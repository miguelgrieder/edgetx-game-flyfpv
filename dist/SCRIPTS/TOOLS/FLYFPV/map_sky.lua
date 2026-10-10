-- SKY: a race in the air. Floating rings climbing north, a high tunnel east, a chimney to dive down (it
-- stops 2 m above the ground: exit under it), a roof with a hole high on its poles to fly up through, and
-- platforms to go over and under on the way back.
-- fbox = x, y, bottom, w, d, h; tube = x, y, z, axis, length, side (axis 0 along y, 1 along x, 2 up; length
-- 0 = a ring); roof = x, y, height, side, hole
return {
  grid = 10,
  spawn = { 0, 0, 0 },
  tube = {
    0, 20, 2, 0, 0, 3, 0, 40, 6, 0, 0, 3, 5, 60, 10, 0, 0, 3, 12, 80, 14, 1, 0, 3,
    35, 80, 14, 1, 24, 4, 60, 80, 2, 2, 14, 4, 60, 50, 4, 0, 0, 3,
  },
  roof = { 60, 25, 16, 14, 5 },
  fbox = { 40, 0, 8, 10, 10, 2, 20, -10, 3, 10, 6, 1.5 },
  fpole = { 0, 60, 4, 10, 30, 80, 2, 8 },
  gate = { 0, 8, 0 },
  pole = { 50, 10, 6, 72, 80, 6 },
}
