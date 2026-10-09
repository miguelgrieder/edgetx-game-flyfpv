-- GATES with a whoop: low and slow toward the first gate (acro: short pitch pulse, then hold)
local L = dofile("inputs/_lib.lua")
return { setup = L.cfg("MAP=2\nQUAD=1\nCAMERA=15\n"), frames = L.FLY + 40, fn = L.after(function(t)
  if t < 6 then return 0, 0, -100, 0 end
  if t < 8 then return 0, 400, -180, 0 end
  return 0, 0, -160, 0
end) }
