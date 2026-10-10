-- CITY, 5": gentle climb to ~3 m, a short forward pitch, then cruise toward the gate
local L = dofile("inputs/_lib.lua")
return { frames = L.FLY + 40, fn = L.after(function(t)
  if t < 4 then return 0, 0, -600, 0 end
  if t < 6 then return 0, 300, -700, 0 end
  return 0, 0, -735, 0
end) }
