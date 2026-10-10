-- CITY: blocks with 8 m streets and an open square in the middle. A tunnel in the street between the two
-- south-west blocks, a roof with a hole on four poles where the north-east block was, a chimney held in
-- the air by four poles on top of the west tower (fly in under it), a pole on top of the 60 m east tower,
-- a walkway between the two north-west buildings.
-- box = x, y, width (x), depth (y), height; tube = x, y, z, axis, length, side (axis 0 along y, 2 up);
-- roof = x, y, height, side, hole; fbox = x, y, bottom, w, d, h; fpole = x, y, bottom, height;
-- pole = x, y, height; gate = x, y, axis
return {
  grid = 10,
  spawn = { 0, 0, 0 },
  box = {
    -18, 20, 10, 10, 12, 0, 20, 10, 10, 20, 18, 20, 10, 10, 9,
    -18, 38, 10, 10, 25, 18, 38, 10, 10, 60,
    -18, 56, 10, 10, 10, 0, 56, 10, 10, 18,
  },
  tube = { -9, 20, 0.5, 0, 10, 3, -18, 38, 29, 2, 8, 3 },
  roof = { 18, 56, 8, 10, 4 },
  fpole = { -19.6, 36.4, 25, 4, -16.4, 36.4, 25, 4, -19.6, 39.6, 25, 4, -16.4, 39.6, 25, 4, 18, 38, 60, 6 },
  fbox = { -9, 56, 6, 8, 3, 1.5 },
  pole = { 0, 38, 8 },
  gate = { 0, 9, 0 },
}
