-- Flight group: FPV camera view. Wireframe world projected from the quad's camera (uptilted),
-- clipped against the near plane and the screen (the firmware drops lines with off-screen
-- endpoints), horizon, ground grid, obstacles, HUD. No allocation per frame.
local use = ...
local config = use("config")
local flight = use("flight")

local M = {}

local floor, sin, cos, sqrt = math.floor, math.sin, math.cos, math.sqrt
local drawLine = lcd.drawLine -- looked up once: it is called hundreds of times per frame
local FORCE, SOLID, DOTTED = FORCE, SOLID, DOTTED -- globals are a table lookup each time
M.F = 40 -- focal length in px: ~116 deg horizontal field of view
M.NEAR = 0.05 -- near plane (m)
M.FAR = flight.far or 120 -- objects farther than this are skipped (m); a map can see less (map.far)
M.SOLID_D = 40 -- nearer than this: solid lines, farther: dotted
M.GRID_N = 3 -- grid lines each side of the quad (farther lines pile up at the horizon)
M.BUDGET = 400 -- max lcd calls per frame for the 3D view (edges + fill rows)
local CX, CY, F, NEAR = 64, 32, M.F, M.NEAR
-- (the hottest lines write these as numbers, 64 32 40 0.05: in Lua an upvalue costs an instruction each
-- time it is read, a number in the code nothing)

-- camera: position and basis (right, up, forward) in world coordinates
local px, py, pz, rx, ry, rz, ux, uy, uz, fx, fy, fz = 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0
local lines, rows = 0, 0
-- topmost screen row drawn on so far this frame: everything above it is still blank, so solid boxes
-- don't need to erase there (a local: it is checked for every line)
local top = 64

function M.camera()
  local t = flight.cam
  local ct, st = cos(t), sin(t)
  px, py, pz = flight.px, flight.py, flight.pz + 0.03
  fx, fy, fz = flight.fx * ct + flight.ux * st, flight.fy * ct + flight.uy * st, flight.fz * ct + flight.uz * st
  ux, uy, uz = flight.ux * ct - flight.fx * st, flight.uy * ct - flight.fy * st, flight.uz * ct - flight.fz * st
  rx, ry, rz = flight.rx, flight.ry, flight.rz
end

-- world -> camera (right, up, depth)
local function tr(x, y, z)
  local dx, dy, dz = x - px, y - py, z - pz
  return dx * rx + dy * ry + dz * rz, dx * ux + dy * uy + dz * uz, dx * fx + dy * fy + dz * fz
end
M.tr = tr

-- No float == / ~= against an integer anywhere in the geometry: EdgeTX 2.12.2's Lua floors the float
-- first (0.87 ~= 0 is false, fixed in 2.12.4), which hid the level horizon on a GX12. Use < and >.

-- draw a screen-space segment (floats, any size), clipped
-- (v - v % 1 rounds without a function call: arithmetic is what costs on the radio)
local function seg2(x1, y1, x2, y2, pat)
  if x1 >= 0 and x1 <= 127 and y1 >= 0 and y1 <= 63 and x2 >= 0 and x2 <= 127 and y2 >= 0 and y2 <= 63 then
    local a, b, c, d = x1 + 0.5, y1 + 0.5, x2 + 0.5, y2 + 0.5
    b, d = b - b % 1, d - d % 1
    drawLine(a - a % 1, b, c - c % 1, d, pat, FORCE)
    lines = lines + 1
    if b < top then top = b end
    if d < top then top = d end
    return
  end
  -- Liang-Barsky against the screen rectangle 0..127 x 0..63: the part t0..t1 of the segment inside
  local dx, dy = x2 - x1, y2 - y1
  local t0, t1 = 0, 1
  if not (dx < 0 or dx > 0) then
    if x1 < 0 or x1 > 127 then return end
  else
    local ra, rb = -x1 / dx, (127 - x1) / dx
    if dx < 0 then ra, rb = rb, ra end
    if ra > 0 then t0 = ra end
    if rb < 1 then t1 = rb end
    if t0 > t1 then return end
  end
  if not (dy < 0 or dy > 0) then
    if y1 < 0 or y1 > 63 then return end
  else
    local ra, rb = -y1 / dy, (63 - y1) / dy
    if dy < 0 then ra, rb = rb, ra end
    if ra > t0 then t0 = ra end
    if rb < t1 then t1 = rb end
    if t0 > t1 then return end
  end
  local xa, ya, xb, yb = x1 + t0 * dx + 0.5, y1 + t0 * dy + 0.5, x1 + t1 * dx + 0.5, y1 + t1 * dy + 0.5
  ya, yb = ya - ya % 1, yb - yb % 1
  drawLine(xa - xa % 1, ya, xb - xb % 1, yb, pat, FORCE)
  lines = lines + 1
  if ya < top then top = ya end
  if yb < top then top = yb end
