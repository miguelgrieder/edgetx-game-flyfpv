-- Flight group: quad physics (Betaflight rates, acro/angle, thrust, drag), the loaded world
-- (collision boxes, gates) and collisions. Units: metres, seconds, radians inside; x east,
-- y north, z up. Attitude = body axes in world coordinates: f (forward), r (right), u (up).
local use = ...
local config = use("config")

local M = {}

local sqrt, sin, cos, abs, atan2, asin = math.sqrt, math.sin, math.cos, math.abs, math.atan2, math.asin
local G = 9.81
local RAD = math.pi / 180
-- SIM SPEED runs movement (gravity, thrust, drag, position) faster than real time; rotation stays real
-- time so the rates mean what they say. Each substep is 12.5 ms of simulated movement (a 5" at top speed
-- moves < 0.5 m: less than a gate bar + its size), so there are 4 x SIM SPEED substeps per 50 ms frame.
M.DT = 0.0125 -- simulated seconds of movement per substep
M.SUB, M.DTR, M.scale = 4, 0.0125, 1 -- substeps per frame, real seconds per substep (rotation), speed factor
M.ANGLE_MAX = 55 -- angle mode: full stick tilt (deg)
M.ANGLE_GAIN = 6 -- angle mode: deg/s of correction per deg of error

-- world: collision boxes (kind 1 box, 2 pole, 0 hidden gate bar / tunnel wall), gates, wire tunnels
-- and the stars of the sky (unit directions)
local W = { x1 = {}, y1 = {}, z1 = {}, x2 = {}, y2 = {}, z2 = {}, kind = {}, rad = {}, nb = 0, gx = {}, gy = {}, ga = {}, ng = 0,
  tx = {}, ty = {}, tz = {}, ta = {}, tl = {}, ts = {}, nt = 0, sx = {}, sy = {}, sz = {}, ns = 0 }
local NEARB, nnear = {}, 0 -- boxes close enough to touch during this frame
M.W = W

-- Betaflight "actual" rates: stick -1..1 -> deg/s (center sensitivity, max rate, expo in hundredths)
function M.rate(x, center, max, expo)
  local e = expo / 100
  local expof = abs(x) * (x ^ 5 * e + x * (1 - e))
  local move = max - center
  if move < 0 then move = 0 end
  return x * center + move * expof
end

-- gate: 2 m wide opening from 0.5 to 2.5 m; axis 0 = spans x (fly through along y), 1 = spans y
M.GATE_W, M.GATE_Z1, M.GATE_Z2 = 1, 0.5, 2.5

-- build the world from a map table (world.lua: loaded for this and dropped, it is not needed in flight)
function M.load(map)
  use("world", true)(M, map)
end

-- quad type and rates from the settings
function M.setup()
  local v = config.v
  local q = config.QUADS[v.QUAD]
  M.tw, M.lin, M.radius, M.bounce = q.tw, q.lin, q.radius, q.bounce
  M.kq = (q.tw * G - q.lin * q.vmax) / (q.vmax * q.vmax) -- quadratic drag: top speed at full throttle
  M.scale = v.SIM_SPEED / 10
  M.SUB = math.floor(4 * M.scale + 0.5)
  M.DTR = 0.05 / M.SUB
  M.lagK = M.DTR / (q.lag + M.DTR)
  M.angle, M.crashOn = v.MODE == 2, v.CRASH == 1 -- int
  M.rpC, M.rpM, M.rpE, M.yC, M.yM, M.yE = v.RP_CENTER, v.RP_MAX, v.RP_EXPO, v.Y_CENTER, v.Y_MAX, v.Y_EXPO
  M.cam = v.CAMERA * RAD
end

-- level attitude with heading h (radians, 0 = north, clockwise)
local function level(h)
  M.fx, M.fy, M.fz = sin(h), cos(h), 0
  M.rx, M.ry, M.rz = cos(h), -sin(h), 0
  M.ux, M.uy, M.uz = 0, 0, 1
end

-- on the ground at the map's spawn point
function M.spawn()
  M.px, M.py, M.pz = M.sx, M.sy, 0
  M.vx, M.vy, M.vz = 0, 0, 0
  M.wr, M.wp, M.wy = 0, 0, 0
  M.cr, M.cp, M.cy, M.drag = 0, 0, 0, M.lin
  level(M.sh * RAD)
  M.ground, M.crashed, M.t = true, false, 0
end

