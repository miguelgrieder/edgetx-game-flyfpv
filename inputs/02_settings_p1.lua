-- hold ENT on the title: page 1, QUAD being edited
local evs = { [10] = "enter", [20] = "long", [24] = "enter", [32] = "next", [34] = "enter" }
return { frames = 40, fn = function(f) return 0, 0, -1024, 0, evs[f] end }
