-- math functions

function ceil_log2(x)
 local n = 0
 while x > 1 do
  x = x >> 1
  n = n + 1
 end
 return n
end

-- overflow-safe L2 distance
-- from FReDs72
function l2_dist(dx, dy)
 dx = abs(dx)
 dy = abs(dy)
 local d = max(dx, dy)
 local n = min(dx, dy) / d
 return d * sqrt(n ^ 2 + 1)
end
