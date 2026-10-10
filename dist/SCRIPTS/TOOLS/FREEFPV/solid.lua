-- Flight group: solid boxes, drawn far to near by render. A box's seen faces are merged into one span
-- per screen row (a box's outline is convex), erased (rows with the same span become one rectangle),
-- then only the seen faces' edges are drawn.
-- Built by render with its projection helpers: use("solid")(tr, seg2, seg3, NEAR, CX, CY, F, drawLine).
local use = ...
local flight = use("flight")
-- rounding with arithmetic (x - x % 1 = floor): math.floor/ceil are C calls, expensive on the radio
local function floor(x) return x - x % 1 end

return function(tr, seg2, seg3, NEAR, CX, CY, F, drawLine)
  local S = {}
  local VX, VY, VZ, SX, SY = {}, {}, {}, {}, {}
  for i = 1, 8 do VX[i], VY[i], VZ[i], SX[i], SY[i] = 0, 0, 0, 0, 0 end

  -- faces by corner index: x1 side, x2 side, y1 side, y2 side, top, bottom (seen only under a floating box)
  local FACES = { 1, 4, 8, 5, 2, 3, 7, 6, 1, 2, 6, 5, 4, 3, 7, 8, 5, 6, 7, 8, 1, 2, 3, 4 }
  -- box edges as corner pairs with their two faces (1 x1, 2 x2, 3 y1, 4 y2, 5 top, 6 bottom)
  local EB = { 1, 2, 3, 6, 2, 3, 2, 6, 3, 4, 4, 6, 4, 1, 1, 6, 5, 6, 3, 5, 6, 7, 2, 5, 7, 8, 4, 5, 8, 5, 1, 5,
    1, 5, 1, 3, 2, 6, 2, 3, 3, 7, 2, 4, 4, 8, 1, 4 }
  local VIS = { false, false, false, false, false, false } -- faces seen
  local front = true -- whole box in front of the near plane
  local QX, QY, QZ, PX, PY = {}, {}, {}, {}, {}
  -- the fill works in bands of 2 screen rows (half the work; edges are still drawn exactly):
  -- RL/RR[b] = left/right end of the current box's outline over rows 2b and 2b+1
  local RL, RR = {}, {}
  for b = 0, 31 do RL[b], RR[b] = 1e9, -1e9 end
  local ylo, yhi = 64, -1 -- rows touched

  local function span(y, x)
    local b = (y - y % 2) / 2
    if x < RL[b] then RL[b] = x end
    if x > RR[b] then RR[b] = x end
  end

  -- add a screen-space edge to the row spans
  local function walk(xa, ya, xb, yb)
    if ya > yb then xa, ya, xb, yb = xb, yb, xa, ya end
    local s0, s1 = -ya, yb - yb % 1
    s0 = -(s0 - s0 % 1) -- ceil
    if s0 < 0 then s0 = 0 end
    if s1 > 63 then s1 = 63 end
    if s0 <= s1 then
      if s0 < ylo then ylo = s0 end
      if s1 > yhi then yhi = s1 end
      local k = (xb - xa) / (yb - ya)
      local x = xa + (s0 - ya) * k
      for y = s0, s1 do
        span(y, x)
        x = x + k
      end
    end
    -- the end rows (horizontal edges, rounding)
    local y = ya + 0.5
    y = y - y % 1
    if y >= 0 and y <= 63 then
      span(y, xa)
      if y < ylo then ylo = y end
      if y > yhi then yhi = y end
    end
    y = yb + 0.5
    y = y - y % 1
    if y >= 0 and y <= 63 then
      span(y, xb)
      if y < ylo then ylo = y end
      if y > yhi then yhi = y end
    end
  end

  -- one outline edge of a box fully in front: fill the left (or right) ends of its rows directly
  local function side(xa, ya, xb, yb, mx, my)
    if ya > yb then xa, ya, xb, yb = xb, yb, xa, ya end
    local s0, s1 = -ya, yb - yb % 1
    s0 = -(s0 - s0 % 1) -- ceil
    if s0 < 0 then s0 = 0 end
    if s1 > 63 then s1 = 63 end
    if s0 > s1 then
      -- a (nearly) horizontal edge between two rows: let walk handle its end rows
      walk(xa, ya, xb, yb)
      return
    end
    if s0 < ylo then ylo = s0 end
    if s1 > yhi then yhi = s1 end
    local k = (xb - xa) / (yb - ya)
    local b0, b1 = (s0 - s0 % 2) / 2, (s1 - s1 % 2) / 2
    local lo, hi = xa < xb and xa or xb, xa < xb and xb or xa -- x never leaves the edge's own range
    -- per band take the outer of its two rows; the centre is right of a downward edge -> left side
    -- (only the first and last band can reach past the edge's ends: clamp just those)
    local left = ((xb - xa) * (my - ya) - (yb - ya) * (mx - xa)) < 0
    local T = left and RL or RR
    local x0 = xa + (2 * b0 - ya) * k + (left and (k < 0 and k or 0) or (k > 0 and k or 0))
    local k2 = 2 * k
    local x1 = x0 + (b1 - b0) * k2
    local v = x0 < lo and lo or (x0 > hi and hi or x0)
    if (left and v < T[b0]) or (not left and v > T[b0]) then T[b0] = v end
    v = x1 < lo and lo or (x1 > hi and hi or x1)
    if (left and v < T[b1]) or (not left and v > T[b1]) then T[b1] = v end
    local x = x0 + k2
    if left then
      for b = b0 + 1, b1 - 1 do
        if x < RL[b] then RL[b] = x end
        x = x + k2
      end
    else
      for b = b0 + 1, b1 - 1 do
        if x > RR[b] then RR[b] = x end
        x = x + k2
      end
    end
  end

  -- face f (camera close to the box): near-plane clip, project, walk its edges
  local function face(f)
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
    for i = 1, n do PX[i], PY[i] = CX + F * QX[i] / QZ[i], CY - F * QY[i] / QZ[i] end
    for i = 1, n do
      local j = i % n + 1
      walk(PX[i], PY[i], PX[j], PY[j])
    end
  end

  -- project box i (camera at cpx, cpy, cpz) and build its outline spans
  function S.outline(i, cpx, cpy, cpz)
    local W = flight.W
    local x1, y1, z1, x2, y2, z2 = W.x1[i], W.y1[i], W.z1[i], W.x2[i], W.y2[i], W.z2[i]
    -- 4 transforms; the other corners by adding the box's edge vectors (the transform is linear)
    local ax, ay, az = tr(x1, y1, z1)
    local bx, by, bz = tr(x2, y1, z1)
    local dx, dy, dz = tr(x1, y2, z1)
    local ex, ey, ez = tr(x1, y1, z2)
    local yx, yy, yz = dx - ax, dy - ay, dz - az -- world y edge
    local zx, zy, zz = ex - ax, ey - ay, ez - az -- world z edge
    VX[1], VY[1], VZ[1] = ax, ay, az
    VX[2], VY[2], VZ[2] = bx, by, bz
    VX[3], VY[3], VZ[3] = bx + yx, by + yy, bz + yz
    VX[4], VY[4], VZ[4] = dx, dy, dz
    VX[5], VY[5], VZ[5] = ex, ey, ez
    VX[6], VY[6], VZ[6] = bx + zx, by + zy, bz + zz
    VX[7], VY[7], VZ[7] = bx + yx + zx, by + yy + zy, bz + yz + zz
    VX[8], VY[8], VZ[8] = dx + zx, dy + zy, dz + zz
    -- a face is seen when the camera is on its outer side
    VIS[1], VIS[2], VIS[3], VIS[4], VIS[5], VIS[6] = cpx < x1, cpx > x2, cpy < y1, cpy > y2, cpz > z2, cpz < z1
    front = true
    for k = 1, 8 do
      local z = VZ[k]
      if z < NEAR then front = false break end
      local inv = F / z
      SX[k], SY[k] = CX + VX[k] * inv, CY - VY[k] * inv
    end
    if front then
      -- the outline = the edges between a seen and an unseen face; each is on the left or the right
      -- side of the (convex) outline, so it only sets that side of the rows it crosses
      local mx = (SX[1] + SX[2] + SX[3] + SX[4] + SX[5] + SX[6] + SX[7] + SX[8]) / 8
      local my = (SY[1] + SY[2] + SY[3] + SY[4] + SY[5] + SY[6] + SY[7] + SY[8]) / 8
      for e = 1, 48, 4 do
        if VIS[EB[e + 2]] ~= VIS[EB[e + 3]] then
          local a, b = EB[e], EB[e + 1]
          side(SX[a], SY[a], SX[b], SY[b], mx, my)
        end
      end
    else
      for f = 1, 6 do
        if VIS[f] then face(f) end
      end
    end
  end

  -- erase the outline from row top down (above top nothing has been drawn yet), one 2-row band at a
  -- time; consecutive bands with the same span become one rectangle. Returns lcd calls.
  function S.erase(top)
    local calls, rb, rl, rr = 0, -1, 0, 0
    local b0, b1 = (ylo - ylo % 2) / 2, (yhi - yhi % 2) / 2
    local bt = (top - top % 2) / 2
    for b = b0, bt - 1 do RL[b], RR[b] = 1e9, -1e9 end
    if bt > b0 then b0 = bt end
    for b = b0, b1 + 1 do
      local il, ir
      if b <= b1 then
        local xl, xr = RL[b], RR[b]
        if xl <= 127 and xr >= 0 and xl <= xr then
          if xl < 0 then xl = 0 end
          if xr > 127 then xr = 127 end
          il, ir = xl + 0.5, xr + 0.5
          il, ir = il - il % 1, ir - ir % 1
        end
        RL[b], RR[b] = 1e9, -1e9
      end
      if not (il and rb >= 0 and il == rl and ir == rr) then
        if rb >= 0 then
          lcd.drawFilledRectangle(rl, 2 * rb, rr - rl + 1, 2 * (b - rb), ERASE)
          calls = calls + 1
        end
        if il then rb, rl, rr = b, il, ir else rb = -1 end
      end
    end
    ylo, yhi = 64, -1
    return calls
  end

  -- the seen faces' edges, each once (after S.outline)
  function S.edges(pat)
    for e = 1, 48, 4 do
      if VIS[EB[e + 2]] or VIS[EB[e + 3]] then
        local a, b = EB[e], EB[e + 1]
        if front then seg2(SX[a], SY[a], SX[b], SY[b], pat)
        else seg3(VX[a], VY[a], VZ[a], VX[b], VY[b], VZ[b], pat) end
      end
    end
  end

  return S
end
