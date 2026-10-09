-- FreeFPV entry: module loader (step 1 stub; the state machine comes later)
local DIR = "/SCRIPTS/TOOLS/FREEFPV/"
local loaded = {}

-- nocache: load a data file once (maps) without keeping it
local function use(name, nocache)
  local m = loaded[name]
  if not m then
    local chunk, err = loadScript(DIR .. name .. ".lua")
    if not chunk then error(err) end
    m = chunk(use)
    if not nocache then loaded[name] = m end
  end
  return m
end

local config = use("config")
local state = 1

local function init() config.load() end
local function run() lcd.clear() return 0 end

return { init = init, run = run, use = use, state = function() return state end }
