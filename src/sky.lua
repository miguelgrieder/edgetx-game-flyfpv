-- Flight group, only when the sky has something in it: stars (night), clouds and a sun (day). All are
-- directions, infinitely far: they turn with the camera but never get closer. Drawn first, so anything in
-- front of them hides them. Built by render: use("sky")(seg2, drawLine, basis).
local use = ...
local flight = use("flight")
local sqrt = math.sqrt
local FORCE, SOLID, DOTTED = FORCE, SOLID, DOTTED
local fillRect, point = lcd.drawFilledRectangle, lcd.drawPoint

-- a cloud at scale 1: a bumpy top and a flat bottom, in pixels around its centre (x right, y up)
local CLOUD = { -11, 0, -8, 4, -3, 7, 2, 5, 7, 7, 11, 0, -11, 0 }
local NC = #CLOUD

return function(seg2, drawLine, basis)
  local S = {}

  -- returns the lcd calls made here that seg2 did not count, and the topmost row drawn on (64: none)
  function S.draw()
    local W = flight.W
    local rx, ry, rz, ux, uy, uz, fx, fy, fz = basis()
    local top, calls = 64, 0
    -- stars: one pixel each
    local SX, SY, SZ = W.sx, W.sy, W.sz
    for k = 1, W.ns do
      local dx, dy, dz = SX[k], SY[k], SZ[k]
      local d = dx * fx + dy * fy + dz * fz
      if d > 0.1 then
        local x = 64 + 40 * (dx * rx + dy * ry + dz * rz) / d + 0.5
        local y = 32 - 40 * (dx * ux + dy * uy + dz * uz) / d + 0.5
        if x >= 0 and x < 128 and y >= 0 and y < 64 then
          x, y = x - x % 1, y - y % 1
          point(x, y, FORCE)
          calls = calls + 1
          if y < top then top = y end
        end
      end
    end
    -- clouds: dotted outlines a fixed size on the screen, turned with the roll (the screen directions of
    -- the world's horizontal and up: the world's up seen from the camera is (rz, uz))
    local n = sqrt(rz * rz + uz * uz)
    if W.nk > 0 and n > 0.2 then
      local hx, hy, vx, vy = uz / n, rz / n, rz / n, -uz / n
      local KX, KY, KZ, KS = W.kx, W.ky, W.kz, W.ks
      for k = 1, W.nk do
        local dx, dy, dz = KX[k], KY[k], KZ[k]
        local d = dx * fx + dy * fy + dz * fz
        if d > 0.2 then
          local cx = 64 + 40 * (dx * rx + dy * ry + dz * rz) / d
          local cy = 32 - 40 * (dx * ux + dy * uy + dz * uz) / d
          if cx > -30 and cx < 158 and cy > -20 and cy < 84 then
            local s = KS[k]
            local ax, ay
            for i = 1, NC, 2 do
              local ox, oy = CLOUD[i] * s, CLOUD[i + 1] * s
              local x, y = cx + ox * hx + oy * vx, cy + ox * hy + oy * vy
              if ax then seg2(ax, ay, x, y, DOTTED) end
              ax, ay = x, y
            end
          end
        end
      end
    end
    -- the sun: a small filled disk and 4 short rays, only when it is all on the screen
    if W.sun then
      local dx, dy, dz = W.sunx, W.suny, W.sunz
      local d = dx * fx + dy * fy + dz * fz
      if d > 0.2 then
        local x = 64 + 40 * (dx * rx + dy * ry + dz * rz) / d + 0.5
        local y = 32 - 40 * (dx * ux + dy * uy + dz * uz) / d + 0.5
        if x >= 8 and x <= 119 and y >= 8 and y <= 55 then
          x, y = x - x % 1, y - y % 1
          fillRect(x - 2, y - 1, 5, 3, FORCE)
          fillRect(x - 1, y - 2, 3, 5, FORCE)
          drawLine(x - 6, y, x - 4, y, SOLID, FORCE)
          drawLine(x + 4, y, x + 6, y, SOLID, FORCE)
          drawLine(x, y - 6, x, y - 4, SOLID, FORCE)
          drawLine(x, y + 4, x, y + 6, SOLID, FORCE)
          calls = calls + 6
          if y - 6 < top then top = y - 6 end
        end
      end
    end
    return calls, top
  end

  return S
end
