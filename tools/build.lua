-- Builds the SD card image in dist/: src/main.lua becomes SCRIPTS/TOOLS/freefpv.lua (with the TOOLS
-- header) and every other module goes to SCRIPTS/TOOLS/FREEFPV/<name>.lua, loaded with loadScript.
-- Each file compiles on its own on the radio (one big file runs out of memory while compiling).
local MODULES = { "config", "menus", "flight", "render", "map_field", "map_gates", "map_poles", "map_city" }
local OUT = "dist/SCRIPTS/TOOLS/"

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a"):gsub("\r\n", "\n")
  f:close()
  return s
end

local function write(path, text)
  assert((loadstring or load)(text, "=" .. path))
  local f = assert(io.open(path, "wb"))
  f:write(text)
  f:close()
  print(string.format("built %-38s %6d bytes", path, #text))
end

local main = read("src/main.lua")
assert(main:match("return { init = init, run = run"), "main.lua must return the script interface")
write(OUT .. "freefpv.lua", "-- TNS|FreeFPV|TNE\n-- FreeFPV (generated from src/ by tools/build.lua; edit the sources)\n" .. main)
for _, name in ipairs(MODULES) do
  local f = io.open("src/" .. name .. ".lua", "rb")
  if f then
    f:close()
    local src = read("src/" .. name .. ".lua")
    assert(not src:find("require%("), name .. ": use use(), not require()")
    write(OUT .. "FREEFPV/" .. name .. ".lua", src)
  end
end
