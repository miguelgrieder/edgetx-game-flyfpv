-- METRO: Manhattan. You start at the southern tip facing north up Broadway (x = 0), avenues 16 m wide at
-- x = -32, 0, 32. Downtown the twin 60 m towers stand diagonally 6 m apart (a pole on the north one) and
-- two blocks joined by a walkway, a stepped Empire State with a spire across Broadway from a roof with a
-- hole, and three small blocks. The Brooklyn Bridge runs east from the east avenue: two towers of
-- poles with thin bars across and suspenders along the deck, and beside it a small park with trees, a
-- fountain and a chimney on four legs to fly up through. The Statue of Liberty
-- stands off to the south-west on her star base: pedestal, robe, crown, torch held up.
-- Every block is drawn, like the other maps (its worst view costs more than CITY's).
-- box = x, y, width (x), depth (y), height; fbox = x, y, bottom, w, d, h; tube = x, y, z, axis, length, side;
-- roof = x, y, height, side, hole; pole = x, y, height; fpole = x, y, bottom, height;
-- hpole = x, y, z, axis (0 along x, 1 along y), length
return {
  grid = 16,
  spawn = { 0, 0, 0 },
  sky = "night",
  box = {
    -42, 32, 10, 10, 60, -26, 48, 10, 10, 60,                       -- twin towers
    16, 30, 16, 10, 20, 16, 52, 16, 10, 28,                          -- the walkway's blocks
    -16, 74, 14, 14, 40,                                             -- Empire State
    -16, 12, 10, 8, 10, 16, 8, 10, 8, 12, -44, 70, 10, 10, 16,       -- small blocks
    -25.2, -25.2, 10, 10, 2,                                         -- Liberty's star base
  },
  fbox = {
    -16, 74, 40, 8, 8, 10,                                           -- the Empire State's top
    16, 41, 12, 3, 12, 1.5,                                          -- walkway
    -25.2, -25.2, 2, 6, 6, 5, -25.2, -25.2, 7, 2.6, 2.6, 9.4,        -- Liberty: pedestal, robe and head
    60, 16, 7, 40, 4, 1,                                             -- bridge deck
  },
  fpole = {
    -26, 48, 60, 8, -16, 74, 50, 10,                                 -- spires
    -26.1, -25.2, 16.4, 1, -24.3, -25.2, 16.4, 1, -25.2, -26.1, 16.4, 1, -- Liberty's crown,
    -25.2, -24.3, 16.4, 1, -25.2, -25.2, 16.4, 1, -23.8, -25.2, 12, 7,   -- her arm up to the torch
    54, 14.2, 8, 7, 58, 14.2, 8, 4, 62, 14.2, 8, 4, 66, 14.2, 8, 7,  -- bridge suspenders
    54, 17.8, 8, 7, 58, 17.8, 8, 4, 62, 17.8, 8, 4, 66, 17.8, 8, 7,
  },
  hpole = { 50, 16, 19.5, 1, 5, 70, 16, 19.5, 1, 5,               -- the bridge towers' bars
    44, 30, 3.6, 0, 2.4, 44, 30, 3.6, 1, 2.4, 52, 38, 3.6, 0, 2.4, 52, 38, 3.6, 1, 2.4 }, -- branches
  roof = { 16, 72, 10, 14, 6 },
  tube = { 44, 38, 3, 2, 8, 4 },                                   -- the park's chimney
  pole = { 50, 13.6, 20, 50, 18.4, 20, 70, 13.6, 20, 70, 18.4, 20,  -- bridge towers
    44, 30, 4, 52, 38, 4, 48, 34, 1.8,                               -- tree trunks, the fountain's jet
    41.9, 35.9, 3, 46.1, 35.9, 3, 41.9, 40.1, 3, 46.1, 40.1, 3 },   -- the chimney's legs
}
