-- lua5.2 tools/bench.lua [map_x ...]: before/after numbers for speed work. Per map, over a scan of camera poses
-- (every 12 m, 3 heights, 8 headings, level and 30 deg nose down), with the lcd functions swapped for an empty C
-- function (on the radio they are C): mean and worst Lua instructions and C calls (lcd.* + math.*) per frame of
-- render. Then physics: Lua instructions and C calls per frame (SIM SPEED 2.0, 5", random sticks on CITY).
local out = io.stdout
local H = dofile("tools/harness.lua")
local maps = { ... }
if #maps == 0 then
  maps = { "map_city", "map_metro", "map_space", "map_oval", "map_tech", "map_sky" }
end
local stub = math.max

local n, c
local function hook(ev)
  if ev == "count" then n = n + 1 elseif debug.getinfo(2, "S").what == "C" then c = c + 1 end
end
local function measure(fn)
  n, c = 0, 0
  debug.sethook(hook, "c", 1)
  fn()
  debug.sethook()
  return n, c
end

local tn, tc, tf, tw = 0, 0, 0, 0
for _, name in ipairs(maps) do
  local h = H.new({ sd = "bench", fast = true })
  for _, k in ipairs({ "drawLine", "drawFilledRectangle", "drawPoint", "drawRectangle" }) do rawset(lcd, k, stub) end
  local cf, f = h.config, h.flight
  cf.defaults()
  cf.v.HUD = 0
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
  local sn, sc, frames, wn, wc = 0, 0, 0, 0, 0
  for x = x1 - 5, x2 + 5, 12 do
    for y = y1 - 5, y2 + 5, 12 do
      for _, z in ipairs({ 1.5, 8, 25 }) do
        for k = 0, 7 do
          for _, p in ipairs({ 0, 30 }) do
            local a, b = k * math.pi / 4, p * math.pi / 180
            f.px, f.py, f.pz, f.ground = x, y, z, false
            f.fx, f.fy, f.fz = math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), -math.sin(b)
            f.rx, f.ry, f.rz = math.cos(a), -math.sin(a), 0
            f.ux, f.uy, f.uz = math.sin(a) * math.sin(b), math.cos(a) * math.sin(b), math.cos(b)
            local i, cc = measure(function() r.draw(0) end)
            sn, sc, frames = sn + i, sc + cc, frames + 1
            if i > wn then wn = i end
            if cc > wc then wc = cc end
          end
        end
      end
    end
  end
  out:write(string.format("%-10s render  mean %6.0f instr %5.1f C calls   worst %6d instr %4d C calls\n", name, sn / frames,
    sc / frames, wn, wc))
  tn, tc, tf, tw = tn + sn / frames, tc + sc / frames, tf + 1, tw + wn
end
out:write(string.format("ALL MAPS   render  mean %6.0f instr %5.1f C calls   sum of worsts %d instr\n", tn / tf, tc / tf, tw))

-- physics: random smoothed sticks, crash off, on CITY
local h = H.new({ sd = "bench", fast = true })
local cf, f = h.config, h.flight
cf.defaults()
cf.v.CRASH = 0
f.load(h.radio(h.app.use, os.getenv("PMAP") or "map_city", true)); f.setup(); f.spawn()
local seed, s = 5, { 0, 0, 0, 0 }
local function rnd() seed = (seed * 16807) % 2147483647 return seed / 2147483647 * 2 - 1 end
local pn, pc = 0, 0
for _ = 1, 400 do
  for k = 1, 4 do s[k] = s[k] * 0.9 + rnd() * 200 end
  local i, cc = measure(function() f.tick(s[1], s[2], 300 + s[3], s[4]) end)
  pn, pc = pn + i, pc + cc
end
out:write(string.format("physics   per frame %6.0f instr %5.1f C calls (SIM SPEED 2.0, %d substeps)\n", pn / 400, pc / 400, f.SUB))
