-- MEGA: a whole city for the fast colour radios (TX15 class: ~5x a GX12's CPU, megabytes of RAM); a GX12 may
-- run out of memory or crawl. Start on the Grand Boulevard (x = 0) facing north, gates up it. Downtown: 16
-- towers of every height either side, the tall ones stepped with spires, skybridges between them. An
-- elevated train loops round downtown on pillars (rails, a train of 3 cars, a station with a canopy and a
-- platform). East a suspension bridge over the harbour (towers of poles, suspenders on the cable's curve, a
-- ring on the deck, a gate under it) to an island with a lighthouse, and a harbour beside it (a moored ship,
-- container cranes, a yard of container stacks). West a stadium (stands, floodlights,
-- goal gates, a tunnel to it). North a building site (frames, a half-built tower, two cranes) and the
-- 135 m mega tower closing the boulevard. South-west a park (trees, a fountain, a chimney on legs).
-- box = x, y, w, d, h; fbox = x, y, bottom, w, d, h; pole = x, y, h; fpole = x, y, bottom, h;
-- hpole = x, y, z, axis (0 along x, 1 along y), length; frame = x, y, w, d, h; gate = x, y, axis;
-- tube = x, y, z, axis, length, side; roof = x, y, height, side, hole
local box, fbox, pole, fpole, hpole, frame, gate, tube, roof = {}, {}, {}, {}, {}, {}, {}, {}, {}
local function add(t, ...)
  for k = 1, select("#", ...) do t[#t + 1] = select(k, ...) end
end

-- downtown: 4 x 4 towers 16 m square, heights 18..66 m; 42 m and up get a stepped top and a spire;
-- skybridges across the side streets halfway up the lower of each pair
local XS, YS, H = { -52, -24, 24, 52 }, { 48, 80, 112, 144 }, {}
for i = 1, 4 do
  H[i] = {}
  for j = 1, 4 do
    local h = 18 + (i * 37 + j * 23) % 7 * 8
    H[i][j] = h
    add(box, XS[i], YS[j], 16, 16, h)
    if h >= 42 then
      add(fbox, XS[i], YS[j], h, 10, 10, 10)
      add(fpole, XS[i], YS[j], h + 10, 12)
    end
  end
end
for j = 1, 4 do
  for _, p in ipairs({ { 1, 2, -38 }, { 3, 4, 38 } }) do
    local h = math.min(H[p[1]][j], H[p[2]][j])
    add(fbox, p[3], YS[j], h / 2, 12, 3, 2)
  end
end
add(gate, 0, 20, 0, 0, 64, 0, 0, 96, 0, 0, 128, 0, 0, 160, 0)

-- elevated train: a rectangle of twin rails 12 m up (x = +-76, y = 30 and 170), a pillar with a cross arm
-- every 20 m, a train of 3 cars on the east line, a station on the west line
for _, x in ipairs({ -76, 76 }) do
  add(hpole, x - 0.8, 100, 12, 1, 140, x + 0.8, 100, 12, 1, 140)
  for y = 30, 170, 20 do add(pole, x, y, 11.8) add(hpole, x, y, 11.9, 0, 2.4) end
end
for _, y in ipairs({ 30, 170 }) do
  add(hpole, 0, y - 0.8, 12, 0, 152, 0, y + 0.8, 12, 0, 152)
  for x = -56, 56, 28 do add(pole, x, y, 11.8) add(hpole, x, y, 11.9, 1, 2.4) end
end
add(fbox, 76, 92, 12.2, 2.4, 7, 2.2, 76, 100, 12.2, 2.4, 7, 2.2, 76, 108, 12.2, 2.4, 7, 2.2)
add(roof, -76, 100, 16, 14, 4)
add(fbox, -72, 100, 10, 3, 14, 1.5)

-- the suspension bridge: deck 10 m up from x = 90 to 210, towers of poles at 125 and 175, suspenders up to
-- the cable (40 m at the towers, 14 m mid-span, down to the deck at the ends), a ring on the deck, a gate under
add(fbox, 150, 100, 10, 120, 8, 1)
add(frame, 125, 100, 3, 10, 40, 175, 100, 3, 10, 40)
for x = 95, 205, 6 do
  local c
  if x < 125 then c = 12 + 28 * (x - 90) / 35
  elseif x > 175 then c = 12 + 28 * (210 - x) / 35
  else c = 14 + 26 * ((x - 150) / 25) ^ 2 end
  if math.abs(x - 125) > 2 and math.abs(x - 175) > 2 and c > 11.5 then
    add(fpole, x, 96.2, 11, c - 11, x, 103.8, 11, c - 11)
  end
end
add(tube, 150, 100, 11.5, 1, 0, 4)
add(gate, 150, 100, 0)
-- the island's lighthouse: base, tower, lamp room, a gallery of poles round it, a mast
add(box, 226, 100, 10, 10, 3, 226, 100, 5, 5, 24)
add(fbox, 226, 100, 24, 3.5, 3.5, 3)
add(fpole, 226, 100, 27, 3)
add(hpole, 226, 96.8, 24, 0, 6.4, 226, 103.2, 24, 0, 6.4, 222.8, 100, 24, 1, 6.4, 229.2, 100, 24, 1, 6.4)

-- the harbour south of the bridge: a quay, a ship moored along it (hull, bridge house, funnel, masts), two
-- container cranes over the ship (4 legs, beams, a boom out over the deck), a yard of container stacks
-- with a line round each container
add(box, 145, 66, 100, 4, 1.5)
add(box, 140, 56, 50, 10, 5)
add(fbox, 122, 56, 5, 8, 9, 6, 122, 56, 11, 3, 3, 5)
add(fpole, 148, 56, 5, 10, 160, 56, 5, 8)
for _, x in ipairs({ 135, 160 }) do
  add(pole, x - 4, 64, 20, x + 4, 64, 20, x - 4, 74, 20, x + 4, 74, 20)
  add(hpole, x - 4, 69, 20, 1, 10, x + 4, 69, 20, 1, 10, x, 64, 20, 0, 8, x, 74, 20, 0, 8)
  add(hpole, x, 60, 22, 1, 28)
end
for i = 0, 5 do
  local x, n = 112 + i * 12, 1 + i * 2 % 3
  for _, y in ipairs({ 82, 90 }) do
    add(box, x, y, 6, 2.6, 2.6 * n)
    for l = 1, n do add(hpole, x, y - 1.3, 2.6 * l, 0, 6, x, y + 1.3, 2.6 * l, 0, 6) end
  end
end

-- the stadium: four stands round a 64 x 40 field (open corners), floodlight towers in the corners, a goal
-- gate at each end, a tunnel on the way in from the train line
add(box, -150, 74, 64, 6, 6, -150, 126, 64, 6, 6, -185, 100, 6, 40, 8, -115, 100, 6, 40, 8)
for _, x in ipairs({ -185, -115 }) do
  for _, y in ipairs({ 74, 126 }) do
    add(pole, x, y, 26)
    add(hpole, x, y, 26, 0, 4, x, y, 26, 1, 4)
  end
end
add(gate, -176, 100, 1, -124, 100, 1)
add(tube, -95, 100, 0.5, 1, 20, 4)

-- the building site: two frames, a half-built tower (solid floors, a frame above), two cranes with hooks
add(frame, -30, 215, 14, 14, 40, 10, 220, 12, 12, 24, 40, 215, 14, 14, 36)
add(box, 40, 215, 14, 14, 12)
add(pole, -12, 232, 52, 56, 236, 44)
add(hpole, -4, 232, 52, 0, 40, 8, 232, 34, 1, 3, 50, 236, 44, 0, 30, 40, 236, 30, 1, 3)
add(fpole, 8, 232, 34, 18, 40, 236, 30, 14)

-- the mega tower: three steps, a spire with antenna arms
add(box, 0, 290, 20, 20, 60)
add(fbox, 0, 290, 60, 14, 14, 30, 0, 290, 90, 8, 8, 20)
add(fpole, 0, 290, 110, 25)
add(hpole, 0, 290, 125, 0, 6, 0, 290, 125, 1, 6)

-- the park: trees (a trunk, crossed branches), a fountain in the middle, a chimney on four legs
for _, x in ipairs({ -56, -46, -36 }) do
  for _, y in ipairs({ -36, -26, -16 }) do
    if x == -46 and y == -26 then add(pole, x, y, 2.2) -- the fountain's jet
    else add(pole, x, y, 4) add(hpole, x, y, 3.6, 0, 2.4, x, y, 3.6, 1, 2.4) end
  end
end
add(tube, -24, -26, 3, 2, 8, 4)
add(pole, -26.1, -28.1, 3, -21.9, -28.1, 3, -26.1, -23.9, 3, -21.9, -23.9, 3)

return {
  grid = 20,
  spawn = { 0, 0, 0 },
  sky = "day",
  far = 160,
  budget = 1200,
  box = box, fbox = fbox, pole = pole, fpole = fpole, hpole = hpole, frame = frame, gate = gate,
  tube = tube, roof = roof,
}
