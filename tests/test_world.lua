local T = dofile("tests/t.lua")

local MAPS = { "map_field", "map_gates", "map_poles", "map_city" }

local function setup(mapfile, cfg)
  local h = T.H.new({ sd = "t_world" })
  local c, f, r = h.config, h.flight, h.render
  c.defaults()
  for k, v in pairs(cfg or {}) do c.v[k] = v end
  f.load(h.radio(h.app.use, mapfile, true))
  f.setup()
  f.spawn()
  return h, f, r
end

local function thrFor(t) return t * 2048 - 1024 end

T.test("every map loads, spawns clear of obstacles and takes off without hitting anything", function()
  for _, m in ipairs(MAPS) do
    local _, f = setup(m)
    T.ok(f.W.nb > 0, m .. " has obstacles")
    for _ = 1, 40 do f.tick(0, 0, thrFor(0.3), 0) end
    T.eq(f.crashed, false, m)
    T.ok(f.pz > 5, m .. " climbed")
  end
end)

T.test("worst view per map stays within the line budget (spin around at 3 heights)", function()
  for _, m in ipairs(MAPS) do
    local _, f, r = setup(m)
    local worst = 0
    for _, z in ipairs({ 1, 6, 25 }) do
      for k = 0, 35 do
        f.pz, f.ground = z, false
        local a = k * 10 * math.pi / 180
        f.fx, f.fy, f.fz = math.sin(a), math.cos(a), 0
        f.rx, f.ry, f.rz = math.cos(a), -math.sin(a), 0
        f.ux, f.uy, f.uz = 0, 0, 1
        lcd.clear()
        local n = r.draw(0)
        if n > worst then worst = n end
      end
    end
    T.ok(worst <= r.BUDGET, m .. " worst " .. worst)
    print(string.format("    %-10s worst view %d lines", m, worst))
  end
end)

-- fly north at ~1.5 m (simple altitude hold on the throttle) until past y=20 or crashed
local function flyNorth(f)
  for _ = 1, 3 do f.tick(0, 0, thrFor(0.5), 0) end
  for _ = 1, 400 do
    local t = 0.2 + (1.5 - f.pz) * 0.1 - f.vz * 0.05
    f.tick(0, 300, thrFor(t), 0)
    if f.crashed or f.py > 20 then return end
  end
end

T.test("flying through a gate is fine, into its post is a crash", function()
  -- FIELD: gate at (0, 15) spanning x, opening 2 m wide, z 0.5..2.5
  local _, f = setup("map_field", { MODE = 2, QUAD = 3 })
  flyNorth(f)
  T.eq(f.crashed, false)
  T.ok(f.py > 20, "passed the gate")
  _, f = setup("map_field", { MODE = 2, QUAD = 3 })
  f.sx = 1.05 -- lined up with the right post
  f.spawn()
  flyNorth(f)
  T.eq(f.crashed, true)
end)

-- a map table straight into the flight group (no file)
local function setupMap(map, cfg)
  local h = T.H.new({ sd = "t_world2" })
  local c, f, r = h.config, h.flight, h.render
  c.defaults()
  for k, v in pairs(cfg or {}) do c.v[k] = v end
  f.load(map)
  f.setup()
  f.spawn()
  return h, f, r
end

