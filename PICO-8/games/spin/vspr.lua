-- draw transformed vector shape
function vspr(shape, ox, oy, sx, sy, r)
 for path in all(shape) do
  assert(#path >= 1)
  local mx_mirror_h = 1 - 2 * tonum(path.mirror_h)
  local my_mirror_v = 1 - 2 * tonum(path.mirror_v)
  for mx = mx_mirror_h, 1, 2 do
   for my = my_mirror_v, 1, 2 do
    function transform(x, y)
     -- scale
     x = x * mx * sx
     y = y * my * sy
     -- rotate
     x, y = x * cos(r) - y * sin(r), x * sin(r) + y * cos(r)
     -- transform
     x = x + ox
     y = y + oy
     return x, y
    end

    local x1, y1 = transform(unpack(path[1]))
    for i = 2, #path do
     local x2, y2 = transform(unpack(path[i]))
     line(x1, y1, x2, y2, path.color)
     x1 = x2
     y1 = y2
    end
   end
  end
 end
end
