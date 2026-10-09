# Performance and memory

> **Update (SIM SPEED 2x + solid buildings):** render.lua compiles with 64.5 KB of allocations (GateRush's 69 KB
> pieces compile on a GX12), flying heap 90.5 KB, worst CITY view 290 lcd calls (edges + erase rows), soak max
> 315 per frame. Physics does 8 substeps per frame at 2.0x but only against nearby boxes.

PC measurements (Lua 5.2 64-bit with debug info; the radio stores compiled files without debug info and uses
32-bit pointers, so its numbers are lower, but the comparisons hold). `lua5.2 tools/memory.lua`:

| file | compile allocations | resident |
|---|---|---|
| freefpv.lua (launcher + state machine) | 36.6 KB | 15.8 KB |
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
