-- CITY in ANGLE mode: climb between the blocks, banked right
local L = dofile("inputs/_lib.lua")
return { setup = L.cfg("MAP=4\nMODE=2\n"), frames = L.FLY + 40, fn = L.after(function(t)
  if t < 20 then return 0, 150, 300, 0 end
  return 500, 300, -200, 0
end) }
