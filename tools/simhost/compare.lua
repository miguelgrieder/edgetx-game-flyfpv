-- lua5.2 tools/simhost/compare.lua <sim_frames_dir> [<dir> ...]
-- Renders menu screens in the mock with the same key sequence as tools/simhost/inputs/*.txt and looks
-- for a pixel-identical frame among the PBMs captured from the real firmware.
local H = dofile("tools/harness.lua")
local FB = H.mock.FB
local realio, out = io, io.stdout

local frames = {}
for _, d in ipairs({ ... }) do
  for i = 1, 2000 do
    local f = realio.open(string.format("%s/frame_%04d.pbm", d, i), "rb")
    if not f then break end
    frames[#frames + 1] = { name = d .. "#" .. i, fb = FB.fromPbm(f:read("*a")) }
    f:close()
  end
end

local REFS = {
  { "title", { { 10 } } },
  { "settings p1, QUAD selected", { { 10 }, { 1, "long" }, { 1, "enter" }, { 8 }, { 1, "next" } } },
  { "settings p1, editing <3.5IN>", { { 10 }, { 1, "long" }, { 1, "enter" }, { 8 }, { 1, "next" },
    { 1, "enter" }, { 1, "prev" } } },
  { "settings p2", { { 10 }, { 1, "long" }, { 1, "enter" }, { 8 }, { 1, "next" },
    { 1, "enter" }, { 1, "prev" }, { 1, "enter" }, { 1, "next" }, { 1, "next" }, { 1, "next" }, { 1, "next" } } },
  { "arming on the field", { { 10 }, { 1, "enter" }, { 3 } } },
}

local fails = 0
for _, ref in ipairs(REFS) do
  local h = H.new({ sd = "compare", modelName = "MODEL01" })
  for _, s in ipairs(ref[2]) do
    for _ = 1, s[1] do h.step(0, 0, -1024, 0, s[2]) end
  end
  local best, bestName = 1e9, "-"
  for _, fr in ipairs(frames) do
    local d = fr.fb:diffCount(h.fb())
    if d < best then best, bestName = d, fr.name end
  end
  if best > 0 then fails = fails + 1 end
  out:write(string.format("%-34s %s (closest firmware frame %s, %d px differ)\n", ref[1],
    best == 0 and "IDENTICAL" or "DIFFERS", bestName, best))
end
os.exit(fails == 0 and 0 or 1)
