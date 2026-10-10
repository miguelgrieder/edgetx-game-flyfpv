-- shared scenario helpers. Frames 1..39: title (ENT at 20) -> throttle low -> flying
local M = {}
M.FLY = 40 -- first frame that is surely flying
function M.menu(f)
  if f == 20 then return 0, 0, -1024, 0, "enter" end
  return 0, 0, -1024, 0
end
-- run fn(t) once flying (t = frames since FLY)
function M.after(fn)
  return function(f)
    if f < M.FLY then return M.menu(f) end
    return fn(f - M.FLY)
  end
end
M.cfg = dofile("tools/harness.lua").cfg
return M
