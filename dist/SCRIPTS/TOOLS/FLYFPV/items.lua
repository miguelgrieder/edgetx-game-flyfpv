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
}
