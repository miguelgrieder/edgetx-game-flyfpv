-- lua5.2 tools/mapcost.lua [map_x ...]: worst and mean render cost of each map over a scan of camera poses
-- (every 8 m across the map, 3 heights, 8 headings, level and 30 deg nose down): Lua VM instructions (in
-- thousands, counted 1000 at a time) and lcd calls per frame. CITY runs 18-20 FPS on a GX12, so a map
-- should not go much past its worst.
local out = io.stdout
local H = dofile("tools/harness.lua")
local maps = { ... }
local cli = arg and arg[0] and arg[0]:find("mapcost") -- from the command line, or dofile'd by a test
if #maps == 0 then
  maps = { "map_city", "map_metro", "map_space", "map_oval", "map_tech", "map_sky", "map_mega" }
end

local function scan(name)
  local h = H.new({ sd = "mapcost", fast = true })
  local c, f = h.config, h.flight
  c.defaults()
  f.load(h.radio(h.app.use, name, true)); f.setup(); f.spawn()
  local r = h.render -- after the map, like the game (render reads the map's view distance when it loads)
  local W = f.W
  local x1, y1, x2, y2 = -10, -10, 10, 10
  for i = 1, W.nb do
    if W.x1[i] < x1 then x1 = W.x1[i] end
    if W.y1[i] < y1 then y1 = W.y1[i] end
    if W.x2[i] > x2 then x2 = W.x2[i] end
    if W.y2[i] > y2 then y2 = W.y2[i] end
  end
  local worst, wlcd, sum, n, wpose, lpose = 0, 0, 0, 0, "", ""
  local count = 0
  debug.sethook(function() count = count + 1 end, "", 1000)
  for x = x1 - 5, x2 + 5, 8 do
    for y = y1 - 5, y2 + 5, 8 do
      for _, z in ipairs({ 1.5, 8, 25 }) do
        local inside = false
        for i = 1, W.nb do
          if W.kind[i] > 0 and x > W.x1[i] - 0.5 and x < W.x2[i] + 0.5 and y > W.y1[i] - 0.5 and y < W.y2[i] + 0.5
            and z > W.z1[i] - 0.5 and z < W.z2[i] + 0.5 then inside = true end
        end
        if not inside then
          for k = 0, 7 do
            for _, p in ipairs({ 0, 30 }) do
              local a, b = k * math.pi / 4, p * math.pi / 180
              f.px, f.py, f.pz, f.ground = x, y, z, false
              f.fx, f.fy, f.fz = math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), -math.sin(b)
              f.rx, f.ry, f.rz = math.cos(a), -math.sin(a), 0
              f.ux, f.uy, f.uz = math.sin(a) * math.sin(b), math.cos(a) * math.sin(b), math.cos(b)
              count = 0
              local calls = r.draw(0)
              local pose = string.format("(%d, %d, %g) hdg %d pitch %d", x, y, z, k * 45, p)
              sum, n = sum + count, n + 1
              if calls > wlcd then wlcd, lpose = calls, pose end
              if count > worst then worst, wpose = count, pose end
            end
          end
        end
      end
    end
  end
  debug.sethook()
  if cli then
    out:write(string.format("%-10s boxes %3d  kinstr worst %3d mean %3d %-32s lcd worst %3d %s\n", name, W.nb, worst,
      sum / n, wpose, wlcd, lpose))
  end
  return worst, wlcd
end

if not cli then return scan end
for _, m in ipairs(maps) do scan(m) end