-- re-square the attitude: normalise f, make r orthogonal to f, u = r x f. The vectors are always
-- almost unit, so 1/length = (3 - length^2) / 2 is exact enough and needs no sqrt (slow on the radio)
local function orthonormalize()
  local fx, fy, fz = M.fx, M.fy, M.fz
  local s = (3 - (fx * fx + fy * fy + fz * fz)) / 2
  fx, fy, fz = fx * s, fy * s, fz * s
  local rx, ry, rz = M.rx, M.ry, M.rz
  local d = rx * fx + ry * fy + rz * fz
  rx, ry, rz = rx - d * fx, ry - d * fy, rz - d * fz
  s = (3 - (rx * rx + ry * ry + rz * rz)) / 2
  rx, ry, rz = rx * s, ry * s, rz * s
  M.fx, M.fy, M.fz, M.rx, M.ry, M.rz = fx, fy, fz, rx, ry, rz
  M.ux, M.uy, M.uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
end

-- rotate the body by small angles: roll a (right wing down), pitch b (nose down), yaw c (nose right)
local function rotate(a, b, c)
  -- angles per substep are small (< 0.1 rad): series instead of 6 sin/cos calls (no double FPU on the radio)
  local a2, b2, c2 = a * a, b * b, c * c
  local ca, sa, cb, sb = 1 - a2 / 2, a - a * a2 / 6, 1 - b2 / 2, b - b * b2 / 6
  local cc, sc = 1 - c2 / 2, c - c * c2 / 6
  local fx, fy, fz, rx, ry, rz, ux, uy, uz = M.fx, M.fy, M.fz, M.rx, M.ry, M.rz, M.ux, M.uy, M.uz
  -- roll about f
  ux, uy, uz, rx, ry, rz = ux * ca + rx * sa, uy * ca + ry * sa, uz * ca + rz * sa,
    rx * ca - ux * sa, ry * ca - uy * sa, rz * ca - uz * sa
  -- pitch about r
  fx, fy, fz, ux, uy, uz = fx * cb - ux * sb, fy * cb - uy * sb, fz * cb - uz * sb,
    ux * cb + fx * sb, uy * cb + fy * sb, uz * cb + fz * sb
  -- yaw about u
  fx, fy, fz, rx, ry, rz = fx * cc + rx * sc, fy * cc + ry * sc, fz * cc + rz * sc,
    rx * cc - fx * sc, ry * cc - fy * sc, rz * cc - fz * sc
  M.fx, M.fy, M.fz, M.rx, M.ry, M.rz, M.ux, M.uy, M.uz = fx, fy, fz, rx, ry, rz, ux, uy, uz
  orthonormalize()
end

-- obstacles: push the sphere out; CRASH ON crashes (a whoop bounces), CRASH OFF slides
local function collide()
  local px, py, pz, r = M.px, M.py, M.pz, M.radius
  local X1, Y1, Z1, X2, Y2, Z2 = W.x1, W.y1, W.z1, W.x2, W.y2, W.z2
  for k = 1, nnear do
    local i = NEARB[k]
    if px + r > X1[i] and px - r < X2[i] and py + r > Y1[i] and py - r < Y2[i] and pz - r < Z2[i] and pz + r > Z1[i] then
      local cx = px < X1[i] and X1[i] or (px > X2[i] and X2[i] or px)
      local cy = py < Y1[i] and Y1[i] or (py > Y2[i] and Y2[i] or py)
      local cz = pz < Z1[i] and Z1[i] or (pz > Z2[i] and Z2[i] or pz)
      local dx, dy, dz = px - cx, py - cy, pz - cz
      local d2 = dx * dx + dy * dy + dz * dz
      if d2 < r * r then
        if M.crashOn and not M.bounce then
          M.crashed = true
          return
        end
        local d = sqrt(d2)
        if d < 1e-6 then
          -- centre inside the box: leave through the nearest face
          local best = px - X1[i]
          cx, cy, cz, dx, dy, dz = X1[i], py, pz, -1, 0, 0
          if X2[i] - px < best then best, cx, dx = X2[i] - px, X2[i], 1 end
          if py - Y1[i] < best then best, cx, cy, dx, dy = py - Y1[i], px, Y1[i], 0, -1 end
          if Y2[i] - py < best then best, cx, cy, dx, dy = Y2[i] - py, px, Y2[i], 0, 1 end
          if Z2[i] - pz < best then best, cx, cy, cz, dx, dy, dz = Z2[i] - pz, px, py, Z2[i], 0, 0, 1 end
          if pz - Z1[i] < best then cx, cy, cz, dx, dy, dz = px, py, Z1[i], 0, 0, -1 end
          d = 1
        end
        local nx, ny, nz = dx / d, dy / d, dz / d
        px, py, pz = cx + nx * r, cy + ny * r, cz + nz * r
        local vn = M.vx * nx + M.vy * ny + M.vz * nz
        if vn < 0 then
          local k = M.bounce and 1.4 or 1 -- bounce keeps 40 % of the speed into the wall
          M.vx, M.vy, M.vz = M.vx - k * vn * nx, M.vy - k * vn * ny, M.vz - k * vn * nz
        end
      end
    end
  end
  M.px, M.py, M.pz = px, py, pz
