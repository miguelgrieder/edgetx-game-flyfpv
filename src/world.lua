-- Flight group, used once per flight session: builds flight.W from a map table, then is dropped.
-- Map format:
-- { grid, spawn = {x, y, hdg}, box = {x, y, w, d, h, ...},
-- pole = {x, y, h, ...}, gate = {x, y, axis, ...}, fbox = {x, y, z, w, d, h, ...} (floating box, z = its
-- bottom), fpole = {x, y, z, h, ...}, hpole = {x, y, z, axis, length, ...} (horizontal, centred on x, y, z;
-- axis 0 along x, 1 along y), frame = {x, y, w, d, h, ...} (a building of poles: 4 corner poles and a
-- square of horizontal poles at a third, two thirds and the top), tube = {x, y, z, axis, length, side, ...}, roof = {x, y, z, side,
-- hole, ...}, sky = "day" | "night", stars = count (night), clouds = {azimuth, elevation, size, ...} and
-- sun = {azimuth, elevation} (day; degrees, azimuth clockwise from north), far = view distance in m
-- (default render.FAR: big maps see less, draw less) }
-- (the tables are built once here, when the map loads; nothing is allocated while flying)
local use = ...
local config = use("config")
local sqrt, sin, cos = math.sqrt, math.sin, math.cos
local RAD = math.pi / 180
local W

-- a day sky when the map does not set its own
local CLOUDS = { 20, 18, 1, 95, 25, 0.8, 160, 15, 1.2, 230, 22, 0.9, 300, 28, 1 }
local SUN = { 60, 30 }

-- hidden boxes (gate bars, tunnel walls) wait in H and go after the drawn ones, so render only walks
-- the first W.nv boxes
local H, nh = {}, 0
local function box(x1, y1, z1, x2, y2, z2, kind)
  if kind == 0 then -- int
    H[nh + 1], H[nh + 2], H[nh + 3], H[nh + 4], H[nh + 5], H[nh + 6] = x1, y1, z1, x2, y2, z2
    nh = nh + 6
    return
  end
  local n = W.nb + 1
  W.nb = n
  W.x1[n], W.y1[n], W.z1[n], W.x2[n], W.y2[n], W.z2[n], W.kind[n] = x1, y1, z1, x2, y2, z2, kind
  -- centre and bounding sphere radius, for render's view test (worked out once here)
  W.mx[n], W.my[n], W.mz[n] = (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2
  W.rad[n] = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) + (z2 - z1) * (z2 - z1)) / 2
end


-- a wire tunnel: square opening of side s, length l; axis 0 runs along y (like a gate with axis 0), 1 along
-- x, both with the opening's bottom at height z; axis 2 is a chimney: runs up from z, opening centred on x, y.
-- l = 0 is a single ring. Its 4 walls are hidden boxes (t thick, just outside the opening).
local function tube(x, y, z, a, l, s)
  local n = W.nt + 1
  W.nt, W.tx[n], W.ty[n], W.tz[n], W.ta[n], W.tl[n], W.ts[n] = n, x, y, z, a, l, s
  local t, h = 0.1, s / 2
  local L = (l > 0.2 and l or 0.2) / 2
  if a == 2 then -- int
    local z2 = z + 2 * L
    box(x - h - t, y - h - t, z, x - h, y + h + t, z2, 0)
    box(x + h, y - h - t, z, x + h + t, y + h + t, z2, 0)
    box(x - h, y - h - t, z, x + h, y - h, z2, 0)
    box(x - h, y + h, z, x + h, y + h + t, z2, 0)
    return
  end
  -- across (u) and height of the 4 walls: left, right, floor, ceiling
  local U1, U2 = { -h - t, h, -h - t, -h - t }, { -h, h + t, h + t, h + t }
  local Z1, Z2 = { z, z, z - t, z + s }, { z + s, z + s, z, z + s + t }
  for k = 1, 4 do
    if a == 0 then box(x + U1[k], y - L, Z1[k], x + U2[k], y + L, Z2[k], 0) -- int
    else box(x - L, y + U1[k], Z1[k], x + L, y + U2[k], Z2[k], 0) end
  end
end

-- a horizontal pole centred on x, y, z, length l, axis 0 along x, 1 along y: kind 3, drawn as one line
local function hpole(x, y, z, a, l)
  l = l / 2
  if a == 0 then box(x - l, y - 0.1, z - 0.1, x + l, y + 0.1, z + 0.1, 3) -- int
  else box(x - 0.1, y - l, z - 0.1, x + 0.1, y + l, z + 0.1, 3) end
end

-- a roof with a square hole: side s, hole side o, 0.3 m thick at height z, on 4 poles at its corners
local function roof(x, y, z, s, o)
  local S, h, z2 = s / 2, o / 2, z + 0.3
  box(x - S, y + h, z, x + S, y + S, z2, 1)
  box(x - S, y - S, z, x + S, y - h, z2, 1)
  box(x - S, y - h, z, x - h, y + h, z2, 1)
  box(x + h, y - h, z, x + S, y + h, z2, 1)
  for k = 1, 4 do
    local px, py = x + (k < 3 and -S or S), y + (k % 2 * 2 - 1) * S
    box(px - 0.1, py - 0.1, 0, px + 0.1, py + 0.1, z, 2)
  end
end

