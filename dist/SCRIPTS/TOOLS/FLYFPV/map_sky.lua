-- SKY: a race in the air. Floating rings climbing north, a high tunnel east, a chimney to dive down (it
-- stops 2 m above the ground: exit under it), a roof with a hole high on its poles to fly up through, and
-- platforms to go over and under on the way back. Each obstacle sits a few metres to the side of the one
-- before, so the next is never dead ahead. A high wire between two tall masts, a square hoop of
-- poles, and a scaffold of poles to dive through its floors.
-- fbox = x, y, bottom, w, d, h; tube = x, y, z, axis, length, side (axis 0 along y, 1 along x, 2 up; length
-- 0 = a ring); roof = x, y, height, side, hole; hpole = x, y, z, axis (0 along x, 1 along y), length;
-- frame = x, y, w, d, h
return {
  grid = 10,
  spawn = { 0, 0, 0 },
  tube = {
    3, 20, 2, 0, 0, 3, -3, 40, 6, 0, 0, 3, 5, 60, 10, 0, 0, 3, 12, 83, 14, 1, 0, 3,
    35, 80, 14, 1, 24, 4, 60, 84, 2, 2, 14, 4, 63, 50, 4, 0, 0, 3,
  },
  roof = { 60, 25, 16, 14, 5 },
  fbox = { 40, 0, 8, 10, 10, 2, 20, -10, 3, 10, 6, 1.5 },
  fpole = { 0, 60, 4, 10, 30, 80, 2, 8, 27, 60, 8, 6, 33, 60, 8, 6 }, -- ..., the hoop's sides
  gate = { 0, 8, 0 },
  pole = { 50, 10, 6, 72, 80, 6, 20, 40, 16, 40, 40, 16 },           -- ..., the wire's masts
  hpole = { 30, 40, 16, 0, 20, 30, 60, 8, 0, 6, 30, 60, 14, 0, 6 },  -- the wire, the hoop
  frame = { 80, 50, 8, 8, 20 },                                      -- the scaffold
}
