-- page 3 (yaw expo, HUD, DEBUG, EXIT), HUD selected
local evs = { [20] = "long", [24] = "enter" }
for f = 32, 54, 2 do evs[f] = "next" end
return { frames = 60, fn = function(f) return 0, 0, -1024, 0, evs[f] end }