end
M.seg2 = seg2

-- draw a camera-space segment: near-plane clip, project, screen clip
local function seg3(xa, ya, za, xb, yb, zb, pat)
  if za < 0.05 then
    if zb < 0.05 then return end
    local t = (0.05 - za) / (zb - za)
    xa, ya, za = xa + (xb - xa) * t, ya + (yb - ya) * t, 0.05
  elseif zb < 0.05 then
    local t = (0.05 - zb) / (za - zb)
    xb, yb, zb = xb + (xa - xb) * t, yb + (ya - yb) * t, 0.05
  end
  seg2(64 + 40 * xa / za, 32 - 40 * ya / za, 64 + 40 * xb / zb, 32 - 40 * yb / zb, pat)
end
M.seg3 = seg3

-- vertical world segment (a pole) from z1 to z2: one transform, the top is the bottom + height along up
local function vline(x, y, z1, z2, pat)
  local ax, ay, az = tr(x, y, z1)
  local h = z2 - z1
  seg3(ax, ay, az, ax + h * rz, ay + h * uz, az + h * fz, pat)
end

-- horizon: screen points whose ray is level ((sx-CX)*rz + (CY-sy)*uz + F*fz = 0), drawn slightly curved
-- like a wide FPV lens shows it: the ends bend toward the screen centre by M.BOW of the line's distance
-- from it (through the centre it stays straight). Out of view nothing is drawn (seg2 clips it all).
-- Always solid: dotted it vanished among the dotted grid lines. Drawn before the objects, so buildings
-- still hide it.
M.BOW = 0.15
local HN = 8 -- curve segments
local function curve(x0, y0, x1, y1)
  local dx, dy = x1 - x0, y1 - y0
  local l = sqrt(dx * dx + dy * dy)
  local nx, ny = -dy / l, dx / l
  local b = M.BOW * ((CX - x0) * nx + (CY - y0) * ny)
  local px, py = x0 + nx * b, y0 + ny * b
  for k = 1, HN do
    local s = k / HN
    local o = (2 * s - 1) * (2 * s - 1) * b
    local x, y = x0 + dx * s + nx * o, y0 + dy * s + ny * o
    seg2(px, py, x, y, SOLID)
    px, py = x, y
  end
end

local function horizon()
  if rz * rz > uz * uz then
    -- steep line: x as a function of y
    curve(CX - ((CY + 1) * uz + F * fz) / rz, -1, CX - ((CY - 64) * uz + F * fz) / rz, 64)
  elseif uz < 0 or uz > 0 then
    curve(-1, CY + ((-1 - CX) * rz + F * fz) / uz, 128, CY + ((128 - CX) * rz + F * fz) / uz)
  end
end

-- dotted ground grid around the quad, snapped to the grid size
local function grid()
  local S, N = flight.grid, M.GRID_N
  local gx, gy = floor(px / S + 0.5) * S, floor(py / S + 0.5) * S
  local L = N * S
  -- low down, far lines squeeze into a band at the horizon: keep lines within ~15x the height
  local far = pz * 15
  if far < 2 * S then far = 2 * S end
  -- the south-west corner in camera space, one cell east (e) and north (n), a whole line (2N cells)
  local ox, oy, oz = tr(gx - L, gy - L, 0)
  local ex, ey, ez, nx, ny, nz = S * rx, S * ux, S * fx, S * ry, S * uy, S * fy
  local m = 2 * N
  local lx, ly, lz, kx, ky, kz = m * nx, m * ny, m * nz, m * ex, m * ey, m * ez
  for k = 0, m do
    local d = (k - N) * S
    local x, y = gx + d - px, gy + d - py
    if x * x < far * far then
      local ax, ay, az = ox + k * ex, oy + k * ey, oz + k * ez
      seg3(ax, ay, az, ax + lx, ay + ly, az + lz, DOTTED)
    end
    if y * y < far * far then
      local ax, ay, az = ox + k * nx, oy + k * ny, oz + k * nz
      seg3(ax, ay, az, ax + kx, ay + ky, az + kz, DOTTED)
    end
  end
end

