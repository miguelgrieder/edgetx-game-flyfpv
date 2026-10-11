-- SPACE: a starry sky over a wide ground grid; blocks, a station, platforms, poles, tunnels, rings and a
-- chimney float at every height. A roof with a hole stands on tall poles at the far end. To the west a
-- rocket on its pad beside a launch tower of poles; two square hoops of poles float to fly through.
-- fbox = x, y, bottom, w, d, h; fpole = x, y, bottom, h; tube = x, y, z, axis, length, side (axis 0 along
-- y, 1 along x, 2 up; length 0 = a ring); roof = x, y, height, side, hole; hpole = x, y, z, axis (0 along
-- x, 1 along y), length; frame = x, y, w, d, h; box/pole/gate as on the ground
return {
  grid = 20,
  spawn = { 0, 0, 0 },
  sky = "night",
  stars = 40,
  far = 60,
  box = { -40, 20, 6, 6, 3, 40, 130, 8, 8, 4, -38, 60, 3, 3, 22 },   -- ..., the rocket
  fbox = {
    0, 30, 6, 6, 6, 4, -20, 50, 12, 4, 4, 8, 25, 45, 18, 8, 8, 3, -30, 90, 25, 10, 10, 10,
    10, 110, 15, 20, 6, 2, 30, 80, 4, 4, 4, 20,
  },
  fpole = { 8, 20, 4, 6, -8, 35, 10, 8, 15, 65, 20, 10, -25, 70, 5, 12,
    -38, 60, 22, 5,                                                  -- the rocket's nose
    12, 90, 12, 6, 18, 90, 12, 6, -5, 117, 20, 6, -5, 123, 20, 6 },  -- the hoops' sides
  tube = {
    0, 60, 8, 0, 20, 4, -10, 100, 15, 1, 24, 4, 20, 30, 5, 0, 0, 3, -15, 20, 10, 1, 0, 3,
    30, 110, 10, 2, 15, 4,
  },
  roof = { 0, 140, 14, 14, 5 },
  gate = { 0, 12, 0 },
  frame = { -45, 60, 6, 6, 30 },                                     -- the launch tower
  hpole = { 15, 90, 12, 0, 6, 15, 90, 18, 0, 6, -5, 120, 20, 1, 6, -5, 120, 26, 1, 6 }, -- the hoops
}
