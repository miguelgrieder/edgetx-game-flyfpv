# Decisions

One line each: what — why — discarded alternative.

## Setup

- Same tooling as GateRush (mock of the B&W API with firmware fonts/rasteriser, harness, PBM goldens, firmware simulator host) — proven pixel-identical to EdgeTX 2.12 — new tooling.
- Split into a launcher + modules loaded with `loadScript` from the start, two groups never loaded together: menus / flight (+ the selected map only) — GateRush ran out of memory compiling one 47 KB file on a GX12 — single file.
- Sticks are read by function (`ail`, `ele`, `thr`, `rud`): the radio already maps them to physical sticks for its stick mode — a STICK MODE setting (needed in GateRush only to pick screen halves).
- Default rates = Betaflight 4.3+ Actual Rates defaults (center 70 °/s, max 670 °/s, expo 0) on all axes — the player asked for defaults.

## Build

- Attitude is a 3x3 rotation (body forward/right/up in world coordinates) rotated by small roll/pitch/yaw steps and re-squared every substep — plain numbers, no allocation, trivially used by the camera — quaternions (would need converting for the camera every frame).
- Rate response lag per quad (`lag`, s): the body rate eases toward the commanded rate — the single number that makes a whoop feel soft and a 5" snappy — modelling motors and inertia.
- Drag = linear (per quad) + quadratic chosen so full throttle tilted reaches the quad's top speed — speeds that match the type without a full aero model.
- Quad types replace the planned POWER setting; picking a quad sets its usual CAMERA ANGLE, which can still be changed.
- 4 physics substeps per 50 ms (12.5 ms): at top speed a 5" moves < 0.5 m per substep, less than a gate bar plus its radius, so it can't tunnel through obstacles — 2 substeps (tunnelled in tests).
- A quad whose centre ends up inside a box leaves through the nearest face — backing out along the velocity tunnelled through walls in tests.
- World = axis-aligned boxes only (poles are thin boxes, gates are 4 hidden bars + a drawn frame) — one cheap sphere/box test covers every collision — per-shape tests.
- Gates are axis-aligned (spanning x or y) — keeps them boxes — rotated gates.
- Sitting on the ground: still and level until thrust beats weight — simple and stable — full ground contact physics.
- Renderer: Liang–Barsky screen clipping (no bitwise ops needed) after a near-plane clip at 5 cm; bounding-sphere culling and a 120 m view distance; nearer than 40 m solid, farther dotted; 250-line budget. No hidden-line removal (wireframe see-through) — the "vanilla" scope.
- Horizon = the vanishing line of the ground plane, computed directly in screen space — 1 line, works inverted.
- Ground grid only within ~15x the altitude (at least 2 squares) and 3 squares each side — far lines squeezed into a solid band at the horizon.
- Arming like a real quad (throttle low) — prevents taking off at full throttle after a menu.
- Maps are loaded with `use(name, true)`: the data is copied into the world arrays and the map file is not kept.
- DEBUG shows `getUsage()` and `collectgarbage("count")` with `lcd.drawNumber` (no string building per frame); the test harness fixes the memory number so goldens stay deterministic.
- Lap timer on GATES: not built (the player said not needed).

## After the first real-radio test (user feedback)

- "Everything 2x faster, especially falling": SIM SPEED (default 2.0x) scales simulated time for movement only (gravity, thrust, drag, position); rotation and rate lag stay real time so Betaflight rates keep their meaning — doubling gravity/top speeds per quad (would need retuning every quad) / a global time scale (would double the rates too).
- Movement substeps stay 12.5 ms of simulated time (collision-safe), so there are 4 x SIM SPEED substeps per frame; a per-frame broad phase keeps only the boxes within reach so the extra substeps don't multiply collision work.
- Solid buildings: painter's algorithm (objects sorted far to near by insertion sort — no table library), each box's visible faces (camera on the outer side of the face plane) are near-clipped, projected and merged into one span per screen row (a box's outline is convex), erased with horizontal lines, then only the visible faces' edges are drawn — a z-buffer (no pixel access) / per-face fills (2–3x the rows: CITY worst 425 calls vs 290).
- 3D budget raised to 400 lcd calls (most are horizontal erase lines, the cheapest primitive); measured worst: CITY 290, soak max 315 per frame including the HUD.
- Known painter limits: very large boxes next to small ones can sort wrong at some angles (sorted by centre distance); gates stay see-through on purpose.