-- is a sphere (camera coordinates) worth drawing? (objects() has the same test inline for boxes)
local KX, KY = CX / F, CY / F
local function visible(x, y, z, r)
  local far = M.FAR + r
  if z + r < NEAR or x * x + y * y + z * z > far * far then return false end
  local zz = z > NEAR and z or NEAR
  return (x < 0 and -x or x) - r < zz * KX and (y < 0 and -y or y) - r < zz * KY
end

-- solid boxes live in their own file (keeps each file small enough to compile on the radio)
local solid = use("solid")(tr, seg2, seg3, NEAR, CX, CY, F, drawLine)

-- corner scratch space for the wire tunnels (wire.lua)
local VX, VY, VZ = {}, {}, {}
for i = 1, 8 do VX[i], VY[i], VZ[i] = 0, 0, 0 end

-- gates: square opening + two legs to the ground (see-through, no fill)
local function gate(i, pat)
  local W = flight.W
  local hw, z1, z2 = flight.GATE_W, flight.GATE_Z1, flight.GATE_Z2
  local x, y = W.gx[i], W.gy[i]
  local along = W.ga[i] == 0 -- int; the opening spans x (else y)
  local ax, ay = along and hw or 0, along and 0 or hw
  -- the left foot transformed; the rest by adding the opening's width (a camera axis scaled) and heights
  local bx, by, bz = tr(x - ax, y - ay, 0)
  local w = 2 * hw
  local wx, wy, wz
  if along then wx, wy, wz = w * rx, w * ux, w * fx else wx, wy, wz = w * ry, w * uy, w * fy end
  local ax1, ay1, az1 = bx + z1 * rz, by + z1 * uz, bz + z1 * fz -- bottom bar, left
  local ax2, ay2, az2 = bx + z2 * rz, by + z2 * uz, bz + z2 * fz -- top bar, left
  seg3(ax1, ay1, az1, ax1 + wx, ay1 + wy, az1 + wz, pat)
  seg3(ax1 + wx, ay1 + wy, az1 + wz, ax2 + wx, ay2 + wy, az2 + wz, pat)
  seg3(ax2 + wx, ay2 + wy, az2 + wz, ax2, ay2, az2, pat)
  seg3(ax2, ay2, az2, ax1, ay1, az1, pat)
  seg3(ax1, ay1, az1, bx, by, bz, pat) -- legs
  seg3(ax1 + wx, ay1 + wy, az1 + wz, bx + wx, by + wy, bz + wz, pat)
end

-- tunnels and stars live in wire.lua, loaded on the first frame only for maps that have them
local wire
local function basis() return rx, ry, rz, ux, uy, uz, fx, fy, fz end

