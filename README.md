# FreeFPV (v2.1)

An FPV **acro trainer** for **EdgeTX radios with a 128×64 black & white screen** (Radiomaster TX12 / TX12 MK2 /
Boxer / Pocket / GX12 / Zorro, Jumper T-Pro / T-Lite / T20 — the `PCB=X7` family).

You look through the quad's camera and fly it with your sticks like a real quad: roll, pitch and yaw sticks set
rotation **rates** (Betaflight "actual rates"), throttle sets thrust, centred sticks hold the attitude. Flips,
rolls, inverted flight, all of it. A small wireframe world with fixed obstacles; no score, no levels.

![screens](docs/screens/contact_sheet.png)

## Install

1. Copy `dist/SCRIPTS/TOOLS/freefpv.lua` **and the whole folder** `dist/SCRIPTS/TOOLS/FREEFPV/` to
   `/SCRIPTS/TOOLS/` on the SD card:

   ```
   SD card
   └── SCRIPTS/TOOLS/
       ├── freefpv.lua        <- the launcher shown in TOOLS
       └── FREEFPV/           <- the game (config, menus, flight, render, solid, 4 maps) + your settings
   ```
2. On the radio: **SYS** → **TOOLS** → **FreeFPV**.

The radio compiles each file the first time it is used (a `.luac` appears next to it), so the first launch and
the first flight take a moment. The radio keeps using a `.luac` that is newer than its `.lua`, and a radio
clock ahead of the PC's makes an old `.luac` look newer than a freshly copied update, so the radio keeps
running the old version. Since v1.6 the game handles this for its own modules (`FREEFPV/build.txt` holds
the build's stamp; each module is recompiled once per new build, logged in `compiled.txt`). Only
`freefpv.luac` next to `freefpv.lua` is compiled by EdgeTX itself, so when updating **delete
`SCRIPTS/TOOLS/freefpv.luac`** (and, the first time you install v1.6, every `.luac` in `FREEFPV/`).
If the radio shows "not enough memory" the first time it compiles, open the game again: files that
were already compiled load from their `.luac`, which takes much less memory.

## Safety

The radio **keeps transmitting your sticks to the bound model while you play** (there is no warning screen):
disarm, better power the model off, before starting FreeFPV.

## Controls

| where | input | action |
|---|---|---|
| title | ENT · hold ENT · RTN | fly · settings · exit |
| arming | throttle | **throttle low to arm** (like a real quad); RTN back to the title |
| flying | sticks | Ail = roll, Ele = pitch, Rud = yaw, Thr = thrust; RTN = pause |
| pause | roller / PAGE, ENT | RESUME · RESPAWN · QUIT (RTN also quits) |
| crashed | — | respawns on the ground after 1.5 s (ENT for sooner) |

Sticks are read by function (`ail`, `ele`, `thr`, `rud`), so your radio's own stick mode applies — nothing to set.

## How it flies

- **ACRO:** the sticks command rotation rates with the Betaflight *actual rates* formula
  (`rate = x·center + (max − center)·|x|·(x⁵·expo + x·(1 − expo))`); centred sticks keep the current angle.
- **ANGLE:** self-levelling; the roll/pitch sticks set a tilt up to 55°. Yaw is still a rate.
- Thrust along the quad's up axis, gravity, drag (linear + quadratic → a top speed), air-mode style (rates work
  at zero throttle).
- **SIM SPEED** (default **2.0×**) runs all movement — gravity, thrust, drag, speed — faster than real time, so
  falls and dives feel like a real quad. Rotation stays real time: your rates mean exactly what they say.
  Physics runs 4 × SIM SPEED steps per 50 ms frame (collisions stay exact at any speed).
- **Ground:** a soft touchdown lands (settles level). With **CRASH ON**, hitting the ground hard (fast, steep or
  tilted) or touching an obstacle is a crash → respawn. A **whoop bounces** off obstacles instead (ducts).
  With **CRASH OFF** you slide along obstacles and never crash.
- **Camera:** ~116° wide, tilted up by CAMERA ANGLE, so you have to lean forward to fly forward.

### Quads

| QUAD | thrust/weight | hover | top speed | feel | camera |
|---|---|---|---|---|---|
| WHOOP | 2.5 | ~40 % | ~36 km/h | soft, stops fast, bounces off things | 15° |
| 2.5IN | 4 | ~25 % | ~70 km/h | quick | 20° |
| 3IN | 5 | ~20 % | ~90 km/h | quick | 25° |
| 3.5IN | 6 | ~17 % | ~110 km/h | sharp | 30° |
| 5IN | 8 | ~13 % | ~140 km/h | sharpest, carries speed | 35° |

### Maps (only the selected one is loaded, only while flying)

