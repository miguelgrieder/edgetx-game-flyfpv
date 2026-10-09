# Decisions

One line each: what — why — discarded alternative.

## Setup

- Same tooling as GateRush (mock of the B&W API with firmware fonts/rasteriser, harness, PBM goldens, firmware simulator host) — proven pixel-identical to EdgeTX 2.12 — new tooling.
- Split into a launcher + modules loaded with `loadScript` from the start, two groups never loaded together: menus / flight (+ the selected map only) — GateRush ran out of memory compiling one 47 KB file on a GX12 — single file.
- Sticks are read by function (`ail`, `ele`, `thr`, `rud`): the radio already maps them to physical sticks for its stick mode — a STICK MODE setting (needed in GateRush only to pick screen halves).
- Default rates = Betaflight 4.3+ Actual Rates defaults (center 70 °/s, max 670 °/s, expo 0) on all axes — the player asked for defaults.
