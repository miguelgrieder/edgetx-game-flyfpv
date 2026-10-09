-- POLES: climb and roll to inverted (acro, full-stick roll for ~0.25 s)
local L = dofile("inputs/_lib.lua")
return { setup = L.cfg("MAP=3\n"), frames = L.FLY + 33, fn = L.after(function(t)
  if t < 25 then return 0, 0, 0, 0 end
  if t < 31 then return 1024, 0, -700, 0 end
  return 0, 0, -1024, 0
end) }
