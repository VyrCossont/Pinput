pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- spin vector demo
-- @vyr@demon.social

theta = 0
dart = nil
darts = {}
fire_counter = 0
fire_cooldown = 4

-- sticks
pi_l = 0
pi_r = 2

-- read normalized stick
-- /!\ pico-8 is upside down
function pi_stick(s, pl)
 pl = pl or 0
 local x = pi_axis(s, pl) >> 15
 local y = pi_axis(s + 1, pl) >> 15
 return x, ~y
end

function _init()
 pi_init()
end

function _update60()
 local x, y = pi_stick(pi_l)
 if x != 0 and y != 0 then
  theta = atan2(x, y)
 end

 if fire_counter == 0 then
  x, y = pi_stick(pi_r)
  if abs(x) > 0.5
  or abs(y) > 0.5 then
   add(darts, {
    p = {x = 0, y = 0},
    v = {x = x * 3, y = y * 3}
   })
   fire_counter = fire_cooldown
  end
 else
  fire_counter -= 1
 end

 for i, dart in pairs(darts) do
  if abs(dart.p.x) > 64
  or abs(dart.p.y) > 64 then
   deli(darts, i)
  else
   dart.p.x += dart.v.x
   dart.p.y += dart.v.y
  end
 end
end

function _draw()
 cls()
 camera(-64, -64)

 if not pi_is_inited() then
  ?"waiting for pinput connection..."
  return
 end

 for dart in all(darts) do
  local dart_theta = atan2(dart.v.x, dart.v.y)
  vspr(shape_dart, dart.p.x, dart.p.y, 2, 2, dart_theta)
 end
 
 vspr(shape_claw, 0, 0, 3, 3, theta)
end

-->8
-- new format data

-- draw transformed vector shape
-- todo: is it faster if we use raw memory instead of tables?
function vspr(shape, ox, oy, sx, sy, r)
 for path in all(shape) do
  assert(#path >= 1)
  local mx_mirror_h = 1 - 2 * tonum(path.mirror_h)
  local my_mirror_v = 1 - 2 * tonum(path.mirror_v)
  for mx = mx_mirror_h, 1, 2 do
   for my = my_mirror_v, 1, 2 do
    function transform(x, y)
     -- scale
     x *= mx * sx
     y *= my * sy
     -- rotate
     x, y = x * cos(r) - y * sin(r), x * sin(r) + y * cos(r)
     -- transform
     x += ox
     y += oy
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

shape_claw = {
 {
  color = 10,
  mirror_h = false,
  mirror_v = true,
  { -1, 0 },
  { 1, 3 },
  { 3, 2 },
  { 0, 4 },
  { -3, 0 },
 },
}

shape_dart = {
 {
  color = 7,
  mirror_h = false,
  mirror_v = true,
  { 0, 0 },
  { -1, -1 },
  { 2, 0 },
 },
}

shape_splitter = {
 {
  color = 14,
  mirror_h = true,
  mirror_v = true,
  { 0, 6 },
  { 6, 6 },
  { 6, 0 },
 },
 {
  color = 14,
  mirror_h = true,
  mirror_v = true,
  { 6, 6 },
  { 0, 0 },
 },
}

shape_pinwheel = {
 {
  color = 13,
  mirror_h = false,
  mirror_v = false,
  { 0, 0 },
  { 0, -6 },
  { -6, -6 },
  { 0, 0 },
  { 0, 0 },
  { 0, 0 },
  { -6, 0 },
  { -6, 6 },
  { 0, 0 },
  { 0, 6 },
  { 6, 6 },
  { 0, 0 },
  { 6, 0 },
  { 6, -6 },
  { 0, 0 },
 },
}

shape_leprechaun = {
 {
  color = 11,
  mirror_h = true,
  mirror_v = true,
  { 0, 6 },
  { 6, 6 },
  { 6, 0 },
  { 0, 6 },
 },
}

shape_diamond = {
 {
  color = 12,
  mirror_h = true,
  mirror_v = true,
  { -8, 0 },
  { 0, -8 },
 },
}

-->8
#include pinput.lua

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
