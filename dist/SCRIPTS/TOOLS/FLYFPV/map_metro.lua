-- METRO: Manhattan. You start at the southern tip facing north up Broadway (x = 0), avenues 16 m wide at
-- x = -32, 0, 32. Downtown the twin 60 m towers stand diagonally 6 m apart (a pole on the north one) and
-- two blocks joined by a walkway, a stepped Empire State with a spire across Broadway from a roof with a
-- hole, the Chrysler further north. The Brooklyn Bridge runs east from the east avenue: two towers of
-- poles with thin bars across and suspenders along the deck, and beside it a small park with trees, a
-- fountain and a chimney to fly up through, poles behind it. The Statue of Liberty
-- stands off to the south-west on her star base: pedestal, robe, crowned head, torch held up, tablet.
-- Every block is drawn, like the other maps (its worst view costs more than CITY's).
-- box = x, y, width (x), depth (y), height; fbox = x, y, bottom, w, d, h; tube = x, y, z, axis, length, side;
-- roof = x, y, height, side, hole; pole = x, y, height; fpole = x, y, bottom, height
return {
  grid = 16,
  spawn = { 0, 0, 0 },
  sky = "night",
  box = {
    -42, 32, 10, 10, 60, -26, 48, 10, 10, 60,                       -- twin towers
    16, 30, 16, 10, 20, 16, 52, 16, 10, 28,                          -- the walkway's blocks
    -16, 74, 14, 14, 40, -16, 120, 10, 10, 36,                       -- Empire State, Chrysler
    -25.2, -25.2, 10, 10, 2,                                         -- Liberty's star base
    48, 34, 2, 2, 0.6,                                               -- the park's fountain
  },
  fbox = {
    -16, 74, 40, 8, 8, 10, -16, 120, 36, 5, 5, 6,                    -- the towers' tops
    16, 41, 12, 3, 12, 1.5,                                          -- walkway
    -25.2, -25.2, 2, 6, 6, 5, -25.2, -25.2, 7, 2.6, 2.6, 8,          -- Liberty: pedestal, robe,
    -25.2, -25.2, 15, 1.4, 1.4, 1.4, -23.8, -25.2, 18, 0.8, 0.8, 0.8, -- head, torch,
    -26.8, -25.2, 11, 0.6, 1.2, 1.6,                                 -- tablet
    60, 16, 7, 40, 4, 1,                                             -- bridge deck, the towers' bars:
    50, 16, 19.4, 0.2, 5, 0.2, 70, 16, 19.4, 0.2, 5, 0.2,            -- thin, like poles across
    44, 30, 2.5, 2.4, 2.4, 2, 52, 38, 2.5, 2.4, 2.4, 2,              -- the park's trees
  },
  fpole = {
    -26, 48, 60, 8, -16, 74, 50, 10, -16, 120, 42, 8,                -- spires
    -26.1, -25.2, 16.2, 1, -24.3, -25.2, 16.2, 1, -25.2, -26.1, 16.2, 1, -- Liberty's crown,
    -25.2, -24.3, 16.2, 1, -25.2, -25.2, 16.4, 1, -23.8, -25.2, 12, 6,   -- her raised arm
    54, 14.2, 8, 7, 58, 14.2, 8, 4, 62, 14.2, 8, 4, 66, 14.2, 8, 7,  -- bridge suspenders
    54, 17.8, 8, 7, 58, 17.8, 8, 4, 62, 17.8, 8, 4, 66, 17.8, 8, 7,
    48, 34, 0.6, 1.2,                                                -- the fountain's jet
  },
  roof = { 16, 72, 10, 14, 6 },
  tube = { 44, 38, 3, 2, 8, 4 },                                   -- the park's chimney
  pole = { 50, 13.6, 20, 50, 18.4, 20, 70, 13.6, 20, 70, 18.4, 20,  -- bridge towers
    44, 30, 2.5, 52, 38, 2.5,                                         -- tree trunks
    41, 42, 8, 43, 42, 11, 45, 42, 11, 47, 42, 8 },                 -- poles behind the chimney
}
