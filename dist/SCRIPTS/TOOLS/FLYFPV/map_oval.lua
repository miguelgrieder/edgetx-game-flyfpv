-- OVAL: a fast race loop, 50 x 150 m. Up the west straight (gate, tunnel, gate), round the north end,
-- down the east straight (gate, a floating ring, gates), round the south end back to the start.
-- tube = x, y, z, axis, length, side (axis 0 along y, 1 along x; length 0 = a ring)
return {
  grid = 10,
  spawn = { -25, 5, 0 },
  gate = {
    -25, 20, 0, -25, 100, 0, -12, 128, 1, 12, 128, 1, 25, 100, 0, 25, 60, 0, 25, 20, 0,
    12, -8, 1, -12, -8, 1,
  },
  tube = { -25, 60, 0.5, 0, 20, 3, 25, 80, 4, 0, 0, 3 },
  pole = { 0, 120, 8, 0, 0, 8, -25, 135, 4, 25, 135, 4, 25, -15, 4, -25, -15, 4 },
  box = { 0, 60, 6, 70, 3 },
}
