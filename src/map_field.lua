-- FIELD: open grass with a few things to fly around. Loaded only while flying this map.
-- box = x, y, width (x), depth (y), height; pole = x, y, height; gate = x, y, axis (0 spans x, 1 spans y)
return {
  grid = 10,
  spawn = { 0, 0, 0 },
  box = { 0, 40, 4, 4, 4, 22, 55, 6, 6, 3, -25, 45, 3, 3, 9, 40, 15, 12, 2, 2, -35, 5, 2, 8, 3 },
  pole = { 10, 25, 6, -10, 25, 6, 0, 70, 14, -40, 70, 8 },
  gate = { 0, 15, 0, 30, 35, 1 },
}
