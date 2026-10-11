local T = dofile("tests/t.lua")

local function setup(cfg)
  local h = T.H.new({ sd = "t_render" })
  local c, f, r = h.config, h.flight, h.render
  c.defaults()
  for k, v in pairs(cfg or {}) do c.v[k] = v end
  f.load({ grid = 10, spawn = { 0, 0, 0 }, box = { 0, 30, 6, 6, 6 }, pole = { 5, 15, 8 }, gate = { -5, 20, 0 } })
  f.setup()
  f.spawn()
  return h, f, r, c
end

T.test("projection: straight ahead is the screen centre, up is up, right is right", function()
  local h, f, r = setup({ CAMERA = 0 })
  f.pz = 2
  r.camera()
  local x, y, z = r.tr(0, 10, 2.03) -- 10 m north at camera height: straight ahead
  T.near(x, 0) T.near(y, 0) T.near(z, 10, 0.05)
  x, y = r.tr(1, 10, 3)
  T.ok(x > 0 and y > 0, "right and up")
end)

-- topmost lit row of column x within rows y0..y1 (nil: none)
local function lit(h, x, y0, y1)
  local r
  for y = y1, y0, -1 do if h.fb():get(x, y) == 1 then r = y end end -- int
  return r
end

-- pose: quad pz m up, pitched pitch degrees nose down (yaw north, no roll)
local function nose(f, pz, pitch)
  local a = pitch * math.pi / 180
  f.px, f.py, f.pz, f.ground = 0, 0, pz, false
  f.fx, f.fy, f.fz, f.rx, f.ry, f.rz = 0, math.cos(a), -math.sin(a), 1, 0, 0
  f.ux, f.uy, f.uz = 0, math.sin(a), math.cos(a)
end

T.test("uptilt puts the horizon low; it is curved like a wide lens, ends toward the centre", function()
  local h, f, r = setup({ CAMERA = 35, HUD = 0 })
  lcd.clear()
  r.draw(-1024)
  -- real horizon at y = 32 + 40 * tan(35) ~ 60 in the middle; 15 % of 28 px ~ 4 px higher at the ends
  local mid, left, right = lit(h, 64, 56, 61), lit(h, 5, 50, 59), lit(h, 122, 50, 59)
  T.ok(mid == 60, "middle row " .. tostring(mid)) -- int
  T.ok(left and left <= 57 and right and right <= 57, "ends " .. tostring(left) .. " " .. tostring(right))
  -- nose down: the horizon comes up, nearly straight close to the centre
  nose(f, 5, 25) -- horizon at 32 + 40 * tan(10) ~ 39
  lcd.clear()
  r.draw(-1024)
  local row = lit(h, 50, 30, 50)
  T.ok(row and row >= 38 and row <= 40, "true horizon row " .. tostring(row))
end)

T.test("horizon out of view: nothing of it is drawn", function()
  local h, f, r = setup({ CAMERA = 35, HUD = 0 })
  nose(f, 20, 80) -- high, looking 45 deg down: the horizon is above the screen
  lcd.clear()
  r.draw(-1024)
  local n = 0
  for y = 0, 10 do for x = 0, 127 do n = n + h.fb():get(x, y) end end
  T.eq(n, 0)
end)

T.test("nothing is ever drawn off-screen: 3000 random poses inside and around the obstacles", function()
  local h, f, r = setup({ CRASH = 0, HUD = 1, DEBUG = 1 })
  local seed = 11
  local function rnd(a, b) seed = (seed * 16807) % 2147483647 return a + (b - a) * seed / 2147483647 end
  for _ = 1, 3000 do
    f.px, f.py, f.pz = rnd(-15, 15), rnd(-5, 40), rnd(0, 10)
    -- random attitude: random small rotations applied many times
    for _ = 1, 3 do f.tick(rnd(-1024, 1024), rnd(-1024, 1024), -400, rnd(-1024, 1024)) end
    f.ground = false
    lcd.clear()
    local n = r.draw(0)
    T.ok(n <= r.BUDGET, "budget")
  end
end)

T.test("no allocation while drawing (mock in no-raster mode: its own rasteriser allocates a little)", function()
  local h = T.H.new({ sd = "t_render_alloc", fast = true })
  local c, f, r = h.config, h.flight, h.render
  c.defaults()
  f.load({ grid = 10, spawn = { 0, 0, 0 }, box = { 0, 30, 6, 6, 6 }, pole = { 5, 15, 8 }, gate = { -5, 20, 0 } })
  f.setup()
  f.spawn()
  f.pz, f.ground = 3, false
  r.draw(0)
  collectgarbage("collect")
  collectgarbage("stop")
  -- right after a full collection the first frame regrows what it shrank (a few KB, once): measure from
  -- frame 10 on; anything per frame would grow 3000x
  for _ = 1, 10 do r.draw(0) end
  local a = collectgarbage("count")
  for _ = 1, 3000 do r.draw(0) end
  local used = collectgarbage("count") - a
  collectgarbage("restart")
  T.ok(used < 0.5, "allocated " .. used .. " KB in 3000 frames")
end)

