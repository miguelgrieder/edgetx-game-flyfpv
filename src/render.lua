-- Flight group: FPV camera view. Wireframe world projected from the quad's camera (uptilted),
-- clipped against the near plane and the screen (the firmware drops lines with off-screen
-- endpoints), horizon, ground grid, obstacles, HUD. No allocation per frame.
local use = ...
local config = use("config")
local flight = use("flight")

local M = {}

local floor, sin, cos = math.floor, math.sin, math.cos
M.F = 40 -- focal length in px: ~116 deg horizontal field of view
M.NEAR = 0.05 -- near plane (m)
M.FAR = 120 -- objects farther than this are skipped (m)
M.SOLID_D = 40 -- nearer than this: solid lines, farther: dotted
M.GRID_N = 3 -- grid lines each side of the quad (farther lines pile up at the horizon)
M.BUDGET = 400 -- max lcd calls per frame for the 3D view (edges + fill rows)
local CX, CY, F, NEAR = 64, 32, M.F, M.NEAR

-- camera: position and basis (right, up, forward) in world coordinates
local px, py, pz, rx, ry, rz, ux, uy, uz, fx, fy, fz = 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0
local lines = 0

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

-- Liang-Barsky against the screen rectangle 0..127 x 0..63
local t0, t1
local function edge(p, q)
  if p == 0 then return q >= 0 end
  local r = q / p
  if p < 0 then
    if r > t1 then return false end
    if r > t0 then t0 = r end
  else
    if r < t0 then return false end
    if r < t1 then t1 = r end
  end
  return true
end

-- draw a screen-space segment (floats, any size), clipped
local function seg2(x1, y1, x2, y2, pat)
  local dx, dy = x2 - x1, y2 - y1
  t0, t1 = 0, 1
  if edge(-dx, x1) and edge(dx, 127 - x1) and edge(-dy, y1) and edge(dy, 63 - y1) then
    lcd.drawLine(floor(x1 + t0 * dx + 0.5), floor(y1 + t0 * dy + 0.5),
      floor(x1 + t1 * dx + 0.5), floor(y1 + t1 * dy + 0.5), pat, FORCE)
    lines = lines + 1
  end
end
M.seg2 = seg2

-- draw a camera-space segment: near-plane clip, project, screen clip
local function seg3(xa, ya, za, xb, yb, zb, pat)
  if za < NEAR then
    if zb < NEAR then return end
    local t = (NEAR - za) / (zb - za)
    xa, ya, za = xa + (xb - xa) * t, ya + (yb - ya) * t, NEAR
  elseif zb < NEAR then
    local t = (NEAR - zb) / (za - zb)
    xb, yb, zb = xb + (xa - xb) * t, yb + (ya - yb) * t, NEAR
  end
  seg2(CX + F * xa / za, CY - F * ya / za, CX + F * xb / zb, CY - F * yb / zb, pat)
end
M.seg3 = seg3

-- world-space segment
local function line(x1, y1, z1, x2, y2, z2, pat)
  local ax, ay, az = tr(x1, y1, z1)
  local bx, by, bz = tr(x2, y2, z2)
  seg3(ax, ay, az, bx, by, bz, pat)
end

-- horizon: screen points whose ray is level ((sx-CX)*rz + (CY-sy)*uz + F*fz = 0)
local function horizon()
  if rz * rz > uz * uz then
    -- steep line: x as a function of y
    seg2(CX - ((CY + 1) * uz + F * fz) / rz, -1, CX - ((CY - 64) * uz + F * fz) / rz, 64, SOLID)
  elseif uz ~= 0 then
    seg2(-1, CY + ((-1 - CX) * rz + F * fz) / uz, 128, CY + ((128 - CX) * rz + F * fz) / uz, SOLID)
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
  for k = -N, N do
    local x, y = gx + k * S, gy + k * S
    if (x - px) * (x - px) < far * far then line(x, gy - L, 0, x, gy + L, 0, DOTTED) end
    if (y - py) * (y - py) < far * far then line(gx - L, y, 0, gx + L, y, 0, DOTTED) end
  end
end

-- is a sphere (camera coordinates) worth drawing?
local function visible(x, y, z, r)
  if z + r < NEAR or z - r > M.FAR then return false end
  local zz = z > NEAR and z or NEAR
  return (x < 0 and -x or x) - r < zz * CX / F and (y < 0 and -y or y) - r < zz * CY / F
