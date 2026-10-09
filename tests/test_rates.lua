local T = dofile("tests/t.lua")

local function fl() return T.H.new({ sd = "t_rates" }).flight end

T.test("Betaflight actual rates: center slope, full stick = max, symmetric", function()
  local f = fl()
  T.near(f.rate(1, 70, 670, 0), 670)
  T.near(f.rate(-1, 70, 670, 0), -670)
  T.near(f.rate(0, 70, 670, 0), 0)
  -- slope at the center = center sensitivity
  T.near(f.rate(1e-5, 70, 670, 0) / 1e-5, 70, 0.01)
  -- expo 0: rate = x*center + (max-center)*|x|*x
  T.near(f.rate(0.5, 70, 670, 0), 0.5 * 70 + 600 * 0.25)
  -- expo 1: rate = x*center + (max-center)*|x|*x^5
  T.near(f.rate(0.5, 70, 670, 100), 0.5 * 70 + 600 * 0.5 * 0.5 ^ 5)
  T.near(f.rate(1, 200, 100, 0), 200) -- max below center: linear only
end)
