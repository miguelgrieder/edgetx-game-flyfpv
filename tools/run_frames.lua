-- lua5.2 tools/run_frames.lua --script inputs/x.lua --out out/x [--frames N] [--every n] [--nopbm] [--target src|dist]
-- Input script: return function(frame, t, ctx) -> ail, ele, thr, rud, event
-- or a table { fn = that function, frames = N, target = "src", setup = function(h) end }
local here = (debug.getinfo(1, "S").source:match("^@(.*[/\])") or "./")
local H = dofile(here .. "harness.lua")

local args = { every = 1 }
local i = 1
while i <= #arg do
  local k = arg[i]:match("^%-%-(.+)$")
  if k == "nopbm" then args[k] = true; i = i + 1
  elseif k then args[k] = arg[i + 1]; i = i + 2
  else i = i + 1 end
end
assert(args.script and args.out, "usage: run_frames.lua --script inputs/x.lua --out out/x [--frames N]")
local every = tonumber(args.every)
local out = args.out:gsub("[/\]$", "")
H.mock.mkdirp(out)

local input = dofile(args.script)
local opts = type(input) == "table" and input or { fn = input }
local name = args.script:match("([^/\]+)%.lua$")
local frames = tonumber(args.frames) or math.max(600, opts.frames or 0)
local h = H.new({ target = args.target or opts.target or "dist", sd = "frames_" .. name, setup = opts.setup })
local realio = h.S.realio

local function write(path, text)
  local f = assert(realio.open(path, "wb"))
  f:write(text)
  f:close()
end

local sumCalls, maxCalls, maxFrame, mem50, memMax = 0, 0, 0, nil, 0
local ran = 0
for f = 1, frames do
  local r = h.step(opts.fn(f, h.S.clock + 5, h.ctx))
  h.S.tones, h.S.haptics = {}, {} -- the mock's sound logs are not game memory
  ran = f
  local c = h.lastCalls
  sumCalls = sumCalls + c
  if c > maxCalls then maxCalls, maxFrame = c, f end
  if not args.nopbm and f % every == 0 then write(string.format("%s/frame_%04d.pbm", out, f), h.S.fb:pbm()) end
  if f % 50 == 0 then
    collectgarbage("collect")
    local m = collectgarbage("count")
    if f == 100 then mem50 = m end
    if f > 100 and m > memMax then memMax = m end
  end
  if r ~= 0 then break end
end
local growth = mem50 and memMax > 0 and (memMax - mem50) or 0
local metrics = string.format('{ "frames": %d, "draw_calls_max": %d, "draw_calls_max_frame": %d, '
  .. '"draw_calls_avg": %.1f, "mem_growth_kb": %.2f, "state": %d }\n',
  ran, maxCalls, maxFrame, sumCalls / ran, growth, h.app.state())
write(out .. "/metrics.json", metrics)
realio.stdout:write(name, ": ", metrics)
if growth > 2 then
  realio.stderr:write("FAIL: memory grew ", growth, " KB\n")
  os.exit(1)
end
