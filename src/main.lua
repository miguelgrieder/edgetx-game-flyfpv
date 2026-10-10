-- FlyFPV entry: module loader, state machine, fixed 50 ms timestep, events, backlight.
-- The game lives in /SCRIPTS/TOOLS/FLYFPV/*.lua, loaded with loadScript (each file compiles and is
-- cached as .luac on its own). Only one group is in memory at a time: menus, or flight + render +
-- the selected map's data.
local DIR = "/SCRIPTS/TOOLS/FLYFPV/"
local loaded = {}

-- EdgeTX runs a file's .luac when it is newer than the .lua: with the radio's clock ahead of the PC's,
-- the old .luac kept winning over freshly copied files and the radio ran the previous version.
-- build.txt holds the build's stamp (tools/build.lua); compiled.txt that stamp and the modules
-- already recompiled for it. A module's first load under a new stamp forces the recompile ("c").
local function readText(name)
  local f = io.open(DIR .. name, "r")
  if not f then return "" end
  local s = io.read(f, 400)
  io.close(f)
  return s or ""
end
local build = readText("build.txt")
local stamp = string.match(build, "%S+") -- nil: no build file (tests from src/)
local done = readText("compiled.txt")
if stamp and string.match(done, "^%S*") ~= stamp then
  done = stamp .. "\n"
  local f = io.open(DIR .. "compiled.txt", "w")
  if f then io.write(f, done) io.close(f) end
end

-- nocache: load a data file once (maps) without keeping it
local function use(name, nocache)
  local m = loaded[name]
  if not m then
    local fresh = not stamp or string.find(done, "\n" .. name .. "\n", 1, true)
    collectgarbage() -- compiling is the memory peak: start it with the garbage gone
    local chunk, err = loadScript(DIR .. name .. ".lua", fresh and "bt" or "btc")
    if not chunk then error(err) end
    if not fresh then
      done = done .. name .. "\n"
      local f = io.open(DIR .. "compiled.txt", "a")
      if f then io.write(f, name, "\n") io.close(f) end
    end
    m = chunk(use)
    if not nocache then loaded[name] = m end
  end
  return m
end

local config = use("config")

-- The first start of a new build compiles the modules listed in build.txt, one per frame, before anything
-- else is loaded: compiling is the memory peak (a Pocket ran out of it compiling while flying), loading
-- the .luac later is not
local pending, np = {}, 0
for name in string.gmatch(build, "\n(%S+)") do
  if not string.find(done, "\n" .. name .. "\n", 1, true) then pending[#pending + 1] = name end
end
local menus, flight, render

local TITLE, SETTINGS, ARM, FLY, PAUSE, CRASH = 2, 3, 4, 5, 6, 7 -- (1 was the RF warning)

local state, last, acc = TITLE, 0, 0
local ignoreUntil = 0
local eatEnter = false -- the ENTER release that follows a long press
local saveOk = true
local count = 0 -- ticks spent in ARM (throttle low) / CRASH
local psel = 1 -- pause menu: 1 resume, 2 respawn, 3 quit
local ail, ele, thr, rud = 0, 0, -1024, 0
local frameTicks = 5 -- smoothed time between frames (10 ms units), for the DEBUG frame rate

-- switch the loaded group, freeing the other one first
local function menuMode()
  if flight then
    loaded.flight, loaded.render, loaded.solid, loaded.wire, loaded.sky, flight, render = nil, nil, nil, nil, nil, nil, nil
    collectgarbage()
  end
  if not menus then
    menus = use("menus")
    menus.saveOk = saveOk
    collectgarbage()
  end
end

local function flightMode()
  if menus then
    loaded.menus, menus = nil, nil
    collectgarbage()
  end
  if not flight then
    flight = use("flight")
    -- the map is built before render loads: its files (map, world.lua) are dropped right after
    flight.load(use(config.MAPFILE[config.v.MAP], true))
    flight.setup()
    render = use("render")
    collectgarbage()
  end
end

-- events (virtual + legacy; some constants are nil on some radios)
local function is(e, a, b, c, d)
  return e ~= 0 and (e == a or e == b or e == c or e == d)
end
local function isEnter(e) return is(e, EVT_VIRTUAL_ENTER, EVT_ENTER_BREAK, EVT_ROT_BREAK) end
local function isLong(e) return is(e, EVT_VIRTUAL_ENTER_LONG, EVT_ENTER_LONG, EVT_ROT_LONG) end
local function isExit(e) return is(e, EVT_VIRTUAL_EXIT, EVT_EXIT_BREAK) end
-- encoder, +/- keys or PAGE keys
local function isNext(e)
  return is(e, EVT_VIRTUAL_NEXT, EVT_VIRTUAL_INC_REPT, EVT_VIRTUAL_NEXT_PAGE, EVT_PLUS_BREAK)
end
local function isPrev(e)
  return is(e, EVT_VIRTUAL_PREV, EVT_VIRTUAL_DEC_REPT, EVT_VIRTUAL_PREV_PAGE, EVT_MINUS_BREAK)
end

local function go(s)
  state = s
  ignoreUntil = getTime() + 30
  if s >= ARM then flightMode() else menuMode() end
  if s == ARM then
    flight.spawn()
    count = 0
  end
  if s == CRASH then
    count = 0
    playTone(200, 300, 0, PLAY_NOW)
    playHaptic(150, 0, PLAY_NOW)
  end
  if s == PAUSE then psel = 1 end
end

local function readSticks()
  ail, ele, thr, rud = getValue("ail") or 0, getValue("ele") or 0, getValue("thr") or -1024, getValue("rud") or 0
end

local function update(e, steps)
  if state == TITLE then
    if isLong(e) then
      killEvents(e)
      eatEnter = true
      menus.sel, menus.editing = 1, false
      go(SETTINGS)
    elseif isEnter(e) then go(ARM)
    elseif isExit(e) then return 1 end
  elseif state == SETTINGS then
    local ev = isNext(e) and "next" or isPrev(e) and "prev" or isEnter(e) and "enter" or isExit(e) and "exit"
    if ev and menus.settingsEvent(ev) then
      saveOk = config.save()
      menus.saveOk = saveOk
      go(TITLE)
    end
  elseif state == ARM then
    -- like a real quad: throttle low to arm
    if isExit(e) then go(TITLE) return 0 end
    count = thr < -920 and count + steps or 0
    if count >= 6 then
      playTone(1000, 100, 0, PLAY_NOW)
      state = FLY
    end
  elseif state == FLY then
    if isExit(e) then go(PAUSE) return 0 end
    for _ = 1, steps do
      flight.tick(ail, ele, thr, rud)
      if flight.crashed then go(CRASH) break end
    end
  elseif state == CRASH then
    count = count + steps
    if count >= 30 or (count >= 6 and isEnter(e)) then go(ARM) end
  elseif state == PAUSE then
    if isNext(e) then psel = psel % 3 + 1
    elseif isPrev(e) then psel = (psel + 1) % 3 + 1
    elseif isExit(e) then go(TITLE)
    elseif isEnter(e) then
      if psel == 1 then state = FLY elseif psel == 2 then go(ARM) else go(TITLE) end
    end
  end
  return 0
end

local PAUSE_ITEMS = { "> RESUME", "> RESPAWN", "> QUIT" }

local function draw()
  lcd.clear()
  if state == TITLE then menus.title()
  elseif state == SETTINGS then menus.settings()
  else
    render.fps = frameTicks > 0 and 100 / frameTicks or 0
    render.draw(thr)
    if state == ARM then render.box("THROTTLE LOW", "TO ARM")
    elseif state == CRASH then render.box("CRASHED", "ENT: RESPAWN")
    elseif state == PAUSE then render.box("PAUSED", PAUSE_ITEMS[psel]) end
  end
end

local function init()
  config.load()
  saveOk = config.save()
  if #pending == 0 then menuMode() end -- else once the modules are compiled (run)
  last = getTime()
  ignoreUntil = last + 40
end

local function run(event)
  if np < #pending then
    np = np + 1
    local name = pending[np]
    collectgarbage()
    local chunk, err = loadScript(DIR .. name .. ".lua", "btc")
    if not chunk then error(err) end
    chunk = nil
    done = done .. name .. "\n"
    local f = io.open(DIR .. "compiled.txt", "a")
    if f then io.write(f, name, "\n") io.close(f) end
    lcd.clear()
    lcd.drawText(64, 28, "PREPARING " .. np .. "/" .. #pending, CENTER)
    if np == #pending then menuMode() end
    last = getTime()
    return 0
  end
  local now = getTime()
  frameTicks = frameTicks * 0.9 + (now - last) * 0.1
  acc = acc + now - last
  last = now
  if acc > 20 then acc = 20 end
  local steps = math.floor(acc / 5)
  acc = acc - steps * 5
  event = event or 0
  if eatEnter and isEnter(event) then
    eatEnter = false
    event = 0
  end
  if now < ignoreUntil then event = 0 end
  readSticks()
  local r = update(event, steps)
  if state >= ARM then lcd.resetBacklightTimeout() end
  draw()
  return r
end

-- use/state/loaded are for the test harness; EdgeTX only looks at init and run
return { init = init, run = run, use = use, state = function() return state end,
  loaded = function(n) return loaded[n] ~= nil end }