| MAP | what's there |
|---|---|
| CITY | blocks with 8 m streets and a square in the middle, a gate at the entrance; a tunnel in the street between two blocks, a roof with a hole on four poles where a block was, a chimney held in the air by four poles on top of a tower (fly in under it), a pole on top of another block |
| METRO | a bigger city: 14 blocks 32 m apart; a plaza with a roof on four poles (a hole to fly up through, a chimney above it), a bridge over the main avenue, a subway tunnel, lamp posts, gates. Blocks past 36 m are not drawn |
| SPACE | starry sky over a wide grid; floating blocks, a station, platforms, poles, tunnels, rings and a chimney at every height; a roof with a hole on tall poles |
| T_OVAL | race: fast 50 × 150 m loop; gates, a tunnel on the west straight, a floating ring on the east one |
| T_TECH | race: slalom, gates, under a low bridge, up through a chimney (enter from below), down through a roof's hole, back through a tunnel |
| T_SKY | race in the air: rings climbing north, a high tunnel, a chimney to dive down (exit under it), a roof hole to fly up through, platforms |

Tunnels, rings and chimneys are see-through wire (like gates); their walls still stop you. Every map's busiest view
costs about the same as CITY's (a test checks it with `tools/mapcost.lua`).

## Screen

Horizon (solid, slightly curved like a wide FPV lens shows it, rolls with you; nothing when it is out of view),
dotted ground grid around you, obstacles drawn **solid**: everything is
drawn far to near and each box hides what is behind it (grid, horizon, other buildings); only the faces you can
see get their edges drawn. Near objects have solid edges, far ones dotted; gates stay see-through. HUD: crosshair, throttle bar (left), ACRO/ANGLE, altitude in m (top right), speed in km/h (bottom
right). DEBUG adds the live frame rate (FPS, 20 is the most an EdgeTX script can get) and the Lua memory in KB at the
bottom left.

## Settings (hold ENT on the title; saved to `/SCRIPTS/TOOLS/FREEFPV/freefpv.cfg`)

| setting | range | default |
|---|---|---|
| MAP | CITY / METRO / SPACE / T_OVAL / T_TECH / T_SKY (T_ = race tracks) | CITY |
| QUAD | WHOOP / 2.5IN / 3IN / 3.5IN / 5IN (also sets CAMERA ANGLE) | 5IN |
| MODE | ACRO / ANGLE | ACRO |
| CRASH | ON / OFF | ON |
| CAMERA ANGLE | 0–60°, step 5 | 35° |
| SIM SPEED | 1.0×–3.0×, step 0.5 (movement speed; rotation stays real time) | 2.0× |
| R/P CENTER, R/P MAX, R/P EXPO | 10–400 °/s · 100–1800 °/s · 0.00–1.00 | 70 · 670 · 0.00 (Betaflight defaults) |
| YAW CENTER, YAW MAX, YAW EXPO | same | 70 · 670 · 0.00 |
| HUD | ON / OFF | ON |
| DEBUG | ON / OFF | OFF |

## Development

Same setup as GateRush: `src/` modules, `src/main.lua` is the launcher; `tools/build.lua` copies them into the SD
image in `dist/`. Two groups are never in memory together: **menus** (`menus`) and **flight** (`flight`, `render`,
`solid`, and `wire` only for maps with tunnels or stars). The selected map file and `world.lua`, which builds the
world from it, are loaded once and dropped. `config` stays loaded.

A map is a small file `src/map_<name>.lua` returning a table (all in metres; x east, y north):
`box = {x, y, width, depth, height, ...}` (on the ground), `fbox = {x, y, bottom, width, depth, height, ...}`
(floating), `pole = {x, y, height, ...}`, `fpole = {x, y, bottom, height, ...}`, `gate = {x, y, axis, ...}` (axis 0:
fly through northward), `tube = {x, y, z, axis, length, side, ...}` (wire tunnel; axis 0 runs north, 1 east, 2 up =
chimney; length 0 = a ring), `roof = {x, y, height, side, hole, ...}` (on 4 corner poles), `stars = count`,
`far = view distance`, `grid`, `spawn = {x, y, heading}`. Add it to `MAPS`/`MAPFILE` in `config.lua` and to
`tools/build.lua`.

| command (Lua 5.2; on Windows `lua52.exe`) | what |
|---|---|
| `lua5.2 tools/build.lua` | build `dist/` |
| `lua5.2 tests/run_all.lua` | rates, physics, render (projection, clipping, no allocation), world (maps, budget, gates), menus, 13 screen goldens (src and dist) |
| `lua5.2 tools/soak.lua 600` | random flying on every map × quad × crash setting |
| `lua5.2 tools/memory.lua` | compile memory per file, Lua heap in menus and in flight |
| `lua5.2 tools/cost.lua` | Lua instructions and C calls per frame in heavy CITY views (compares versions the way the radio would) |
| `lua5.2 tools/mapcost.lua [map_x ...]` | worst and mean cost per frame of each map over a scan of camera poses |
| `make sim` / `python tools/simhost/simu_host.py ...` | run it in the real EdgeTX firmware (Companion 2.12 DLLs), then `lua5.2 tools/simhost/compare.lua out/simu/fly out/simu/settings` |

New golden after an intended visual change: `APPROVE=1 lua5.2 tests/run_all.lua test_screens`, look at
`out/screens/*.pbm` (`python tools/snapshot.py png <pbm> <png>`), commit.

## Tested

| radio | mock | EdgeTX 2.12 firmware on PC | real radio |
|---|---|---|---|
| GX12 | ✓ all tests | ✓ fly, crash, settings; 6 screens pixel-identical to the mock | not yet |
| TX12, Boxer, Pocket | (same target) | ✓ fly scenario, no errors | not yet |

MIT license.
