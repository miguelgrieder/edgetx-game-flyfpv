-- Settings: values, quad types, .cfg persistence. Always loaded (small).
local use = ...
local M = {}

M.VERSION = "v0.1.2" -- shown on the title screen
M.FILE = "/SCRIPTS/TOOLS/FLYFPV/flyfpv.cfg"

M.MAPS = { "CITY", "METRO", "SPACE", "T_OVAL", "T_TECH", "T_SKY" } -- T_: race tracks
M.MAPFILE = { "map_city", "map_metro", "map_space", "map_oval", "map_tech", "map_sky" }

-- quad types: thrust/weight, top speed (m/s), linear drag (1/s), rate response lag (s),
-- collision radius (m), default camera angle (deg), bounces off obstacles (ducted)
M.QUADS = {
  { name = "WHOOP", tw = 2.5, vmax = 10, lin = 1.2, lag = 0.09, radius = 0.06, cam = 15, bounce = true },
  { name = "2.5IN", tw = 4.0, vmax = 19, lin = 0.6, lag = 0.06, radius = 0.12, cam = 20 },
  { name = "3IN", tw = 5.0, vmax = 25, lin = 0.45, lag = 0.045, radius = 0.15, cam = 25 },
  { name = "3.5IN", tw = 6.0, vmax = 30, lin = 0.35, lag = 0.035, radius = 0.18, cam = 30 },
  { name = "5IN", tw = 8.0, vmax = 39, lin = 0.25, lag = 0.025, radius = 0.25, cam = 35 },
}

-- the settings menu's items live in items.lua: loaded when needed, dropped while flying (main.lua)
function M.items()
  if not M.ITEMS then M.ITEMS = use("items", true) end
  return M.ITEMS
end

M.v = {}

function M.defaults()
  local items = M.items()
  for i = 1, #items do
    local it = items[i]
    M.v[it.key] = it.def
  end
end

function M.item(key)
  local items = M.items()
  for i = 1, #items do
    if items[i].key == key then return items[i] end
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

-- returns false when the file can't be written (missing FLYFPV/ folder)
function M.save()
  local f = io.open(M.FILE, "w")
  if not f then return false end
  local items = M.items()
  for i = 1, #items do
    local k = items[i].key
    io.write(f, k, "=", M.v[k], "\n")
  end
  io.close(f)
  return true
end

return M