-- EdgeTX 2.12.2's Lua floors a float before == / ~= against an integer (0.87 ~= 0 is false; fixed in
-- 2.12.4) and the PC's Lua 5.2 can't show it, so the geometry modules may compare with a number
-- literal only where both sides are integers, marked "int" in a comment
T.test("geometry never compares a float with == / ~= against a number (EdgeTX 2.12.2 Lua bug)", function()
  for _, name in ipairs({ "render", "solid", "flight", "world", "wire", "sky" }) do
    local n = 0
    for line in (T.read("src/" .. name .. ".lua"):gsub("\r", "") .. "\n"):gmatch("(.-)\n") do
      n = n + 1
      local code, comment = line:match("^(.-)%-%-(.*)$")
      code, comment = code or line, comment or ""
      if code:find("[=~]=%s*%-?%d") and not comment:find("int") then
        error(name .. ".lua:" .. n .. ": == / ~= with a number literal: " .. line)
      end
    end
  end
end)

T.test("a horizontal pole is one line, along x or along y", function()
  for _, a in ipairs({ 0, 1 }) do
    local h = T.H.new({ sd = "t_render_h" })
    local c, f, r = h.config, h.flight, h.render
    c.defaults() c.v.CAMERA, c.v.HUD = 0, 0
    -- 5 m above the camera, 20 m ahead: across the view (axis 0), or running away from it (axis 1)
    f.load({ grid = 10, spawn = { 0, 0, 0 }, hpole = { 0, 20, 7.03, a, a == 0 and 6 or 8 } })
    f.setup() f.spawn()
    f.pz, f.ground = 2, false
    lcd.clear()
    local n = r.draw(0)
    f.load({ grid = 10, spawn = { 0, 0, 0 } })
    lcd.clear()
    T.eq(n - r.draw(0), 1, "axis " .. a)
  end
end)

T.test("a frame is drawn whole: 4 corner poles and 3 squares of 4 beams", function()
  local h = T.H.new({ sd = "t_render_f" })
  local c, f, r = h.config, h.flight, h.render
  c.defaults() c.v.CAMERA, c.v.HUD = 0, 0
  f.load({ grid = 10, spawn = { 0, 0, 0 }, frame = { 0, 40, 6, 6, 9 } }) -- far enough to be all in view
  f.setup() f.spawn()
  f.pz, f.ground = 4.5, false
  lcd.clear()
  local n = r.draw(0)
  f.load({ grid = 10, spawn = { 0, 0, 0 } })
  lcd.clear()
  T.eq(n - r.draw(0), 16)
end)

T.test("VIEW DIST: AUTO keeps the map's view distance, a number replaces it", function()
  local _, _, r = setup({ VIEW = 0 })
  T.eq(r.FAR, 120)
  local h = T.H.new({ sd = "t_render_view" })
  h.config.defaults() h.config.v.VIEW = 0
  h.flight.load({ grid = 10, spawn = { 0, 0, 0 }, far = 60, box = { 0, 30, 6, 6, 6 } })
  T.eq(h.render.FAR, 60)
  h = T.H.new({ sd = "t_render_view2" })
  h.config.defaults() h.config.v.VIEW = 200
  h.flight.load({ grid = 10, spawn = { 0, 0, 0 }, far = 60, box = { 0, 30, 6, 6, 6 } })
  T.eq(h.render.FAR, 200)
end)

T.test("view settings: FOV, SOLID DIST, HORIZON and LINE LIMIT set the renderer; GRID OFF / DENSE", function()
  local function renderer(cfg) -- the settings first: render reads them when it loads
    local h = T.H.new({ sd = "t_render_s" })
    h.config.defaults()
    for k, v in pairs(cfg) do h.config.v[k] = v end
    h.flight.load({ grid = 10, spawn = { 0, 0, 0 } })
    return h.render
  end
  local r = renderer({ FOV = 1, SOLID_D = 70, BOW = 1, LIMIT = 150 })
  T.eq(r.F, 64) T.eq(r.SOLID_D, 70) T.eq(r.BOW, 0) T.eq(r.BUDGET, 150)
  local d = renderer({})
  T.eq(d.F, 40) T.eq(d.SOLID_D, 40) T.eq(d.BOW, 0.15) T.eq(d.BUDGET, 400)
  local function lines(grid)
    local h = T.H.new({ sd = "t_render_g" .. grid })
    h.config.defaults() h.config.v.GRID, h.config.v.HUD, h.config.v.CAMERA = grid, 0, 0
    h.flight.load({ grid = 10, spawn = { 0, 0, 0 } }) h.flight.setup() h.flight.spawn()
    h.flight.pz, h.flight.ground = 10, false
    lcd.clear()
    return h.render.draw(0)
  end
  local off, on, dense = lines(0), lines(1), lines(2)
  T.ok(off < on and on < dense, off .. " < " .. on .. " < " .. dense)
end)

T.test("SOLID BLDGS OFF: a box is its 12 edges, see-through, with no fill", function()
  local function draw(solid)
    local h = T.H.new({ sd = "t_render_w" .. solid })
    h.config.defaults() h.config.v.SOLID, h.config.v.HUD, h.config.v.GRID, h.config.v.CAMERA = solid, 0, 0, 0
    h.flight.load({ grid = 10, spawn = { 0, 0, 0 }, box = { 0, 40, 6, 6, 6 } }) h.flight.setup() h.flight.spawn()
    h.flight.pz, h.flight.ground = 8, false
    lcd.clear()
    local n = h.render.draw(0)
    h.flight.load({ grid = 10, spawn = { 0, 0, 0 } })
    lcd.clear()
    return n - h.render.draw(0)
  end
  T.eq(draw(0), 12)
  T.ok(draw(1) ~= 12, "solid: only its seen edges, and fill rows")
end)
