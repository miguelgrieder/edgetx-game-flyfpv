-- Builds the SD card image in dist/: src/main.lua becomes SCRIPTS/TOOLS/freefpv.lua (with the TOOLS
-- header) and every other module goes to SCRIPTS/TOOLS/FREEFPV/<name>.lua, loaded with loadScript.
-- Each file compiles on its own on the radio (one big file runs out of memory while compiling).
local MODULES = { "config", "menus", "flight", "render", "solid", "world", "wire", "map_field", "map_gates", "map_poles", "map_city" }
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
local all = { main }
for _, name in ipairs(MODULES) do
  local f = io.open("src/" .. name .. ".lua", "rb")
  if f then
    f:close()
    local src = read("src/" .. name .. ".lua")
    assert(not src:find("require%("), name .. ": use use(), not require()")
    write(OUT .. "FREEFPV/" .. name .. ".lua", src)
    all[#all + 1] = src
  end
end

-- the build's stamp (version + hash of every file): the game forces a recompile of each module the
-- first time it loads it under a new stamp, so an old .luac can't outlive an update (see main.lua)
local h, text = 0, table.concat(all)
for i = 1, #text do h = (h * 31 + text:byte(i)) % 4294967296 end
local stamp = string.format("%s-%08x", read("src/config.lua"):match('M%.VERSION = "([^"]+)"'), h)
local f = assert(io.open(OUT .. "FREEFPV/build.txt", "wb"))
f:write(stamp .. "\n")
f:close()
print("stamp " .. stamp)
