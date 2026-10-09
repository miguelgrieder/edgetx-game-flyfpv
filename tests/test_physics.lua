local T = dofile("tests/t.lua")

-- flight module on an empty field with the given settings
local function setup(cfg)
  local h = T.H.new({ sd = "t_phys" })
  local c, f = h.config, h.flight
  c.defaults()
  for k, v in pairs(cfg or {}) do c.v[k] = v end
  f.load({ grid = 10, spawn = { 0, 0, 0 } })
  f.setup()
  f.spawn()
  return f, c
end

local function thrFor(t) return t * 2048 - 1024 end -- throttle 0..1 -> stick

T.test("sits on the ground at low throttle, lifts off above hover", function()
  local f = setup()
  for _ = 1, 20 do f.tick(0, 0, -1024, 0) end
  T.eq(f.pz, 0) T.eq(f.ground, true)
  for _ = 1, 20 do f.tick(0, 0, thrFor(0.5), 0) end
  T.ok(f.pz > 1, "climbing: " .. f.pz)
  T.eq(f.ground, false)
end)

T.test("hover throttle = 1 / thrust-to-weight for every quad", function()
  for q = 1, 5 do
    local f, c = setup({ QUAD = q })
    local hover = 1 / c.QUADS[q].tw
    for _ = 1, 20 do f.tick(0, 0, thrFor(hover + 0.15), 0) end -- take off
    for _ = 1, 400 do f.tick(0, 0, thrFor(hover), 0) end
    T.ok(math.abs(f.vz) < 0.05, "quad " .. q .. " vz " .. f.vz)
  end
end)

T.test("full-stick roll does 360 degrees in about 360/670 s and comes back level", function()
  local f = setup()
  for _ = 1, 40 do f.tick(0, 0, thrFor(0.4), 0) end -- climb
  local turned, ticks, last = 0, 0, f.rz
  -- integrate the commanded rate: after reaching 670 deg/s, one turn takes ~0.54 s = ~11 ticks
  for i = 1, 60 do
    f.tick(1024, 0, thrFor(0.3), 0)
    ticks = i
    turned = turned + f.wr * 0.05 / math.pi * 180
    if turned >= 360 then break end
  end
  T.ok(ticks >= 10 and ticks <= 14, "ticks for one roll: " .. ticks)
  T.near(f.wr / math.pi * 180, 670, 5)
end)

T.test("acro holds the attitude with centred sticks; angle mode levels itself", function()
  local f = setup()
  for _ = 1, 40 do f.tick(0, 0, thrFor(0.4), 0) end
  for _ = 1, 3 do f.tick(1024, 0, thrFor(0.3), 0) end
  for _ = 1, 10 do f.tick(0, 0, thrFor(0.3), 0) end
  local rz = f.rz
  for _ = 1, 10 do f.tick(0, 0, thrFor(0.3), 0) end
  T.near(f.rz, rz, 0.01)
  T.ok(math.abs(rz) > 0.3, "still banked")
  f = setup({ MODE = 2 })
  for _ = 1, 40 do f.tick(0, 0, thrFor(0.4), 0) end
  for _ = 1, 20 do f.tick(1024, 0, thrFor(0.4), 0) end
  T.near(math.atan2(-f.rz, f.uz) / math.pi * 180, 55, 3)
  for _ = 1, 40 do f.tick(0, 0, thrFor(0.4), 0) end
  T.ok(math.abs(f.rz) < 0.02 and f.uz > 0.999, "levelled")
end)

T.test("axes stay orthonormal and finite through long random flying", function()
  local f = setup({ CRASH = 0 })
  local seed = 7
  local function rnd() seed = (seed * 16807) % 2147483647 return seed / 2147483647 * 2048 - 1024 end
  for _ = 1, 4000 do
    f.tick(rnd(), rnd(), rnd(), rnd())
    local fu = f.fx * f.ux + f.fy * f.uy + f.fz * f.uz
    local ff = f.fx * f.fx + f.fy * f.fy + f.fz * f.fz
    T.ok(math.abs(fu) < 1e-6 and math.abs(ff - 1) < 1e-6, "orthonormal")
    T.ok(f.px == f.px and f.pz >= 0 and f.speed() < 200, "finite")
  end
end)

T.test("top speed per quad: full throttle tilted ~ vmax", function()
  for q = 1, 5 do
    local f, c = setup({ QUAD = q, MODE = 2 })
    for _ = 1, 20 do f.tick(0, 0, thrFor(0.9), 0) end -- climb
    for _ = 1, 400 do f.tick(0, 1024, 1024, 0) end -- full forward tilt, full throttle
    local vmax = c.QUADS[q].vmax
    T.ok(f.speed() > vmax * 0.6 and f.speed() < vmax * 1.05, "quad " .. q .. " " .. f.speed() .. " vs " .. vmax)
  end
end)

T.test("crash ON: hard landing crashes, soft landing lands; crash OFF never crashes", function()
  local f = setup()
  for _ = 1, 40 do f.tick(0, 0, thrFor(0.6), 0) end
  for _ = 1, 600 do
    f.tick(0, 0, -1024, 0)
    if f.crashed or f.ground then break end
  end
  T.eq(f.crashed, true)
  f = setup()
  for _ = 1, 6 do f.tick(0, 0, thrFor(0.3), 0) end
  for _ = 1, 400 do
    f.tick(0, 0, thrFor(0.11), 0) -- just under hover (5": 1/8): slow descent
    if f.crashed or f.ground then break end
  end
  T.eq(f.crashed, false) T.eq(f.ground, true)
  f = setup({ CRASH = 0 })
  for _ = 1, 40 do f.tick(0, 0, thrFor(0.6), 0) end
  for _ = 1, 200 do f.tick(1024, 0, -1024, 0) end
  T.eq(f.crashed, false)
end)

T.test("obstacles: crash ON crashes, whoop bounces, crash OFF slides", function()
  local map = { spawn = { 0, 0, 0 }, box = { 0, 10, 40, 2, 200 } } -- wall 9..11 m north, too high to climb over
  for _, case in ipairs({ { 5, 1, "crash" }, { 1, 1, "bounce" }, { 5, 0, "slide" } }) do
    local h = T.H.new({ sd = "t_wall" })
    local c, f = h.config, h.flight
    c.defaults()
    c.v.QUAD, c.v.CRASH, c.v.MODE = case[1], case[2], 2
    f.load(map)
    f.setup()
    f.spawn()
    for _ = 1, 20 do f.tick(0, 0, thrFor(0.8), 0) end
    -- tilted ~38 deg forward with just enough throttle to hold altitude
    local thr = thrFor(1 / c.QUADS[case[1]].tw / math.cos(38 * math.pi / 180) + 0.02)
    for _ = 1, 200 do
      f.tick(0, 700, thr, 0)
      if f.crashed then break end
    end
    T.ok(f.pz < 200, "below the top of the wall")
    if case[3] == "crash" then T.eq(f.crashed, true)
    else
      T.eq(f.crashed, false)
      T.ok(f.py < 9, case[3] .. ": stayed out of the wall, y " .. f.py)
    end
  end
end)
