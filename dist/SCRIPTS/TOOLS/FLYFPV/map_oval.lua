-- OVAL: a fast race loop, 50 x 150 m. Up the west straight (gate, tunnel, gate), round the north end,
-- down the east straight (gate, a floating ring, gates), round the south end back to the start. A gantry
-- with start lights over the start, a control tower of poles with its cab in the infield, floodlights on
-- the four corners.
-- tube = x, y, z, axis, length, side (axis 0 along y, 1 along x; length 0 = a ring); hpole = x, y, z,
-- axis (0 along x, 1 along y), length; fpole = x, y, bottom, height; fbox = x, y, bottom, w, d, h;
-- frame = x, y, w, d, h
return {
  grid = 10,
  spawn = { -25, 5, 0 },
  gate = {
    -25, 20, 0, -25, 100, 0, -12, 128, 1, 12, 128, 1, 25, 100, 0, 25, 60, 0, 25, 20, 0,
    12, -8, 1, -12, -8, 1,
  },
  tube = { -25, 60, 0.5, 0, 20, 3, 25, 80, 4, 0, 0, 3 },
  pole = { 0, 120, 8, 0, 0, 8, -25, 135, 10, 25, 135, 10, 25, -15, 10, -25, -15, 10, -- floodlights
    -31, 10, 7, -19, 10, 7 },                                        -- the gantry's legs
  box = { 0, 60, 6, 70, 3 },
  hpole = { -25, 10, 7, 0, 12,                                       -- the gantry
    -25, 135, 10, 0, 3, 25, 135, 10, 0, 3, 25, -15, 10, 0, 3, -25, -15, 10, 0, 3 }, -- the lamps
  fpole = { -27, 10, 5.5, 1.5, -25, 10, 5.5, 1.5, -23, 10, 5.5, 1.5 }, -- start lights
  frame = { 0, 10, 6, 6, 15 },                                       -- the control tower
  fbox = { 0, 10, 15, 7, 7, 3 },                                     -- its cab
}
