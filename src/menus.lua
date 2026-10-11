-- Menu group (never loaded while flying): title, settings.
local use = ...
local config = use("config")

local M = {}

M.saveOk = true
M.sel, M.editing = 1, false
M.confirm = false -- RESET ALL asked once, waiting for the second ENT
M.tsel = 1 -- the title's menu: 1 FLY, 2 SETTINGS, 3 EXIT

local function center(y, s, flags)
  lcd.drawText(64, y, s, (flags or 0) + CENTER)
end

-- text in reverse video: draw it centered, then XOR a box around it
local function boxed(y, s)
  center(y + 2, s)
  local right = lcd.getLastRightPos()
  local w = 2 * (right - 64) - 1 -- text width (CENTER puts ceil(w/2) right of x=64)
  lcd.drawFilledRectangle(right - w - 2, y, w + 3, 11)
end

local function rule() lcd.drawLine(8, 18, 119, 18, DOTTED, FORCE) end

-- text shown in the settings list
function M.label(it)
  local v = config.v[it.key]
  if it.key == "QUAD" then return config.QUADS[v].name end
  if it.key == "CAMERA" then return v .. " DEG" end
  if it.key == "VIEW" or it.key == "LIMIT" then return v == 0 and "AUTO" or v .. (it.key == "VIEW" and " M" or "") end
  if it.key == "SOLID_D" then return v .. " M" end
  if it.action == "reset" then return M.confirm and "ENT: SURE?" or "" end
  if it.key == "SIM_SPEED" then return math.floor(v / 10) .. "." .. v % 10 .. "X" end
  if it.key == "RP_EXPO" or it.key == "Y_EXPO" then return math.floor(v / 100) .. "." .. (v < 10 and "0" or "") .. v % 100 end
  if it.names then return it.names[v - it.lo + 1] end
  return tostring(v)
end

-- step the value of item it by dir (+1/-1), clamped; a new quad brings its usual camera angle
function M.change(it, dir)
  local v = config.v
  local nv = v[it.key] + dir * (it.step or 1)
  if nv < it.lo then nv = it.lo elseif nv > it.hi then nv = it.hi end
  v[it.key] = nv
  if it.key == "QUAD" then v.CAMERA = config.QUADS[nv].cam end
end

local TITLE_ITEMS = { "FLY", "SETTINGS", "EXIT" }


function M.title()
  local v = config.v
  center(3, "FLYFPV", DBLSIZE)
  lcd.drawText(127, 0, config.VERSION, SMLSIZE + RIGHT)
  center(21, M.saveOk and config.MAPS[v.MAP] .. "  " .. config.QUADS[v.QUAD].name .. "  " .. (v.MODE == 2 and "ANGLE" or "ACRO")
    or "NO SAVE")
  -- a menu like every EdgeTX tool's (the scroll wheel moves, ENT picks), so SETTINGS is in plain sight
  for i = 1, 3 do
    local y, s = 19 + 11 * i, TITLE_ITEMS[i]
    if i == M.tsel then boxed(y, s) else center(y + 2, s) end
  end
end

M.MENU = {} -- config items + EXIT
local items = config.items()
for i = 1, #items do M.MENU[i] = items[i] end
M.MENU[#M.MENU + 1] = { name = "RESET ALL", action = "reset" } -- every setting back to its default
M.MENU[#M.MENU + 1] = { name = "EXIT", action = "exit" }
local PAGES = math.ceil(#M.MENU / 5)

function M.settings()
  local sel = M.sel
  local page = math.ceil(sel / 5)
  lcd.drawText(2, 1, "SETTINGS", 0)
  lcd.drawText(90, 1, page .. "/" .. PAGES, 0)
  lcd.drawLine(0, 9, 127, 9, SOLID, FORCE)
  for row = 1, 5 do
    local i = (page - 1) * 5 + row
    local it, y = M.MENU[i], 2 + row * 10
    if not it then break end
    local val = (it.key or it.action == "reset") and M.label(it) or ""
    if i == sel and M.editing then val = "<" .. val .. ">" end
    lcd.drawText(4, y, it.name, 0)
    lcd.drawText(74, y, val, 0)
    if i == sel then lcd.drawFilledRectangle(0, y - 1, 124, 9) end
  end
  lcd.drawLine(126, 11, 126, 62, SOLID, FORCE)
  local h = math.floor(52 / PAGES)
  lcd.drawFilledRectangle(125, 11 + (page - 1) * h, 3, h, FORCE)
end

-- one settings event: "next" / "prev" / "enter" / "exit"; returns true when leaving the menu
function M.settingsEvent(e)
  local it = M.MENU[M.sel]
  if M.editing then
    if e == "next" then M.change(it, 1)
    elseif e == "prev" then M.change(it, -1)
    elseif e == "enter" or e == "exit" then M.editing = false end
    return false
  end
  local ask = false
  if e == "next" then M.sel = M.sel % #M.MENU + 1
  elseif e == "prev" then M.sel = (M.sel - 2) % #M.MENU + 1
  elseif e == "exit" then M.confirm = false return true
  elseif e == "enter" then
    if it.key then M.editing = true
    elseif it.action == "reset" then
      -- the second ENT resets (saved when the menu is left): a stray press can't wipe them
      if M.confirm then config.defaults() else ask = true end
    else return true end
  end
  M.confirm = ask
  return false
end

return M
