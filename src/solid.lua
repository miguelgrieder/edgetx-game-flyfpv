-- Flight group: solid boxes. Each box hides what was drawn behind it: its seen faces are merged
-- into one span per screen row (a box's outline is convex), erased, then only their edges are drawn.
-- Built by render with its projection helpers: use("solid")(tr, seg2, seg3, NEAR, CX, CY, F, drawLine).
local use = ...
local flight = use("flight")
local floor = math.floor

return function(tr, seg2, seg3, NEAR, CX, CY, F, drawLine)
  local VX, VY, VZ = {}, {}, {}
  for i = 1, 8 do VX[i], VY[i], VZ[i] = 0, 0, 0 end

  -- faces by corner index: x1 side, x2 side, y1 side, y2 side, top (the bottom is never seen)
  local FACES = { 1, 4, 8, 5, 2, 3, 7, 6, 1, 2, 6, 5, 4, 3, 7, 8, 5, 6, 7, 8 }
  local QX, QY, QZ, PX, PY = {}, {}, {}, {}, {}
  local RL, RR = {}, {} -- per screen row: left/right end of the current box's outline
  for y = 0, 63 do RL[y], RR[y] = 1e9, -1e9 end
  local rows, ylo, yhi = 0, 64, -1
  local px, py, pz = 0, 0, 0

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
    if y0 > y1 then return end
    if y0 < ylo then ylo = y0 end
    if y1 > yhi then yhi = y1 end
    -- walk each edge once over the rows it crosses (x steps by its slope)
    for i = 1, n do
      local j = i % n + 1
      local xa, ya, xb, yb = PX[i], PY[i], PX[j], PY[j]
      if ya > yb then xa, ya, xb, yb = xb, yb, xa, ya end
      local s0, s1 = math.ceil(ya), floor(yb)
      if s0 < y0 then s0 = y0 end
      if s1 > y1 then s1 = y1 end
      if s0 <= s1 then
        local k = yb > ya and (xb - xa) / (yb - ya) or 0
        local x = xa + (s0 - ya) * k
        for y = s0, s1 do
          if x < RL[y] then RL[y] = x end
          if x > RR[y] then RR[y] = x end
          x = x + k
        end
      end
    end
    -- vertices themselves (covers horizontal edges and rounding at the ends)
    for i = 1, n do
      local y = floor(PY[i] + 0.5)
      if y >= y0 and y <= y1 then
        local x = PX[i]
        if x < RL[y] then RL[y] = x end
        if x > RR[y] then RR[y] = x end
      end
    end
  end

  -- erase the box outline (the union of its visible faces is convex: one span per row)
  local function flush()
    for y = ylo, yhi do
      local xl, xr = RL[y], RR[y]
      if xl <= 127 and xr >= 0 and xl <= xr then
        if xl < 0 then xl = 0 end
        if xr > 127 then xr = 127 end
        drawLine(floor(xl + 0.5), y, floor(xr + 0.5), y, SOLID, ERASE)
        rows = rows + 1
      end
      RL[y], RR[y] = 1e9, -1e9
    end
    ylo, yhi = 64, -1
  end

  -- box edges as corner pairs with their two faces (1 x1, 2 x2, 3 y1, 4 y2, 5 top, 6 bottom)
  local EB = { 1, 2, 3, 6, 2, 3, 2, 6, 3, 4, 4, 6, 4, 1, 1, 6, 5, 6, 3, 5, 6, 7, 2, 5, 7, 8, 4, 5, 8, 5, 1, 5,
    1, 5, 1, 3, 2, 6, 2, 3, 3, 7, 2, 4, 4, 8, 1, 4 }
  local VIS = { false, false, false, false, false, false } -- faces seen (the bottom never is)
  local SX, SY = {}, {}

  -- add a screen-space edge to the row spans
  local function walk(xa, ya, xb, yb)
    if ya > yb then xa, ya, xb, yb = xb, yb, xa, ya end
    local s0, s1 = math.ceil(ya), floor(yb)
    if s0 < 0 then s0 = 0 end
    if s1 > 63 then s1 = 63 end
    if s0 <= s1 then
      if s0 < ylo then ylo = s0 end
      if s1 > yhi then yhi = s1 end
      local k = (xb - xa) / (yb - ya)
      local x = xa + (s0 - ya) * k
      for y = s0, s1 do
        if x < RL[y] then RL[y] = x end
        if x > RR[y] then RR[y] = x end
        x = x + k
      end
    end
    -- the end rows (horizontal edges, rounding)
    local y = floor(ya + 0.5)
    if y >= 0 and y <= 63 then
      if xa < RL[y] then RL[y] = xa end
      if xa > RR[y] then RR[y] = xa end
      if y < ylo then ylo = y end
      if y > yhi then yhi = y end
    end
    y = floor(yb + 0.5)
    if y >= 0 and y <= 63 then
      if xb < RL[y] then RL[y] = xb end
      if xb > RR[y] then RR[y] = xb end
      if y < ylo then ylo = y end
      if y > yhi then yhi = y end
    end
  end

  -- a solid box: hide what is behind its visible faces, then draw only their edges
  local function box(i, pat, cpx, cpy, cpz)
    px, py, pz, rows = cpx, cpy, cpz, 0
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
    VIS[1], VIS[2], VIS[3], VIS[4], VIS[5] = px < x1, px > x2, py < y1, py > y2, pz > z2
    local front = true
    for k = 1, 8 do
      local z = VZ[k]
      if z < NEAR then front = false break end
      SX[k], SY[k] = CX + F * VX[k] / z, CY - F * VY[k] / z
    end
    if front then
      -- whole box in front of the camera: its outline = the edges between a seen and an unseen face
      for e = 1, 48, 4 do
        if VIS[EB[e + 2]] ~= VIS[EB[e + 3]] then
          local a, b = EB[e], EB[e + 1]
          walk(SX[a], SY[a], SX[b], SY[b])
        end
      end
      flush()
      for e = 1, 48, 4 do
        if VIS[EB[e + 2]] or VIS[EB[e + 3]] then
          local a, b = EB[e], EB[e + 1]
          seg2(SX[a], SY[a], SX[b], SY[b], pat)
        end
      end
      return rows
    end
    -- camera close to the box: clip each seen face against the near plane
    for f = 1, 5 do
      if VIS[f] then fill(f) end
    end
    flush()
    for e = 1, 48, 4 do
      if VIS[EB[e + 2]] or VIS[EB[e + 3]] then
        local a, b = EB[e], EB[e + 1]
        seg3(VX[a], VY[a], VZ[a], VX[b], VY[b], VZ[b], pat)
      end
    end
    return rows
  end

  return box
end