end

local VX, VY, VZ = {}, {}, {}
for i = 1, 8 do VX[i], VY[i], VZ[i] = 0, 0, 0 end
-- box corners 1..4 bottom (x1y1, x2y1, x2y2, x1y2), 5..8 top; 12 edges
local EDGES = { 1, 2, 2, 3, 3, 4, 4, 1, 5, 6, 6, 7, 7, 8, 8, 5, 1, 5, 2, 6, 3, 7, 4, 8 }

-- faces by corner index: x1 side, x2 side, y1 side, y2 side, top (the bottom is never seen)
local FACES = { 1, 4, 8, 5, 2, 3, 7, 6, 1, 2, 6, 5, 4, 3, 7, 8, 5, 6, 7, 8 }
local QX, QY, QZ, PX, PY = {}, {}, {}, {}, {}
local RL, RR = {}, {} -- per screen row: left/right end of the current box's outline
for y = 0, 63 do RL[y], RR[y] = 1e9, -1e9 end
local rows, ylo, yhi = 0, 64, -1

-- add face f of the current box (VX/VY/VZ) to the row spans: near-plane clip, project, scan edges
local function fill(f)
  local n, o = 0, (f - 1) * 4
  for k = 1, 4 do
    local a, b = FACES[o + k], FACES[o + k % 4 + 1]
    local za, zb = VZ[a], VZ[b]
    if za >= NEAR then
      n = n + 1
      QX[n], QY[n], QZ[n] = VX[a], VY[a], za
    end
    if (za >= NEAR) ~= (zb >= NEAR) then
      local t = (NEAR - za) / (zb - za)
      n = n + 1
      QX[n], QY[n], QZ[n] = VX[a] + (VX[b] - VX[a]) * t, VY[a] + (VY[b] - VY[a]) * t, NEAR
    end
  end
  if n < 3 then return end
  local ymin, ymax = 1e9, -1e9
  for i = 1, n do
    local y = CY - F * QY[i] / QZ[i]
    PX[i], PY[i] = CX + F * QX[i] / QZ[i], y
    if y < ymin then ymin = y end
    if y > ymax then ymax = y end
  end
  local y0, y1 = math.ceil(ymin), floor(ymax)
  if y0 < 0 then y0 = 0 end
  if y1 > 63 then y1 = 63 end
  if y0 < ylo then ylo = y0 end
  if y1 > yhi then yhi = y1 end
  for y = y0, y1 do
    local xl, xr = 1e9, -1e9
    for i = 1, n do
      local j = i % n + 1
      local ya, yb = PY[i], PY[j]
      if (ya <= y and yb >= y) or (yb <= y and ya >= y) then
        local xa, xb = PX[i], PX[j]
        if ya ~= yb then xa = xa + (y - ya) * (xb - xa) / (yb - ya); xb = xa end
        if xa < xl then xl = xa end
        if xb < xl then xl = xb end
        if xa > xr then xr = xa end
        if xb > xr then xr = xb end
      end
    end
    if xl < RL[y] then RL[y] = xl end
    if xr > RR[y] then RR[y] = xr end
  end
end

-- erase the box outline (the union of its visible faces is convex: one span per row)
local function flush()
  for y = ylo, yhi do
    local xl, xr = RL[y], RR[y]
    if xl <= 127 and xr >= 0 and xl <= xr then
      if xl < 0 then xl = 0 end
      if xr > 127 then xr = 127 end
      lcd.drawLine(floor(xl + 0.5), y, floor(xr + 0.5), y, SOLID, ERASE)
      rows = rows + 1
    end
    RL[y], RR[y] = 1e9, -1e9
  end
  ylo, yhi = 64, -1
end

