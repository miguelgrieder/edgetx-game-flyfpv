local T = dofile("tests/t.lua")

local function toTitle(h)
  h.wait(10) -- the game starts on the title (no warning screen any more)
  T.eq(h.app.state(), 2)
end

local function toSettings(h)
  toTitle(h)
  h.step(0, 0, -1024, 0, "long")
  h.step(0, 0, -1024, 0, "enter") -- release after the long press is swallowed
  h.wait(8)
  T.eq(h.app.state(), 3)
end

T.test("settings: edit values, a new quad brings its camera angle, saved on exit", function()
  local h = T.H.new({ sd = "t_menus" })
  toSettings(h)
  T.eq(h.menus.editing, false)
  h.step(0, 0, -1024, 0, "next") -- SKY
  h.step(0, 0, -1024, 0, "next") -- QUAD
  h.step(0, 0, -1024, 0, "enter")
  h.step(0, 0, -1024, 0, "prev") -- 5IN -> 3.5IN
  h.step(0, 0, -1024, 0, "enter")
  T.eq(h.config.v.QUAD, 4)
  T.eq(h.config.v.CAMERA, 30)
  T.eq(h.menus.label(h.config.item("QUAD")), "3.5IN")
  T.eq(h.menus.label(h.config.item("RP_EXPO")), "0.00")
  h.config.v.RP_EXPO = 35
  T.eq(h.menus.label(h.config.item("RP_EXPO")), "0.35")
  h.step(0, 0, -1024, 0, "exit")
  T.eq(h.app.state(), 2)
  local f = h.S.realio.open(h.S.sdroot .. "/SCRIPTS/TOOLS/FLYFPV/flyfpv.cfg", "rb")
  local text = f:read("*a")
  f:close()
  T.ok(text:find("QUAD=4"), "saved")
  -- a fresh start reads it back
  local h2 = T.H.new({ sd = "t_menus2", setup = T.H.cfg(text) })
  T.eq(h2.config.v.QUAD, 4)
  T.eq(h2.config.v.RP_EXPO, 35)
end)

T.test("corrupted settings are ignored line by line", function()
  local h = T.H.new({ sd = "t_menus3", setup = T.H.cfg("garbage\nMAP=99\nQUAD=2\nRP_MAX=675\nMODE=2\n") })
  T.eq(h.config.v.MAP, 1) T.eq(h.config.v.QUAD, 2) T.eq(h.config.v.RP_MAX, 670) T.eq(h.config.v.MODE, 2)
end)

T.test("menus and flight are never loaded together; the map file is not kept", function()
  local h = T.H.new({ sd = "t_groups" })
  toTitle(h)
  T.eq(h.app.loaded("menus"), true) T.eq(h.app.loaded("flight"), false)
  h.step(0, 0, -1024, 0, "enter")
  T.eq(h.app.state(), 4)
  T.eq(h.app.loaded("menus"), false) T.eq(h.app.loaded("flight"), true) T.eq(h.app.loaded("render"), true)
  T.eq(h.app.loaded("map_city"), false)
  h.wait(8)
  h.step(0, 0, -1024, 0, "exit")
  T.eq(h.app.state(), 6) -- pause
  h.wait(8)
  h.step(0, 0, -1024, 0, "exit")
  T.eq(h.app.state(), 2)
  T.eq(h.app.loaded("flight"), false) T.eq(h.app.loaded("menus"), true)
end)

T.test("arming needs the throttle low; then it flies; a crash respawns", function()
  local h = T.H.new({ sd = "t_arm" })
  toTitle(h)
  h.step(0, 0, 0, 0, "enter") -- throttle at 50 %
  h.wait(20, 0, 0, 0, 0)
  T.eq(h.app.state(), 4) -- still waiting
  h.wait(8, 0, 0, -1024, 0)
  T.eq(h.app.state(), 5)
  -- full throttle up, then dive into the ground: crash, then respawn on the ground
  h.wait(20, 0, 0, 1024, 0)
  T.ok(h.flight.pz > 5)
  for _ = 1, 200 do
    h.step(1024, 0, -1024, 0)
    if h.app.state() == 7 then break end
  end
  T.eq(h.app.state(), 7)
  h.wait(31)
  T.eq(h.app.state(), 4)
  T.eq(h.flight.pz, 0)
end)

T.test("pause menu: respawn and quit", function()
  local h = T.H.new({ sd = "t_pause" })
  toTitle(h)
  h.step(0, 0, -1024, 0, "enter")
  h.wait(8)
  h.wait(20, 0, 0, 0, 0)
  T.ok(h.flight.pz > 1, "flying")
  h.step(0, 0, 0, 0, "exit")
  h.wait(8)
  h.step(0, 0, 0, 0, "next")
  h.step(0, 0, 0, 0, "enter") -- RESPAWN
  T.eq(h.app.state(), 4)
  T.eq(h.flight.pz, 0)
end)

T.test("after an update each module is recompiled once, so an old .luac can't outlive it", function()
  local B, C = "/SCRIPTS/TOOLS/FLYFPV/build.txt", "/SCRIPTS/TOOLS/FLYFPV/compiled.txt"
  local function modes(h) return table.concat(h.S.loadModes, " ") end
  local function fly(h)
    toTitle(h)
    h.step(0, 0, -1024, 0, "enter")
    T.eq(h.app.state(), 4)
  end
  local h = T.H.new({ sd = "t_stamp", files = { [B] = "v9-1\n" } })
  fly(h)
  T.eq(modes(h), "config:btc menus:btc flight:btc map_city:btc world:btc render:btc solid:btc wire:btc")
  local f = h.S.realio.open(h.S.sdroot .. C, "rb")
  local done = f:read("*a")
  f:close()
  T.eq(done, "v9-1\nconfig\nmenus\nflight\nmap_city\nworld\nrender\nsolid\nwire\n")
  -- next start, same build: the .luac files are used
  local h2 = T.H.new({ sd = "t_stamp2", files = { [B] = "v9-1\n", [C] = done } })
  fly(h2)
  T.eq(modes(h2), "config:bt menus:bt flight:bt map_city:bt world:bt render:bt solid:bt wire:bt")
  -- a new build: recompiled again
  local h3 = T.H.new({ sd = "t_stamp3", files = { [B] = "v9-2\n", [C] = done } })
  T.eq(modes(h3), "config:btc menus:btc")
  -- no build file (running from src/): plain loads
  local h4 = T.H.new({ sd = "t_stamp4" })
  T.eq(modes(h4), "config:bt menus:bt")
end)

T.test("a new build compiles its modules one per frame before the menus load, then flies from the .luac", function()
  local B = "/SCRIPTS/TOOLS/FLYFPV/build.txt"
  local h = T.H.new({ sd = "t_prep", files = { [B] = "v9-1\nconfig\nmenus\nflight\nrender\nsolid\nmap_city\nworld\nwire\n" } })
  local function modes() return table.concat(h.S.loadModes, " ") end
  T.eq(modes(), "config:btc") -- nothing else loaded yet: each compile has the memory to itself
  h.wait(8)
  T.eq(modes(), "config:btc menus:btc flight:btc render:btc solid:btc map_city:btc world:btc wire:btc menus:bt")
  h.wait(4)
  T.eq(h.app.state(), 2)
  h.step(0, 0, -1024, 0, "enter")
  T.eq(h.app.state(), 4)
  T.ok(modes():find("menus:bt flight:bt map_city:bt world:bt render:bt solid:bt wire:bt$"), modes())
end)
