-- METRO in ANGLE mode: a short climb, then forward and banked right between the blocks
local L = dofile("inputs/_lib.lua")
return { setup = L.cfg("MAP=2\nMODE=2\n"), frames = L.FLY + 30, fn = L.after(function(t)
  if t < 5 then return 0, 0, -450, 0 end
  return 350, 400, -700, 0
end) }
