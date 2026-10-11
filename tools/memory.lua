-- lua5.2 tools/memory.lua: compile allocations per built file and resident Lua heap per phase
-- (PC numbers: 64-bit, with debug info; the radio uses less, but the ratios hold)
local files = { "dist/SCRIPTS/TOOLS/flyfpv.lua" }
for _, n in ipairs({ "config", "items", "menus", "flight", "render", "solid", "world", "wire", "sky", "map_city", "map_metro", "map_space", "map_oval", "map_tech", "map_sky", "map_mega" }) do
  files[#files + 1] = "dist/SCRIPTS/TOOLS/FLYFPV/" .. n .. ".lua"
end
for _, p in ipairs(files) do
  collectgarbage("collect"); collectgarbage("stop")
  local a = collectgarbage("count")
  local f = assert(loadfile(p))
  local b = collectgarbage("count")
  collectgarbage("restart"); collectgarbage("collect")
  print(string.format("%-42s compile %6.1f KB  resident %6.1f KB", p, b - a, collectgarbage("count") - a))
  f = nil
end
collectgarbage("collect")
local mock = dofile("tools/mock/edgetx.lua")
local S = mock.install({ sdroot = mock.sd("memory"), clock = 1000, scriptDir = "dist/SCRIPTS/TOOLS/FLYFPV/" })
local function mem() S.tones, S.haptics, S.modules = {}, {}, {}; collectgarbage("collect"); return collectgarbage("count") end
local base = mem()
local app = dofile("dist/SCRIPTS/TOOLS/flyfpv.lua")
app.init()
local peak = 0
local function run(n, ev, thr)
  for f = 1, n do
    S.clock = S.clock + 5
    S.inputs.thr = thr or -1024
    app.run(f == 1 and ev or 0)
    local m = collectgarbage("count"); if m > peak then peak = m end
  end
end
run(12)
local menus = mem() - base
run(12, EVT_VIRTUAL_ENTER); run(10, EVT_VIRTUAL_ENTER); run(60, nil, 200)
local fly = mem() - base
print(string.format("resident: menus %.1f KB, flying %.1f KB (state %d); peak without forced GC %.1f KB", menus, fly, app.state(), peak - base))
