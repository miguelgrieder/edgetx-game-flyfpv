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

T.test("uptilt puts the horizon low on the ground; rolling tilts it", function()
  local h, f, r = setup({ CAMERA = 35 })
  lcd.clear()
  r.draw(-1024)
  -- horizon at y = 32 + 40 * tan(35) ~ 60
  local row = 0
  for y = 50, 63 do
    local n = 0
    for x = 0, 127 do n = n + h.fb():get(x, y) end
    if n > 100 then row = y end
  end
  T.ok(row >= 58 and row <= 61, "horizon row " .. row)
end)

T.test("nothing is ever drawn off-screen: 3000 random poses inside and around the obstacles", function()
  local h, f, r = setup({ CRASH = 0, HUD = 1, DEBUG = 1 })
  local seed = 11
  local function rnd(a, b) seed = (seed * 16807) % 2147483647 return a + (b - a) * seed / 2147483647 end
  for _ = 1, 3000 do
    f.px, f.py, f.pz = rnd(-15, 15), rnd(-5, 40), rnd(0, 10)
    -- random attitude: random small rotations applied many times
    for _ = 1, 3 do f.step(rnd(-1, 1), rnd(-1, 1), 0.3, rnd(-1, 1)) end
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
  local a = collectgarbage("count")
  for _ = 1, 3000 do r.draw(0) end
  local used = collectgarbage("count") - a
  collectgarbage("restart")
  -- a one-off ~1 KB (interpreter stack) is fine; anything per frame would be 3000x
  T.ok(used < 2, "allocated " .. used .. " KB in 3000 frames")
end)
