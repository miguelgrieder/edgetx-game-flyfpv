-- Golden masters: the last frame of each inputs/NN_*.lua scenario must match tests/golden/NN_*.pbm.
-- APPROVE=1 lua5.2 tests/run_all.lua test_screens   rewrites the goldens (review the PNGs first!)
local T = dofile("tests/t.lua")
local FB = T.H.mock.FB

local SCREENS = { "01_title", "02_settings_p1", "03_settings_p2", "04_settings_p3", "05_arm",
  "06_fly_city", "07_fly_metro_angle", "08_fly_oval_whoop", "09_fly_tech_flip", "10_pause", "11_crash",
  "12_debug_no_hud" }
local approve = os.getenv("APPROVE") == "1"

local function render(name, target)
  local sc = dofile("inputs/" .. name .. ".lua")
  local h = T.H.new({ target = target, sd = "golden_" .. name, setup = sc.setup })
  local maxCalls = 0
  for f = 1, sc.frames do
    h.step(sc.fn(f, h.S.clock + 5, h.ctx))
    if h.lastCalls > maxCalls then maxCalls = h.lastCalls end
  end
  return h.fb(), maxCalls
end

local function save(path, text)
  local f = assert(T.H.mock.S.realio.open(path, "wb"))
  f:write(text)
  f:close()
end

T.H.mock.mkdirp("out/screens")
for _, name in ipairs(SCREENS) do
  T.test(name .. " matches its golden (src and dist)", function()
    local fb, calls = render(name, "src")
    T.ok(calls <= 420, "lcd calls " .. calls)
    save("out/screens/" .. name .. ".pbm", fb:pbm())
    local golden = "tests/golden/" .. name .. ".pbm"
    local want = T.read(golden)
    if approve or not want then
      save(golden, fb:pbm())
      if not approve then error("new golden written: " .. golden .. " (review it, then rerun)") end
      return
    end
    local g = FB.fromPbm(want)
    if not g:equals(fb) then
      os.execute("python tools/snapshot.py diff " .. golden .. " out/screens/" .. name .. ".pbm out/screens/"
        .. name .. "_diff.png")
      error(g:diffCount(fb) .. " pixels differ, see out/screens/" .. name .. "_diff.png")
    end
    T.ok(g:equals((render(name, "dist"))), "dist differs from src")
  end)
end
