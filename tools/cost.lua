-- lua5.2 tools/cost.lua [src|dist]: Lua VM instructions and C calls per frame (render + physics) in heavy
-- CITY views. Counts don't depend on the PC's speed, so they compare versions the way the radio would; a C
-- call (math.floor/sin/..., lcd.*) costs much more than one instruction there (no double-precision FPU).
local out = io.stdout -- before the mock replaces io
local H = dofile("tools/harness.lua")
local h = H.new({ sd = "cost", fast = true, target = arg[1] or "src" })
local c, f, r = h.config, h.flight, h.render
c.defaults()
f.load(h.radio(h.app.use, "map_city", true)); f.setup(); f.spawn()

local function pose(x, y, z, yawdeg, pitchdeg, rolldeg)
  local a = yawdeg * math.pi / 180
  f.px, f.py, f.pz, f.ground = x, y, z, false
  f.fx, f.fy, f.fz, f.rx, f.ry, f.rz, f.ux, f.uy, f.uz = math.sin(a), math.cos(a), 0, math.cos(a), -math.sin(a), 0, 0, 0, 1
  local pa, ra = pitchdeg * math.pi / 180, rolldeg * math.pi / 180
  local fx, fy, fz, rx, ry, rz, ux, uy, uz = f.fx, f.fy, f.fz, f.rx, f.ry, f.rz, f.ux, f.uy, f.uz
  local ca, sa = math.cos(ra), math.sin(ra)
  ux, uy, uz, rx, ry, rz = ux * ca + rx * sa, uy * ca + ry * sa, uz * ca + rz * sa, rx * ca - ux * sa, ry * ca - uy * sa, rz * ca - uz * sa
  local cb, sb = math.cos(pa), math.sin(pa)
  fx, fy, fz, ux, uy, uz = fx * cb - ux * sb, fy * cb - uy * sb, fz * cb - uz * sb, ux * cb + fx * sb, uy * cb + fy * sb, uz * cb + fz * sb
  f.fx, f.fy, f.fz, f.rx, f.ry, f.rz, f.ux, f.uy, f.uz = fx, fy, fz, rx, ry, rz, ux, uy, uz
end

local function count(fn)
  local n, cc = 0, 0
  debug.sethook(function(ev)
    if ev == "count" then n = n + 1
    elseif debug.getinfo(2, "S").what == "C" then cc = cc + 1 end
  end, "c", 1)
  fn()
  debug.sethook()
  return n, cc
end

local total, ctotal = 0, 0
for _, v in ipairs({ { "street, level", -9, 5, 6, 15, 10, 0 }, { "between blocks, low", 9, 29, 4, 0, 30, 0 },
  { "between blocks, banked", 9, 29, 4, 0, 30, 35 }, { "falling, looking down", 0, 38, 30, 0, 80, 0 },
  { "fast forward, nose down", -9, 30, 15, 0, 45, 20 }, { "brushing a wall", -13.2, 29, 6, 0, 30, 0 } }) do
  pose(v[2], v[3], v[4], v[5], v[6], v[7])
  local n, cc = count(function() r.draw(0) end)
  total, ctotal = total + n, ctotal + cc
  out:write(string.format("%-26s render %6d instructions, %4d C calls\n", v[1], n, cc))
end
pose(-9, 0, 15, 0, 45, 0)
local p, pc = count(function() f.vx, f.vy, f.vz = 0, 60, -20; f.crashed = false; f.tick(0, 0, 0, 0) end)
out:write(string.format("%-26s physics %5d instructions, %4d C calls (SIM SPEED 2x)\n", "fast", p, pc))
out:write(string.format("render total %d instructions, %d C calls\n", total, ctotal))
