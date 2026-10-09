-- short climb, then roll over and cut the throttle: hits the ground hard
local L = dofile("inputs/_lib.lua")
return { frames = L.FLY + 45, fn = L.after(function(t)
  if t < 6 then return 0, 0, 0, 0 end
  return 1024, 0, -1024, 0
end) }
