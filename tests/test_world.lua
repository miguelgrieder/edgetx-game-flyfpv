local T = dofile("tests/t.lua")

local MAPS = { "map_city", "map_metro", "map_space", "map_oval", "map_tech", "map_sky" }

local function setup(mapfile, cfg)
  local h = T.H.new({ sd = "t_world" })
  local c, f = h.config, h.flight
  c.defaults()
  for k, v in pairs(cfg or {}) do c.v[k] = v end
  f.load(h.radio(h.app.use, mapfile, true))
  f.setup()
  f.spawn()
  return h, f, h.render -- render after the map, as in the game (it reads the map's view distance)
end

local function thrFor(t) return t * 2048 - 1024 end

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
  -- a gate at (0, 15) spanning x, opening 2 m wide, z 0.5..2.5
  local GATE = { gate = { 0, 15, 0 } }
  local _, f = setupMap(GATE, { MODE = 2, QUAD = 3 })
  flyNorth(f)
  T.eq(f.crashed, false)
  T.ok(f.py > 20, "passed the gate")
  _, f = setupMap(GATE, { MODE = 2, QUAD = 3 })
  f.sx = 1.05 -- lined up with the right post
  f.spawn()
  flyNorth(f)
  T.eq(f.crashed, true)
end)

T.test("floating boxes and poles, tunnels, chimneys, roofs and stars build their collision boxes", function()
  local _, f = setupMap({ fbox = { 0, 10, 5, 4, 4, 2 }, fpole = { 3, 3, 2, 4 },
    tube = { 0, 20, 2, 0, 10, 3, 10, 0, 1, 1, 0, 2, -10, 0, 0, 2, 8, 3 }, roof = { 0, -20, 6, 8, 3 }, stars = 20 })
  local W = f.W
  T.eq(W.nb, 1 + 1 + 3 * 4 + 4 + 4) T.eq(W.nt, 3) T.eq(W.ns, 20)
  T.eq(W.z1[1], 5) T.eq(W.z2[1], 7) T.eq(W.kind[1], 1)
  T.eq(W.z1[2], 2) T.eq(W.z2[2], 6) T.eq(W.kind[2], 2)
  -- drawn boxes first (render walks only those): roof slabs at 6..6.3, then its 4 poles from the ground to
  -- the roof at its corners
  T.eq(W.nv, 10)
  T.eq(W.z1[3], 6) T.near(W.z2[3], 6.3) T.eq(W.kind[7], 2) T.eq(W.z2[7], 6)
  T.near(W.mx[7], -4) T.near(W.my[7], -16)
  -- then the hidden tunnel walls; the chimney's (third tunnel) stand from 0 to 8
  T.eq(W.kind[11], 0) T.eq(W.z1[19], 0) T.eq(W.z2[19], 8) T.eq(W.kind[19], 0)
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

T.test("on every map the gate and tunnel openings are clear of buildings and poles", function()
  for _, m in ipairs(MAPS) do
    local _, f = setup(m)
    local W = f.W
    -- free space to check: x1, y1, z1, x2, y2, z2
    local free = {}
    for i = 1, W.ng do
      local x, y = W.gx[i], W.gy[i]
      local ax, ay = W.ga[i] == 0 and 0.9 or 0.3, W.ga[i] == 0 and 0.3 or 0.9 -- int
      free[#free + 1] = { x - ax, y - ay, 0.6, x + ax, y + ay, 2.4, m .. " gate " .. i }
    end
    for i = 1, W.nt do
      local x, y, z, l, h = W.tx[i], W.ty[i], W.tz[i], W.tl[i] / 2 + 0.3, W.ts[i] / 2 - 0.1
      local a = W.ta[i]
      if a == 2 then free[#free + 1] = { x - h, y - h, z - 3, x + h, y + h, z + 2 * l + 3, m .. " chimney " .. i } -- int
      elseif a == 0 then free[#free + 1] = { x - h, y - l - 3, z + 0.1, x + h, y + l + 3, z + 2 * h, m .. " tunnel " .. i } -- int
      else free[#free + 1] = { x - l - 3, y - h, z + 0.1, x + l + 3, y + h, z + 2 * h, m .. " tunnel " .. i } end
    end
    for _, v in ipairs(free) do
      for i = 1, W.nb do
        if W.kind[i] > 0 and W.x1[i] < v[4] and W.x2[i] > v[1] and W.y1[i] < v[5] and W.y2[i] > v[2]
          and W.z1[i] < v[6] and W.z2[i] > v[3] then
          error(v[7] .. " is blocked by box " .. i)
        end
      end
    end
  end
end)

-- Budget from the radio: v2.2's CITY (worst view in this scan ~31k instructions, ~240 lcd calls) still had
-- great FPS on a GX12. No map may cost more than ~25 % over that in its worst view (tools/mapcost.lua).
-- SKY OFF in the settings takes the sky's part (~10 %) away.
T.test("no map's worst view costs more than 40k instructions or 300 lcd calls", function()
  local scan = dofile("tools/mapcost.lua")
  for _, m in ipairs(MAPS) do
    local i, l = scan(m)
    T.ok(i <= 40 and l <= 300, m .. ": " .. i .. "k instructions, " .. l .. " lcd calls (budget 40k, 300)")
  end
end)

T.test("SKY: AUTO takes the map's sky, DAY gives clouds and a sun, NIGHT stars, OFF nothing", function()
  local function sky(map, s)
    local _, f = setupMap(map, { SKY = s })
    local W = f.W
    return W.ns, W.nk, W.sun, W.sky
  end
  local day, night = { sky = "day" }, { sky = "night", stars = 30 }
  local ns, nk, sun = sky(day, 1)
  T.eq(ns, 0) T.ok(nk > 0, "clouds") T.eq(sun, true)
  ns, nk, sun = sky(night, 1)
  T.eq(ns, 30) T.eq(nk, 0) T.eq(sun, false)
  ns, nk, sun = sky(night, 2)
  T.eq(ns, 0) T.ok(nk > 0, "clouds") T.eq(sun, true)
  ns, nk, sun = sky(day, 3)
  T.eq(ns, 40) T.eq(nk, 0) T.eq(sun, false)
  local s
  ns, nk, sun, s = sky(day, 4)
  T.eq(ns, 0) T.eq(nk, 0) T.eq(sun, false) T.eq(s, false)
  -- the sun is drawn where it is (looking at it, level): its disk is lit
  local h, f, r = setupMap({ sky = "day", sun = { 0, 30 }, clouds = {} }, { CAMERA = 30, HUD = 0 })
  f.pz, f.ground = 5, false
  lcd.clear()
  r.draw(0)
  T.eq(h.fb():get(64, 32), 1) -- straight ahead and 30 deg up, the camera's centre
end)