-- a solid box: hide what is behind its visible faces, then draw only their edges
local function box(i, pat)
  local W = flight.W
  local x1, y1, z1, x2, y2, z2 = W.x1[i], W.y1[i], W.z1[i], W.x2[i], W.y2[i], W.z2[i]
  VX[1], VY[1], VZ[1] = tr(x1, y1, z1)
  VX[2], VY[2], VZ[2] = tr(x2, y1, z1)
  VX[3], VY[3], VZ[3] = tr(x2, y2, z1)
  VX[4], VY[4], VZ[4] = tr(x1, y2, z1)
  VX[5], VY[5], VZ[5] = tr(x1, y1, z2)
  VX[6], VY[6], VZ[6] = tr(x2, y1, z2)
  VX[7], VY[7], VZ[7] = tr(x2, y2, z2)
  VX[8], VY[8], VZ[8] = tr(x1, y2, z2)
  -- a face is seen when the camera is on its outer side
  local s1, s2, s3, s4, s5 = px < x1, px > x2, py < y1, py > y2, pz > z2
  if s1 then fill(1) end
  if s2 then fill(2) end
  if s3 then fill(3) end
  if s4 then fill(4) end
  if s5 then fill(5) end
  flush()
  for f = 1, 5 do
    if (f == 1 and s1) or (f == 2 and s2) or (f == 3 and s3) or (f == 4 and s4) or (f == 5 and s5) then
      local o = (f - 1) * 4
      for k = 1, 4 do
        local a, b = FACES[o + k], FACES[o + k % 4 + 1]
        seg3(VX[a], VY[a], VZ[a], VX[b], VY[b], VZ[b], pat)
      end
    end
  end
end

-- gates: square opening + two legs to the ground (see-through, no fill)
local function gate(i, pat)
  local W = flight.W
  local hw, z1, z2 = flight.GATE_W, flight.GATE_Z1, flight.GATE_Z2
  local x, y = W.gx[i], W.gy[i]
  local ax, ay = W.ga[i] == 0 and hw or 0, W.ga[i] == 0 and 0 or hw
  VX[1], VY[1], VZ[1] = tr(x - ax, y - ay, z1)
  VX[2], VY[2], VZ[2] = tr(x + ax, y + ay, z1)
  VX[3], VY[3], VZ[3] = tr(x + ax, y + ay, z2)
  VX[4], VY[4], VZ[4] = tr(x - ax, y - ay, z2)
  VX[5], VY[5], VZ[5] = tr(x - ax, y - ay, 0)
  VX[6], VY[6], VZ[6] = tr(x + ax, y + ay, 0)
  for e = 1, 8, 2 do
    local a, b = EDGES[e], EDGES[e + 1]
    seg3(VX[a], VY[a], VZ[a], VX[b], VY[b], VZ[b], pat)
  end
  seg3(VX[1], VY[1], VZ[1], VX[5], VY[5], VZ[5], pat)
  seg3(VX[2], VY[2], VZ[2], VX[6], VY[6], VZ[6], pat)
end

-- everything in view, sorted far to near (painter's algorithm: near boxes hide what is behind)
local ORD, DST = {}, {}
local function objects()
  local W = flight.W
  local X1, Y1, Z1, X2, Y2, Z2, K = W.x1, W.y1, W.z1, W.x2, W.y2, W.z2, W.kind
  local n = 0
  for i = 1, W.nb do
    if K[i] > 0 then
      local mx, my, mz = (X1[i] + X2[i]) / 2, (Y1[i] + Y2[i]) / 2, (Z1[i] + Z2[i]) / 2
      local cx, cy, cz = tr(mx, my, mz)
      if visible(cx, cy, cz, ((X2[i] - X1[i]) + (Y2[i] - Y1[i]) + (Z2[i] - Z1[i])) / 2) then
        n = n + 1
        ORD[n], DST[n] = i, cx * cx + cy * cy + cz * cz
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
    if i < 0 then gate(-i, pat)
    elseif K[i] == 2 then
      line((X1[i] + X2[i]) / 2, (Y1[i] + Y2[i]) / 2, Z1[i], (X1[i] + X2[i]) / 2, (Y1[i] + Y2[i]) / 2, Z2[i], pat) -- pole
    else box(i, pat) end
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

local function debug()
  lcd.drawNumber(1, 57, getUsage(), SMLSIZE)
  lcd.drawNumber(20, 57, floor(collectgarbage("count")), SMLSIZE)
end

-- the whole view; returns the number of lcd calls of the 3D part (lines + fill rows)
function M.draw(thr)
  lines, rows = 0, 0
  M.camera()
  horizon()
  grid()
  objects()
  local n = lines + rows
  if config.v.HUD == 1 then hud(thr) end
  if config.v.DEBUG == 1 then debug() end
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
