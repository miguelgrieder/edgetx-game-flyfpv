-- throttle up while arming: the quad waits for throttle low
return { frames = 35, fn = function(f)
  if f == 20 then return 0, 0, 0, 0, "enter" end
  return 0, 0, 0, 0
end }