T.test("floating boxes and poles, tunnels, chimneys, roofs and stars build their collision boxes", function()
  local _, f = setupMap({ fbox = { 0, 10, 5, 4, 4, 2 }, fpole = { 3, 3, 2, 4 },
    tube = { 0, 20, 2, 0, 10, 3, 10, 0, 1, 1, 0, 2, -10, 0, 0, 2, 8, 3 }, roof = { 0, -20, 6, 8, 3 }, stars = 20 })
  local W = f.W
  T.eq(W.nb, 1 + 1 + 3 * 4 + 4 + 4) T.eq(W.nt, 3) T.eq(W.ns, 20)
  T.eq(W.z1[1], 5) T.eq(W.z2[1], 7) T.eq(W.kind[1], 1)
  T.eq(W.z1[2], 2) T.eq(W.z2[2], 6) T.eq(W.kind[2], 2)
  -- chimney walls stand from 0 to 8
  T.eq(W.z1[11], 0) T.eq(W.z2[11], 8) T.eq(W.kind[11], 0)
  -- roof slabs at 6..6.3, then 4 poles from the ground to the roof at its corners
  T.eq(W.z1[15], 6) T.near(W.z2[15], 6.3) T.eq(W.kind[19], 2) T.eq(W.z2[19], 6)
  T.near((W.x1[19] + W.x2[19]) / 2, -4) T.near((W.y1[19] + W.y2[19]) / 2, -16)
  for k = 1, 20 do
    local x, y, z = W.sx[k], W.sy[k], W.sz[k]
    T.near(x * x + y * y + z * z, 1, 1e-9)
    T.ok(z > 0, "stars above the horizon")
  end
end)

T.test("under a floating box is free, its underside stops a climb; a chimney is flown up through", function()
  local _, f = setupMap({ fbox = { 0, 10, 4, 8, 4, 2 } }, { MODE = 2, QUAD = 3 })
  flyNorth(f) -- at ~1.5 m, under the box (4..6 m)
  T.eq(f.crashed, false)
  T.ok(f.py > 20, "passed under")
  _, f = setupMap({ fbox = { 0, 0, 4, 8, 8, 2 } }, { MODE = 2, QUAD = 3 })
  for _ = 1, 60 do
    f.tick(0, 0, thrFor(0.6), 0)
    if f.crashed then break end
  end
  T.eq(f.crashed, true)
  T.ok(f.pz < 4, "stopped under it at " .. f.pz)
  _, f = setupMap({ tube = { 0, 0, 0, 2, 20, 3 } }, { MODE = 2, QUAD = 3 })
  for _ = 1, 80 do f.tick(0, 0, thrFor(0.6), 0) end
  T.eq(f.crashed, false)
  T.ok(f.pz > 20, "out of the top at " .. f.pz)
end)

T.test("floating box seen from below, a tunnel from inside and the stars are drawn", function()
  local h, f, r = setupMap({ fbox = { 0, 8, 4, 4, 4, 1 } }, { CAMERA = 35, HUD = 0 })
  f.pz, f.ground = 1, false
  lcd.clear()
  T.ok(r.draw(0) >= 4, "box from below")
  -- the bottom face fills: the pixel straight below the box's centre on screen is part of a face
  local x, y, z = r.tr(0, 8, 4)
  local sx, sy = 64 + r.F * x / z, 32 - r.F * y / z
  T.ok(sy > 0 and sy < 63, "box bottom on screen")
  -- right under it looking straight up: only the bottom face can be seen
  h, f, r = setupMap({ fbox = { 0, 8, 4, 4, 4, 1 } }, { CAMERA = 0, HUD = 0 })
  f.px, f.py, f.pz, f.ground = 0, 8, 1, false
  f.fx, f.fy, f.fz, f.rx, f.ry, f.rz, f.ux, f.uy, f.uz = 0, 0, 1, 1, 0, 0, 0, -1, 0
  lcd.clear()
  T.ok(r.draw(0) >= 4, "bottom face from right under it")
  h, f, r = setupMap({ tube = { 0, 10, 0, 0, 30, 3 } }, { CAMERA = 0, HUD = 0 })
  f.pz, f.ground = 1.5, false
  lcd.clear()
  T.ok(r.draw(0) >= 20, "rings and rails")
  h, f, r = setupMap({ stars = 40 }, { CAMERA = 35, HUD = 0 })
  f.pz, f.ground = 30, false
  lcd.clear()
  r.draw(0)
  local n = 0
  for yy = 0, 20 do for xx = 0, 127 do n = n + h.fb():get(xx, yy) end end
  T.ok(n >= 3, "stars in the top rows: " .. n)
end)