-- everything in view, sorted far to near (painter's algorithm: near boxes hide what is behind)
local ORD, DST = {}, {}
local function objects()
  local W = flight.W
  local X1, Y1, Z1, X2, Y2, Z2, K = W.x1, W.y1, W.z1, W.x2, W.y2, W.z2, W.kind
  local n = 0
  -- the boxes that are drawn come first in W (nv of them); the view test inline, it runs for every one
  local MX, MY, MZ, RAD, FAR = W.mx, W.my, W.mz, W.rad, M.FAR
  local crx, cry, crz, cux, cuy, cuz, cfx, cfy, cfz, cpx, cpy, cpz = rx, ry, rz, ux, uy, uz, fx, fy, fz, px, py, pz
  for i = 1, W.nv do
    local dx, dy, dz, r = MX[i] - cpx, MY[i] - cpy, MZ[i] - cpz, RAD[i]
    local cz = dx * cfx + dy * cfy + dz * cfz
    if cz + r > 0.05 then
      local cx, cy = dx * crx + dy * cry + dz * crz, dx * cux + dy * cuy + dz * cuz
      local d, far = cx * cx + cy * cy + cz * cz, FAR + r
      if d < far * far then
        local zz = cz > 0.05 and cz or 0.05
        if (cx < 0 and -cx or cx) - r < zz * 1.6 and (cy < 0 and -cy or cy) - r < zz * 0.8 then -- KX, KY
          n = n + 1
          ORD[n], DST[n] = i, d
        end
      end
    end
  end
  local zm = (flight.GATE_Z1 + flight.GATE_Z2) / 2
  for i = 1, W.ng do
    local cx, cy, cz = tr(W.gx[i], W.gy[i], zm)
    if visible(cx, cy, cz, 2) then
      n = n + 1
      ORD[n], DST[n] = -i, cx * cx + cy * cy + cz * cz
    end
  end
  -- tunnels: after the gates in ORD (-ng - i)
  for i = 1, W.nt do
    local l, s = W.tl[i], W.ts[i]
    local cx, cy, cz
    if W.ta[i] == 2 then cx, cy, cz = tr(W.tx[i], W.ty[i], W.tz[i] + l / 2) -- int
    else cx, cy, cz = tr(W.tx[i], W.ty[i], W.tz[i] + s / 2) end
    if visible(cx, cy, cz, l / 2 + s) then
      n = n + 1
      ORD[n], DST[n] = -W.ng - i, cx * cx + cy * cy + cz * cz
    end
  end
  -- insertion sort, farthest first (no table library on the radio)
  for i = 2, n do
    local o, d = ORD[i], DST[i]
    local j = i - 1
    while j >= 1 and DST[j] < d do
      ORD[j + 1], DST[j + 1] = ORD[j], DST[j]
      j = j - 1
    end
    ORD[j + 1], DST[j + 1] = o, d
  end
  local far2 = M.SOLID_D * M.SOLID_D
  for k = 1, n do
    if lines + rows >= M.BUDGET then return end
    local i = ORD[k]
    local pat = DST[k] > far2 and DOTTED or SOLID
    if i < -W.ng then
      -- a tunnel's centre can be far while its near end is close: solid by its nearest part
      local d = M.SOLID_D + W.tl[-i - W.ng] / 2
      wire.tube(-i - W.ng, DST[k] > d * d and DOTTED or SOLID)
    elseif i < 0 then gate(-i, pat)
    elseif K[i] == 2 then -- int
      vline(MX[i], MY[i], Z1[i], Z2[i], pat) -- pole
    else
      solid.outline(i)
      rows = rows + solid.erase(top)
      solid.edges(pat)
    end
  end
end

-- OSD: crosshair, throttle bar, mode, altitude (m), speed (km/h); DEBUG: CPU % and Lua KB
local function hud(thr)
  lcd.drawLine(61, 32, 67, 32, SOLID, FORCE)
  lcd.drawLine(64, 29, 64, 35, SOLID, FORCE)
  lcd.drawRectangle(0, 12, 4, 40, FORCE)
  local t = floor((thr + 1024) / 2048 * 38 + 0.5)
  if t > 0 then lcd.drawFilledRectangle(1, 51 - t, 2, t, FORCE) end
  lcd.drawText(1, 1, flight.angle and "ANGLE" or "ACRO", SMLSIZE)
  lcd.drawNumber(127, 1, floor(flight.pz + 0.5), SMLSIZE + RIGHT)
  lcd.drawNumber(127, 57, floor(flight.speed() * flight.scale * 3.6 + 0.5), SMLSIZE + RIGHT) -- as seen, km/h
end

-- DEBUG: live frames per second (set by main) and Lua memory in KB.
-- (getUsage() on B&W radios is the slowest frame since the script started, not the current one.)
M.fps = 20
local function debug()
  lcd.drawNumber(1, 57, floor(M.fps + 0.5), SMLSIZE)
  lcd.drawText(lcd.getLastRightPos() + 1, 57, "FPS", SMLSIZE)
  lcd.drawNumber(34, 57, floor(collectgarbage("count")), SMLSIZE)
  lcd.drawText(lcd.getLastRightPos() + 1, 57, "KB", SMLSIZE)
end

-- the whole view; returns the number of lcd calls of the 3D part (lines + fill rows)
function M.draw(thr)
  lines, rows, top = 0, 0, 64
  M.camera()
  solid.camera(px, py, pz, rx, ry, rz, ux, uy, uz, fx, fy, fz)
  local W = flight.W
  if not wire and (W.nt > 0 or W.ns > 0) then wire = use("wire")(tr, seg3, VX, VY, VZ, CX, CY, F, basis, M) end
  if wire then
    local t = wire.stars()
    if t < top then top = t end
  end
  horizon()
  grid()
  objects()
  local n = lines + rows
  if config.v.HUD == 1 then hud(thr) end -- int
  if config.v.DEBUG == 1 then debug() end -- int
  return n
end

-- centred message box over the view (two lines, second may be nil)
function M.box(a, b)
  local h = b and 22 or 13
  local y = 32 - floor(h / 2)
  lcd.drawFilledRectangle(14, y, 100, h, ERASE)
  lcd.drawRectangle(14, y, 100, h, FORCE)
  lcd.drawText(64, y + 3, a, CENTER)
  if b then lcd.drawText(64, y + 12, b, CENTER + SMLSIZE) end
end

return M
