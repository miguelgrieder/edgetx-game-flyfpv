-- METRO: Manhattan. You start at the southern tip facing north up Broadway (x = 0), avenues 16 m wide at
-- x = -32, 0, 32. Downtown the twin 60 m towers stand diagonally 18 m apart (a pole on the north one) with
-- a walkway over Broadway; midtown a stepped Empire State and a Chrysler with spires, a roof with a hole
-- and a chimney above it, and a pedestrian tunnel high across the west avenue between two blocks (fly
-- through it). The Brooklyn Bridge runs east on two pairs of pylons, the Statue of Liberty stands off to
-- the south-west, a subway tunnel under the east avenue, gates up Broadway, lamp posts along it and at
-- Central Park.
-- Every block is drawn, like the other maps (its worst view costs more than CITY's).
-- box = x, y, width (x), depth (y), height; fbox = x, y, bottom, w, d, h; tube = x, y, z, axis, length, side;
-- roof = x, y, height, side, hole; pole = x, y, height; fpole = x, y, bottom, height;
-- gate = x, y, axis (0 spans x, 1 spans y)
return {
  grid = 16,
  spawn = { 0, 0, 0 },
  sky = "night",
  box = {
    -46, 30, 10, 10, 60, -18, 50, 10, 10, 60,                       -- twin towers
    16, 30, 16, 10, 20, 48, 34, 16, 14, 14, 16, 52, 16, 10, 28,      -- downtown
    -48, 90, 16, 12, 22, -16, 88, 16, 10, 14, 48, 90, 16, 12, 18,    -- midtown
    16, 104, 14, 14, 40, -16, 120, 10, 10, 36,                       -- Empire State, Chrysler
    -48, 120, 12, 12, 16, 48, 120, 16, 12, 26,
    -36, -36, 6, 6, 6,                                               -- Liberty's pedestal
  },
  fbox = {
    16, 104, 40, 8, 8, 10, -16, 120, 36, 5, 5, 6,                    -- the towers' tops
    -36, -36, 6, 2.5, 2.5, 9,                                        -- Liberty
    66, 16, 7, 44, 4, 1,                                             -- Brooklyn Bridge deck
    -2.5, 52, 9, 21, 4, 1.5,                                         -- walkway over Broadway
  },
  fpole = { -18, 50, 60, 8, 16, 104, 50, 10, -16, 120, 42, 8, -35, -36, 15, 4 },
  roof = { 16, 72, 10, 14, 6 },
  tube = { 16, 72, 12, 2, 12, 4, 32, 60, 0.5, 0, 30, 3, -32, 89, 8, 1, 9, 3 },
  pole = { 54, 13.5, 18, 54, 18.5, 18, 78, 13.5, 18, 78, 18.5, 18, -40, 145, 5, 40, 145, 5,
    -6, 40, 5, 6, 100, 5 },
  gate = { 0, 10, 0, 0, 70, 0, 0, 110, 0, 32, 140, 0 },
}
