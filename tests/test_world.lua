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
