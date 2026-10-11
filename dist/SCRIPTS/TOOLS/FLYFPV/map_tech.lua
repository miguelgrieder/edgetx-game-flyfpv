-- TECH: a tight technical track. Slalom north, gate, right turn, south under a low bridge, left along the
-- south, up through a chimney (enter from below), dive down through the hole of a roof, back west through
-- a tunnel to the finish gate. A low limbo bar after the first gate (under or over it), and north of the
-- roof a frame of poles to thread between its floors.
-- fbox = x, y, bottom, w, d, h; tube = x, y, z, axis, length, side (axis 0 along y, 1 along x, 2 up);
-- roof = x, y, height, side, hole; hpole = x, y, z, axis (0 along x, 1 along y), length;
-- frame = x, y, w, d, h
return {
  grid = 6,
  spawn = { 0, 0, 0 },
  sky = "night",
  pole = { -3, 12, 8, 3, 20, 8, -3, 28, 8, 3, 36, 8, 12, 66, 6, 30, 10, 6,
    -3, 52, 1.8, 3, 52, 1.8 },                                       -- the limbo's posts
  gate = { 0, 45, 0, 12, 58, 1, 24, 45, 0, 24, 15, 0, 10, -20, 1 },
  fbox = { 24, 30, 3.5, 10, 3, 1.5 },
  box = { 12, 30, 6, 20, 4, 36, -6, 2, 8, 6 },
  tube = { 48, 0, 3, 2, 12, 4, 40, -20, 0.5, 1, 30, 3 },
  roof = { 70, 0, 10, 14, 5 },
  hpole = { 0, 52, 1.8, 0, 6 },                                      -- the limbo bar
  frame = { 58, 24, 8, 8, 12 },
}
