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
  local a = collectgarbage("count")
  for _ = 1, 3000 do r.draw(0) end
  local used = collectgarbage("count") - a
  collectgarbage("restart")
  -- a one-off ~1 KB (interpreter stack) is fine; anything per frame would be 3000x
  T.ok(used < 2, "allocated " .. used .. " KB in 3000 frames")
end)

-- EdgeTX 2.12.2's Lua floors a float before == / ~= against an integer (0.87 ~= 0 is false; fixed in
-- 2.12.4) and the PC's Lua 5.2 can't show it, so the geometry modules may compare with a number
-- literal only where both sides are integers, marked "int" in a comment
T.test("geometry never compares a float with == / ~= against a number (EdgeTX 2.12.2 Lua bug)", function()
  for _, name in ipairs({ "render", "solid", "flight" }) do
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
