# Performance and memory

> **Update (cheap pieces):** a solid box costs ~1.8-2k Lua instructions when in view (up to ~5.5k cut by the
> near plane) however small it looks; a pole ~100. So: boxes under a pixel from the camera are drawn as a
> line like a pole, and maps get horizontal poles (`hpole`, one line). METRO's thin details use them (bridge
> bars, tree branches). Tried and dropped: the dot rule at 2 px instead of 1 (METRO's worst view went up,
> 59k -> 65k: cheaper far boxes left room under the line budget for more near ones).

> **Update (settings out of flight):** the settings menu's items (ranges, labels, defaults) moved from config
> to items.lua, loaded for the menus and the .cfg and dropped while flying, where only config.v is read.
> Flying heap with stripped bytecode like the radio's, PC 64-bit: CITY 93.1 -> 86.8 KB, METRO 102.4 -> 96.1 KB.
> Tried and dropped: starting the far-to-near sort from last frame's order (on smooth flights it cost more
> than the sort it saved: 10.0k vs 9.9k instructions per frame). Rendering allocates nothing per frame (the
> ~2 KB seen after a full GC is the Lua stack growing back, not garbage).

> **Update (v2.1, speed round):** Lua instructions per frame, mean over a scan of camera poses on all 9 maps
> (`lua5.2 tools/bench.lua`, lcd calls swapped for an empty C function as on the radio): render 9163 -> 6260
> (-32 %), sum of each map's worst view 214k -> 156k (-27 %); physics at SIM SPEED 2.0 2665 -> 1750 (-34 %).
> CITY's worst view 29.9k -> 21.7k. Every change draws exactly the same pixels (`tools/samepix.lua`: 638k
> frames before/after the near-plane fill, 165k for the rest) and flies the same to the last digit. What did it:
> one transform per box / grid / gate / tunnel (the other corners are camera axes scaled), the view test inline
> with box centres and radii worked out at load and hidden boxes skipped, near-plane faces filled a band at a
> time (one call per row was a quarter of a close frame), the Liang-Barsky y edges inline, numbers instead of
> upvalues in the hottest lines, the 12 box edges tested as locals, physics substeps on locals. Tried and
> dropped: corners rounded once per box (no gain). Not done: passing unrounded floats to lcd.* (EdgeTX 2.12
> floors them, checked in the simulator, but older firmware may round to nearest). Find hot spots with
> `lua5.2 tools/profile.lua` (`HEAVY=15000` for the slow frames only).

> **Update (third real-radio round):** heavy CITY views: 17-23k Lua instructions and 9 math-library calls per
> frame (was 21-29k and ~300); physics 2.7k instructions and 5 C calls at SIM SPEED 2x (was 3.2k and 50).
> Soak max 184 lcd calls per frame (was 315). Compile: render 55 KB, solid 35 KB, flight 47 KB. Flying heap
> 103 KB on the PC (the radio showed ~48 KB). Measure with `lua5.2 tools/cost.lua`.

> **Update (faster solid boxes):** PC render time for a heavy CITY view 174 -> 90 us (physics with 8 substeps:
> 11 us). Compile allocations: render 52 KB, solid 24 KB, flight 47 KB. Flying heap 99 KB (PC). DEBUG shows a
> live frame rate now.

> **Update (SIM SPEED 2x + solid buildings):** render.lua compiles with 64.5 KB of allocations (GateRush's 69 KB
> pieces compile on a GX12), flying heap 90.5 KB, worst CITY view 290 lcd calls (edges + erase rows), soak max
> 315 per frame. Physics does 8 substeps per frame at 2.0x but only against nearby boxes.

PC measurements (Lua 5.2 64-bit with debug info; the radio stores compiled files without debug info and uses
32-bit pointers, so its numbers are lower, but the comparisons hold). `lua5.2 tools/memory.lua`:

| file | compile allocations | resident |
|---|---|---|
| flyfpv.lua (launcher + state machine) | 36.6 KB | 15.8 KB |
| config | 18.7 KB | 8.1 KB |
| menus | 26.0 KB | 10.9 KB |
| flight | 44.1 KB | 21.4 KB |
| render | 48.1 KB | 20.4 KB |
| each map | 2.6–4.7 KB | 1.2–1.7 KB |

For reference: GateRush's largest piece is 69 KB and compiles fine on a GX12; its single 47 KB file (271 KB of
compile allocations) did not.

Lua heap in use (after GC): **menus 40 KB, flying 77 KB** (GateRush while playing: 129 KB). Peak without forced
GC 85 KB. Rendering allocates nothing per frame (tested over 3000 frames).

## Draw calls (budget 250 for the 3D view, 300 per frame)

| | lines |
|---|---|
| worst view, spinning at 1 / 6 / 25 m: FIELD | 77 |
| GATES | 65 |
| POLES | 33 (45 before the grid limit) |
| CITY | 101–112 |
| soak: 14,400 frames of random flying, all maps × 3 quads × crash on/off | max 122 per frame |

## CPU per frame

- physics: 4 substeps × (rates, small rotation + re-squaring ~60 multiplies, forces, collision against every box
  with an early bounding test: ~40 boxes on CITY)
- render: per visible box 8 vertex transforms (9 multiplies each) + 12 clipped lines; ~14 grid lines; horizon
- the real cost on the STM32 is unknown until DEBUG is read on the radio (`getUsage()` %)
