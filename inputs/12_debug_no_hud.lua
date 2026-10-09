local L = dofile("inputs/_lib.lua")
return { setup = L.cfg("HUD=0\nDEBUG=1\n"), frames = L.FLY + 20, fn = L.after(function(t)
  return 0, 0, t < 6 and -600 or -760, 0
end) }
