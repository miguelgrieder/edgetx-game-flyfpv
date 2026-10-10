-- METRO: a bigger city, 4 x 4 blocks 32 m apart (wide avenues at x = -32, 0, 32 and streets every 32 m
-- north). In the middle a plaza with a roof on four poles: a hole to fly up through and a chimney above it.
-- A bridge over the main avenue, a subway tunnel under the east avenue, lamp posts, gates. Blocks past
-- 36 m are not drawn (far) to keep it as fast as CITY.
-- box = x, y, width (x), depth (y), height; fbox = x, y, bottom, w, d, h; tube = x, y, z, axis, length, side;
-- roof = x, y, height, side, hole; pole = x, y, height; gate = x, y, axis (0 spans x, 1 spans y)
return {
  grid = 16,
  spawn = { 0, 0, 0 },
  far = 36,
  sky = "night",
  box = {
    -48, 24, 16, 16, 10, -16, 24, 14, 16, 22, 16, 24, 16, 12, 6, 48, 24, 16, 16, 16,
    -48, 56, 16, 16, 30, 48, 56, 12, 16, 12,
    -48, 88, 16, 16, 8, -16, 88, 16, 16, 14, 16, 88, 10, 10, 40, 48, 88, 16, 16, 18,
    -48, 120, 16, 16, 12, -16, 120, 16, 8, 5, 16, 120, 16, 16, 24, 48, 120, 16, 16, 10,
  },
  fbox = { 0, 88, 9, 18, 4, 1.5 },
  roof = { 0, 56, 10, 16, 6 },
  tube = { 0, 56, 12, 2, 12, 4, 32, 40, 0.5, 0, 30, 3 },
  pole = { -6, 14, 5, 6, 40, 5, -6, 72, 5, 6, 104, 5, -6, 134, 5 },
  gate = { 0, 8, 0, 32, 92, 0, -32, 40, 0, 0, 136, 0 },
}
