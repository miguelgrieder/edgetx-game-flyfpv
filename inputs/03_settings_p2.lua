-- page 2 (rates), R/P MAX selected
local evs = { [20] = "long", [24] = "enter" }
for f = 32, 44, 2 do evs[f] = "next" end
return { frames = 50, fn = function(f) return 0, 0, -1024, 0, evs[f] end }
