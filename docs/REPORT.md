# FlyFPV — report

## Done

Everything in the agreed plan: Betaflight actual rates (default 70/670/0), ACRO and ANGLE, five quad types
(whoop, 2.5", 3", 3.5", 5"), throttle-low arming, crash ON/OFF (whoop bounces), four maps loaded only while
flying, FPV camera with uptilt, horizon, ground grid, wireframe obstacles, HUD, DEBUG readout, settings menu
saved to the SD card, pause menu, RF warning. Split into small files with menus and flight never loaded
together. 34 tests, 13 screen goldens, a 14,400-frame soak, and runs in the real EdgeTX 2.12 firmware
(GX12, TX12, Boxer, Pocket) with menus and the arming view pixel-identical to the mock.

Not done: lap timer (not wanted), hidden-line removal (vanilla scope), real radio test.

## Please check on the GX12

1. It opens and the first flight starts (first run compiles each file).
2. Turn DEBUG ON: what CPU % (left number) do you see while flying in CITY? Smooth or choppy?
3. Do the default rates and the 5" feel right? Too twitchy / too floaty? Is the hover throttle (~13 %) believable?
4. Is the wireframe readable on the real screen (dotted far objects, grid, horizon)?
5. Camera angle: does 35° feel like your quad?
6. Crash detection: too strict or too lenient on landings?
