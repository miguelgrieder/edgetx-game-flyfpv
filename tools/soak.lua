-- lua5.2 tools/soak.lua [frames per combo]
-- Random sticks (smoothed, like a clumsy pilot) on every map x quad x crash setting, through the real
-- state machine: no runtime error, <= 300 draw calls, no drawing off-screen (the mock errors), flat memory.
local H = dofile("tools/harness.lua")
local frames = tonumber(arg[1]) or 600
local out = io.stdout
local maxCalls, total, crashes = 0, 0, 0
local mem0
for map = 1, 4 do
  for quad = 1, 5, 2 do
    for crash = 0, 1 do
      local h = H.new({ sd = "soak", setup = H.cfg("MAP=" .. map .. "\nQUAD=" .. quad .. "\nCRASH=" .. crash .. "\n") })
      local seed = map * 100 + quad * 10 + crash
      local function rnd() seed = (seed * 16807) % 2147483647 return seed / 2147483647 * 2 - 1 end
      local a, e, t, r = 0, 0, -1024, 0
      for f = 1, frames do
        local ev = (f == 10 or f == 20) and "enter" or nil
        if h.app.state() == 7 then ev = (f % 10 == 0) and "enter" or nil end -- respawn quickly
        -- smoothed random sticks; throttle hovers around 35 %
        a, e, r = a * 0.9 + rnd() * 150, e * 0.9 + rnd() * 150, r * 0.9 + rnd() * 100
        t = t * 0.9 + (-300 + rnd() * 600) * 0.1
        local thr = (h.app.state() == 4) and -1024 or t
        h.step(a, e, thr, r, ev)
        h.S.tones, h.S.haptics = {}, {}
        if h.lastCalls > maxCalls then maxCalls = h.lastCalls end
        if h.app.state() == 7 and f % 10 == 1 then crashes = crashes + 1 end
        total = total + 1
      end
      collectgarbage("collect")
      if not mem0 then mem0 = collectgarbage("count") end
    end
  end
end
collectgarbage("collect")
local growth = collectgarbage("count") - mem0
out:write(string.format("soak: %d frames, %d maps x 3 quads x crash on/off, max draw calls %d, crashes seen %d, memory %+.1f KB\n",
  total, 4, maxCalls, crashes, growth))
if maxCalls > 300 or growth > 50 then out:write("FAIL\n") os.exit(1) end
