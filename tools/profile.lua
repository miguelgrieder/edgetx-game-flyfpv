-- lua5.2 tools/profile.lua [map_x ...]: where render's time goes. The lcd functions are swapped for an empty
-- C function (on the radio they are C; the mock's are Lua and would be counted), then each Lua instruction
-- is charged to the function running it (sampled 1 in 10), and each C call (lcd.* and math.*) is counted, over a scan of
-- camera poses (every 20 m, 3 heights, 8 headings, level and 30 deg nose down).
local out = io.stdout
local H = dofile("tools/harness.lua")
local maps = { ... }
if #maps == 0 then maps = { "map_city", "map_metro", "map_space", "map_tech" } end

local stub = math.max -- a C function that accepts numbers and returns at once
local per, cnames = {}, {}
local total, ccalls, frames = 0, 0, 0
for _, name in ipairs(maps) do
  local h = H.new({ sd = "profile", fast = true })
  for _, k in ipairs({ "drawLine", "drawFilledRectangle", "drawPoint", "drawRectangle" }) do rawset(lcd, k, stub) end
  local c, f = h.config, h.flight
  c.defaults()
  c.v.HUD = 0
  f.load(h.radio(h.app.use, name, true)); f.setup(); f.spawn()
  local r = h.render
  local W = f.W
  local x1, y1, x2, y2 = -10, -10, 10, 10
  for i = 1, W.nb do
    if W.x1[i] < x1 then x1 = W.x1[i] end
    if W.y1[i] < y1 then y1 = W.y1[i] end
    if W.x2[i] > x2 then x2 = W.x2[i] end
    if W.y2[i] > y2 then y2 = W.y2[i] end
  end
  for x = x1 - 5, x2 + 5, 20 do
    for y = y1 - 5, y2 + 5, 20 do
      for _, z in ipairs({ 1.5, 8, 25 }) do
        for k = 0, 7 do
          for _, p in ipairs({ 0, 30 }) do
            local a, b = k * math.pi / 4, p * math.pi / 180
            f.px, f.py, f.pz, f.ground = x, y, z, false
            f.fx, f.fy, f.fz = math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), -math.sin(b)
            f.rx, f.ry, f.rz = math.cos(a), -math.sin(a), 0
            f.ux, f.uy, f.uz = math.sin(a) * math.sin(b), math.cos(a) * math.sin(b), math.cos(b)
            debug.sethook(function(ev)
              local info = debug.getinfo(2, "Sl")
              if ev == "count" then
                local key = (info.short_src:match("([%w_]+%.lua)") or info.short_src) .. ":" .. info.linedefined
                per[key] = (per[key] or 0) + 10
                total = total + 10
              elseif info.what == "C" then
                ccalls = ccalls + 1
              end
            end, "c", 10) -- a sample every 10 instructions
            r.draw(0)
            debug.sethook()
            frames = frames + 1
          end
        end
      end
    end
  end
end
local keys = {}
for k in pairs(per) do keys[#keys + 1] = k end
table.sort(keys, function(a, b) return per[a] > per[b] end)
out:write(string.format("%d frames (%s): %.0f instructions and %.1f C calls per frame\n", frames, table.concat(maps, " "),
  total / frames, ccalls / frames))
for i = 1, math.min(#keys, 18) do
  out:write(string.format("  %-22s %6.0f per frame  %4.1f %%\n", keys[i], per[keys[i]] / frames, 100 * per[keys[i]] / total))
end