return function(M, map)
  W = M.W
  W.nb, W.ng, W.nt, W.ns, nh = 0, 0, 0, 0, 0
  local b = map.box or {}
  for i = 1, #b, 5 do
    local x, y, w, d, h = b[i], b[i + 1], b[i + 2] / 2, b[i + 3] / 2, b[i + 4]
    box(x - w, y - d, 0, x + w, y + d, h, 1)
  end
  b = map.fbox or {}
  for i = 1, #b, 6 do
    local x, y, z, w, d = b[i], b[i + 1], b[i + 2], b[i + 3] / 2, b[i + 4] / 2
    box(x - w, y - d, z, x + w, y + d, z + b[i + 5], 1)
  end
  local p = map.pole or {}
  for i = 1, #p, 3 do box(p[i] - 0.1, p[i + 1] - 0.1, 0, p[i] + 0.1, p[i + 1] + 0.1, p[i + 2], 2) end
  p = map.fpole or {}
  for i = 1, #p, 4 do box(p[i] - 0.1, p[i + 1] - 0.1, p[i + 2], p[i] + 0.1, p[i + 1] + 0.1, p[i + 2] + p[i + 3], 2) end
  p = map.hpole or {}
  for i = 1, #p, 5 do hpole(p[i], p[i + 1], p[i + 2], p[i + 3], p[i + 4]) end
  p = map.frame or {}
  for i = 1, #p, 5 do
    local x, y, w, d, h = p[i], p[i + 1], p[i + 2] / 2, p[i + 3] / 2, p[i + 4]
    for k = 1, 4 do
      local px, py = x + (k < 3 and -w or w), y + (k % 2 * 2 - 1) * d
      box(px - 0.1, py - 0.1, 0, px + 0.1, py + 0.1, h, 2)
    end
    for f = 1, 3 do
      local z = h * f / 3
      hpole(x, y - d, z, 0, 2 * w) hpole(x, y + d, z, 0, 2 * w)
      hpole(x - w, y, z, 1, 2 * d) hpole(x + w, y, z, 1, 2 * d)
    end
  end
  p = map.tube or {}
  for i = 1, #p, 6 do tube(p[i], p[i + 1], p[i + 2], p[i + 3], p[i + 4], p[i + 5]) end
  p = map.roof or {}
  for i = 1, #p, 5 do roof(p[i], p[i + 1], p[i + 2], p[i + 3], p[i + 4]) end
  -- the sky: the SKY setting (1 AUTO = the map's own, 2 DAY, 3 NIGHT, 4 OFF)
  local s = config.v.SKY or 1
  local sky = map.sky or (map.stars and "night") or "day"
  if s == 2 then sky = "day" elseif s == 3 then sky = "night" elseif s == 4 then sky = "off" end -- int
  local night, day = sky == "night", sky == "day"
  -- stars: fixed pseudo-random directions above the horizon (same sky every time)
  local seed = 7
  for k = 1, night and (map.stars or 40) or 0 do
    seed = (seed * 16807) % 2147483647
    local a = seed / 2147483647 * 2 * math.pi
    seed = (seed * 16807) % 2147483647
    local z = 0.08 + 0.9 * seed / 2147483647
    local c = sqrt(1 - z * z)
    W.ns, W.sx[k], W.sy[k], W.sz[k] = k, c * sin(a), c * cos(a), z
  end
  -- clouds and the sun: directions from azimuth and elevation
  W.nk, W.sun = 0, false
  if day then
    local c = map.clouds or CLOUDS
    for i = 1, #c, 3 do
      local a, e = c[i] * RAD, c[i + 1] * RAD
      local k = W.nk + 1
      W.nk, W.kx[k], W.ky[k], W.kz[k], W.ks[k] = k, cos(e) * sin(a), cos(e) * cos(a), sin(e), c[i + 2]
    end
    local u = map.sun or SUN
    local a, e = u[1] * RAD, u[2] * RAD
    W.sun, W.sunx, W.suny, W.sunz = true, cos(e) * sin(a), cos(e) * cos(a), sin(e)
  end
  W.sky = W.ns > 0 or W.nk > 0 or W.sun
  local g = map.gate or {}
  local hw, z1, z2 = M.GATE_W, M.GATE_Z1, M.GATE_Z2
  for i = 1, #g, 3 do
    local x, y, a = g[i], g[i + 1], g[i + 2]
    local n = W.ng + 1
    W.ng, W.gx[n], W.gy[n], W.ga[n] = n, x, y, a
    -- bars (invisible collision boxes): 2 posts, top, bottom; t = half thickness
    local t = 0.05
    local ax, ay = a == 0 and 1 or 0, a == 0 and 0 or 1 -- along the opening (int)
    local bx, by = ay, ax -- across
    for s = -1, 1, 2 do
      local cx, cy = x + ax * s * (hw + t), y + ay * s * (hw + t)
      box(cx - t - bx * t, cy - t - by * t, 0, cx + t + bx * t, cy + t + by * t, z2 + t, 0)
    end
    local ex, ey = ax * (hw + 2 * t) + bx * t, ay * (hw + 2 * t) + by * t
    box(x - ex, y - ey, z2, x + ex, y + ey, z2 + 2 * t, 0)
    box(x - ex, y - ey, z1 - 2 * t, x + ex, y + ey, z1, 0)
  end
  W.nv = W.nb
  for k = 1, nh, 6 do
    local n = W.nb + 1
    W.nb = n
    W.x1[n], W.y1[n], W.z1[n], W.x2[n], W.y2[n], W.z2[n], W.kind[n] = H[k], H[k + 1], H[k + 2], H[k + 3], H[k + 4], H[k + 5], 0
  end
  M.grid = map.grid or 10
  M.far = map.far
  local s = map.spawn or { 0, 0, 0 }
  M.sx, M.sy, M.sh = s[1], s[2], s[3]
end

