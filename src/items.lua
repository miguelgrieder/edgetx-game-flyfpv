-- The settings menu's items: ranges, defaults and labels. Loaded by config.items() for the menus and the
-- .cfg file, and dropped while flying (main.lua), where only config.v is read.
local use = ...
local config = use("config")

-- names = labels by value (index = value - lo + 1); rates in deg/s, expo in hundredths
return {
  { key = "MAP", name = "MAP", lo = 1, hi = #config.MAPS, def = 1, names = config.MAPS },
  { key = "SKY", name = "SKY", lo = 1, hi = 4, def = 4, names = { "AUTO", "DAY", "NIGHT", "OFF" } }, -- AUTO: the map's;
  -- OFF by default: a Pocket ran out of memory with a sky
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
  { key = "VIEW", name = "VIEW DIST", lo = 0, hi = 240, step = 20, def = 0 }, -- m; 0 AUTO: the map's own
  -- (less: faster on a slow radio, more: see the whole of a big map)
  { key = "SOLID", name = "SOLID BLDGS", lo = 0, hi = 1, def = 1, names = { "OFF", "ON" } }, -- OFF: see-through, faster
  { key = "SOLID_D", name = "SOLID DIST", lo = 10, hi = 100, step = 10, def = 40 }, -- m: nearer solid lines, farther dotted
  { key = "FOV", name = "FOV", lo = 1, hi = 5, def = 4, names = { "90 DEG", "100 DEG", "110 DEG", "116 DEG", "125 DEG" } },
  { key = "GRID", name = "GRID", lo = 0, hi = 2, def = 1, names = { "OFF", "ON", "DENSE" } },
  { key = "BOW", name = "HORIZON", lo = 1, hi = 4, def = 3, names = { "FLAT", "LOW", "MID", "HIGH" } }, -- its lens curve
  { key = "LIMIT", name = "LINE LIMIT", lo = 0, hi = 1200, step = 50, def = 0 }, -- lcd calls a frame; 0 AUTO: the map's
}
