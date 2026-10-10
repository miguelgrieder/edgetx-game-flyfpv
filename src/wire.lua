-- Flight group, only for maps with tunnels or stars: wire tunnels (see-through, like gates) and the stars.
-- Built by render with its projection helpers: use("wire")(tr, seg3, VX, VY, VZ, CX, CY, F, basis, R).
local use = ...
local flight = use("flight")
local floor = math.floor

return function(tr, seg3, VX, VY, VZ, CX, CY, F, basis, R)
  local S = {}

  -- wire tunnel i (see world.lua): a ring about every 8 m and the 4 corner rails. The first ring's corners
  -- are transformed, the others are steps along the tunnel (the transform is linear)
  function S.tube(i, pat)
    local W = flight.W
    local x, y, z, a, l = W.tx[i], W.ty[i], W.tz[i], W.ta[i], W.tl[i]
    local s = W.ts[i]
    local h, L = s / 2, l / 2
    -- one corner transformed; the others by adding the opening's sides and the length, each a camera
    -- axis scaled (u, v: the opening's two sides, d: along the tunnel)
    local rx, ry, rz, ux, uy, uz, fx, fy, fz = basis()
    local cx, cy, cz, ax, ay, az, bx, by, bz, dx, dy, dz
    if a == 2 then -- int
      cx, cy, cz = tr(x - h, y - h, z)
      ax, ay, az, bx, by, bz, dx, dy, dz = s * rx, s * ux, s * fx, s * ry, s * uy, s * fy, l * rz, l * uz, l * fz
    elseif a == 0 then -- int
      cx, cy, cz = tr(x - h, y - L, z)
      ax, ay, az, bx, by, bz, dx, dy, dz = s * rx, s * ux, s * fx, s * rz, s * uz, s * fz, l * ry, l * uy, l * fy
    else
      cx, cy, cz = tr(x - L, y - h, z)
      ax, ay, az, bx, by, bz, dx, dy, dz = s * ry, s * uy, s * fy, s * rz, s * uz, s * fz, l * rx, l * ux, l * fx
    end
    VX[1], VY[1], VZ[1] = cx, cy, cz
    VX[2], VY[2], VZ[2] = cx + ax, cy + ay, cz + az
    VX[3], VY[3], VZ[3] = cx + ax + bx, cy + ay + by, cz + az + bz
    VX[4], VY[4], VZ[4] = cx + bx, cy + by, cz + bz
    VX[5], VY[5], VZ[5] = cx + dx, cy + dy, cz + dz
    local n = floor(l / 8 + 0.5)
    if n < 1 then n = 1 end
    local dx, dy, dz = (VX[5] - VX[1]) / n, (VY[5] - VY[1]) / n, (VZ[5] - VZ[1]) / n
    if not (l > 0) then n = 0 end
    for k = 0, n do
      local ox, oy, oz = k * dx, k * dy, k * dz
      for e = 1, 4 do
        local f = e % 4 + 1
        seg3(VX[e] + ox, VY[e] + oy, VZ[e] + oz, VX[f] + ox, VY[f] + oy, VZ[f] + oz, pat)
      end
    end
    if n > 0 then
      local ox, oy, oz = n * dx, n * dy, n * dz
      for e = 1, 4 do seg3(VX[e], VY[e], VZ[e], VX[e] + ox, VY[e] + oy, VZ[e] + oz, pat) end
    end
  end

  -- stars (maps with a sky): fixed directions, so they turn with the camera but never get closer
  -- returns the topmost row drawn on (64: none)
  function S.stars()
    local W = flight.W
    local top = 64
    local rx, ry, rz, ux, uy, uz, fx, fy, fz = basis()
    local SX, SY, SZ = W.sx, W.sy, W.sz
    for k = 1, W.ns do
      local dx, dy, dz = SX[k], SY[k], SZ[k]
      local d = dx * fx + dy * fy + dz * fz
      if d > 0.1 then
        local x = CX + F * (dx * rx + dy * ry + dz * rz) / d + 0.5
        local y = CY - F * (dx * ux + dy * uy + dz * uz) / d + 0.5
        if x >= 0 and x < 128 and y >= 0 and y < 64 then
          x, y = x - x % 1, y - y % 1
          lcd.drawPoint(x, y, FORCE)
          if y < top then top = y end
        end
      end
    end
    return top
  end

  return S
end