end

-- one physics substep; sticks -1..1, throttle 0..1
function M.step(ail, ele, thr, rud)
  local dt, dtr = M.DT, M.DTR
  local T = thr * M.tw * G
  if M.ground then
    if T <= G * 1.02 then
      -- sitting on the ground: level and still until the thrust beats the weight
      M.vx, M.vy, M.vz = 0, 0, 0
      M.wr, M.wp, M.wy = 0, 0, 0
      return
    end
    M.ground = false
  end
  -- commanded body rates (deg/s)
  local cr, cp, cy = M.cr, M.cp, M.cy -- commanded rates, worked out once per frame in M.tick
  -- motors and inertia: the real rate follows the command with a lag
  local k = M.lagK
  M.wr = M.wr + (cr * RAD - M.wr) * k
  M.wp = M.wp + (cp * RAD - M.wp) * k
  M.wy = M.wy + (cy * RAD - M.wy) * k
  rotate(M.wr * dtr, M.wp * dtr, M.wy * dtr)
  -- thrust along u, gravity, drag (linear + quadratic)
  local vx, vy, vz = M.vx, M.vy, M.vz
  local drag = M.drag -- set once per frame from the speed (saves a sqrt per substep)
  vx = vx + (M.ux * T - drag * vx) * dt
  vy = vy + (M.uy * T - drag * vy) * dt
  vz = vz + (M.uz * T - G - drag * vz) * dt
  M.px, M.py, M.pz = M.px + vx * dt, M.py + vy * dt, M.pz + vz * dt
  M.vx, M.vy, M.vz = vx, vy, vz
  -- ground
  if M.pz <= 0 then
    local hs = sqrt(vx * vx + vy * vy)
    if M.crashOn and (vz < -3.5 or M.uz < 0.6 or hs > 5) then
      M.pz = 0
      M.crashed = true
      return
    end
    M.pz = 0
    if T <= G * 1.02 and M.uz > 0 then
      -- touchdown: settle level, keep the heading
      M.ground = true
      level(atan2(M.fx, M.fy))
    else
      M.vz = vz < 0 and 0 or vz
      M.vx, M.vy = vx * 0.8, vy * 0.8
    end
  end
  collide()
end

-- one 50 ms tick from raw stick values (-1024..1024)
function M.tick(ail, ele, thr, rud)
  local a, e, y = ail / 1024, ele / 1024, rud / 1024
  local t = (thr + 1024) / 2048
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  -- once per frame: commanded body rates (deg/s) and the drag factor
  if M.angle then
    local roll = atan2(-M.rz, M.uz) / RAD
    local fz = M.fz > 1 and 1 or (M.fz < -1 and -1 or M.fz)
    local pitch = asin(-fz) / RAD
    local cr = (a * M.ANGLE_MAX - roll) * M.ANGLE_GAIN
    local cp = (e * M.ANGLE_MAX - pitch) * M.ANGLE_GAIN
    if cr > M.rpM then cr = M.rpM elseif cr < -M.rpM then cr = -M.rpM end
    if cp > M.rpM then cp = M.rpM elseif cp < -M.rpM then cp = -M.rpM end
    M.cr, M.cp = cr, cp
  else
    M.cr, M.cp = M.rate(a, M.rpC, M.rpM, M.rpE), M.rate(e, M.rpC, M.rpM, M.rpE)
  end
  M.cy = M.rate(y, M.yC, M.yM, M.yE)
  local speed = M.speed()
  M.drag = M.kq * speed + M.lin
  -- broad phase: only boxes within this frame's reach are tested in the substeps
  local reach = speed * M.DT * M.SUB + M.radius + 1
  local px, py, pz = M.px, M.py, M.pz
  local X1, Y1, Z1, X2, Y2, Z2 = W.x1, W.y1, W.z1, W.x2, W.y2, W.z2
  nnear = 0
  for i = 1, W.nb do
    if px + reach > X1[i] and px - reach < X2[i] and py + reach > Y1[i] and py - reach < Y2[i]
      and pz - reach < Z2[i] and pz + reach > Z1[i] then
      nnear = nnear + 1
      NEARB[nnear] = i
    end
  end
  for _ = 1, M.SUB do
    M.step(a, e, t, y)
    if M.crashed then return end
  end
  M.t = M.t + 1
end

function M.speed() return sqrt(M.vx * M.vx + M.vy * M.vy + M.vz * M.vz) end

return M
