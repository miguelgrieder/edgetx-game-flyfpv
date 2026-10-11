-- lua5.2 tools/samepix.lua <out.txt> [step m]: renders a scan of camera poses on every map (mock rasteriser on) and
-- writes one checksum per frame. Run it on two versions and diff the files: a speed change must not
-- change a single pixel.
local out = assert(io.open(arg[1], "wb"))
local STEP = tonumber(arg[2] or "14") -- metres between sampled positions
local H = dofile("tools/harness.lua")
local maps = { "map_city", "map_metro", "map_space", "map_oval", "map_tech", "map_sky", "map_mega" }
for _, name in ipairs(maps) do
  local h = H.new({ sd = "samepix" })
  local c, f = h.config, h.flight
  c.defaults()
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
  for x = x1 - 5, x2 + 5, STEP do
    for y = y1 - 5, y2 + 5, STEP do
      for _, z in ipairs({ 0.6, 1.5, 4, 12, 30 }) do
        for k = 0, 7 do
          for _, p in ipairs({ -20, 0, 35, 80 }) do
            for _, roll in ipairs({ 0, 40 }) do
              local a, b, rl = k * math.pi / 4 + 0.1, p * math.pi / 180, roll * math.pi / 180
              f.px, f.py, f.pz, f.ground = x, y, z, false
              local fx, fy, fz = math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), -math.sin(b)
              local rx, ry, rz = math.cos(a), -math.sin(a), 0
              local ux, uy, uz = math.sin(a) * math.sin(b), math.cos(a) * math.sin(b), math.cos(b)
              local cr, sr = math.cos(rl), math.sin(rl)
              f.fx, f.fy, f.fz = fx, fy, fz
              f.ux, f.uy, f.uz = ux * cr + rx * sr, uy * cr + ry * sr, uz * cr + rz * sr
              f.rx, f.ry, f.rz = rx * cr - ux * sr, ry * cr - uy * sr, rz * cr - uz * sr
              lcd.clear()
              h.radio(r.draw, 0)
              local s = h.fb():pbm()
              local sum = 0
              for i = 1, #s do sum = (sum * 31 + s:byte(i)) % 4294967296 end
              out:write(string.format("%s %g %g %g %d %d %d %08x\n", name, x, y, z, k, p, roll, sum))
            end
          end
        end
      end
    end
  end
end
out:close()
