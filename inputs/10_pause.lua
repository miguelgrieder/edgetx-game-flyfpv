local L = dofile("inputs/_lib.lua")
return { frames = L.FLY + 30, fn = L.after(function(t)
  if t == 15 then return 0, 0, 0, 0, "exit" end
  if t == 25 then return 0, 0, 0, 0, "next" end
  return 0, 0, t < 15 and 0 or -1024, 0
end) }
