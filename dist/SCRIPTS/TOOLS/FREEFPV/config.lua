-- Settings: ranges, defaults, quad types, .cfg persistence. Always loaded (small).
local M = {}

M.VERSION = "v1.5" -- shown on the title screen
M.FILE = "/SCRIPTS/TOOLS/FREEFPV/freefpv.cfg"

M.MAPS = { "FIELD", "GATES", "POLES", "CITY" }
M.MAPFILE = { "map_field", "map_gates", "map_poles", "map_city" }

-- quad types: thrust/weight, top speed (m/s), linear drag (1/s), rate response lag (s),
-- collision radius (m), default camera angle (deg), bounces off obstacles (ducted)
M.QUADS = {
  { name = "WHOOP", tw = 2.5, vmax = 10, lin = 1.2, lag = 0.09, radius = 0.06, cam = 15, bounce = true },
  { name = "2.5IN", tw = 4.0, vmax = 19, lin = 0.6, lag = 0.06, radius = 0.12, cam = 20 },
  { name = "3IN", tw = 5.0, vmax = 25, lin = 0.45, lag = 0.045, radius = 0.15, cam = 25 },
  { name = "3.5IN", tw = 6.0, vmax = 30, lin = 0.35, lag = 0.035, radius = 0.18, cam = 30 },
  { name = "5IN", tw = 8.0, vmax = 39, lin = 0.25, lag = 0.025, radius = 0.25, cam = 35 },
}

-- names = labels by value (index = value - lo + 1); rates in deg/s, expo in hundredths
M.ITEMS = {
  { key = "MAP", name = "MAP", lo = 1, hi = 4, def = 1, names = M.MAPS },
  { key = "QUAD", name = "QUAD", lo = 1, hi = 5, def = 5 },
  { key = "MODE", name = "MODE", lo = 1, hi = 2, def = 1, names = { "ACRO", "ANGLE" } },
  { key = "CRASH", name = "CRASH", lo = 0, hi = 1, def = 1, names = { "OFF", "ON" } },
  { key = "CAMERA", name = "CAMERA ANGLE", lo = 0, hi = 60, step = 5, def = 35 },
  { key = "SIM_SPEED", name = "SIM SPEED", lo = 10, hi = 30, step = 5, def = 20 }, -- tenths: 2.0x
  { key = "RP_CENTER", name = "R/P CENTER", lo = 10, hi = 400, step = 10, def = 70 },
  { key = "RP_MAX", name = "R/P MAX", lo = 100, hi = 1800, step = 10, def = 670 },
  { key = "RP_EXPO", name = "R/P EXPO", lo = 0, hi = 100, step = 5, def = 0 },
  { key = "Y_CENTER", name = "YAW CENTER", lo = 10, hi = 400, step = 10, def = 70 },
  { key = "Y_MAX", name = "YAW MAX", lo = 100, hi = 1800, step = 10, def = 670 },
  { key = "Y_EXPO", name = "YAW EXPO", lo = 0, hi = 100, step = 5, def = 0 },
  { key = "HUD", name = "HUD", lo = 0, hi = 1, def = 1, names = { "OFF", "ON" } },
  { key = "DEBUG", name = "DEBUG", lo = 0, hi = 1, def = 0, names = { "OFF", "ON" } },
}

M.v = {}

function M.defaults()
  for i = 1, #M.ITEMS do
    local it = M.ITEMS[i]
    M.v[it.key] = it.def
  end
end

function M.item(key)
  for i = 1, #M.ITEMS do
    if M.ITEMS[i].key == key then return M.ITEMS[i] end
  end
end

-- apply "KEY=value" lines; invalid or out-of-range lines are ignored
function M.parse(text)
  for k, val in string.gmatch(text, "([%u_]+)=(%-?%d+)") do
    local it = M.item(k)
    local n = tonumber(val)
    if it and n and n >= it.lo and n <= it.hi and (n - it.lo) % (it.step or 1) == 0 then M.v[k] = n end
  end
end

function M.load()
  M.defaults()
  local f = io.open(M.FILE, "r")
  if not f then return end
  local text = io.read(f, 512)
  io.close(f)
  if text then M.parse(text) end
end

-- returns false when the file can't be written (missing FREEFPV/ folder)
function M.save()
  local f = io.open(M.FILE, "w")
  if not f then return false end
  for i = 1, #M.ITEMS do
    local k = M.ITEMS[i].key
    io.write(f, k, "=", M.v[k], "\n")
  end
  io.close(f)
  return true
end

return M
