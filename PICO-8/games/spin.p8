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

function hflip(m)
 local r = {}
 for l in all(m) do
  add(r, vline(
   vec2(-l.a.x, l.a.y),
   vec2(-l.b.x, l.b.y)
  ))
 end
 return r
end

function vflip(m)
 local r = {}
 for l in all(m) do
  add(r, vline(
   vec2(l.a.x, -l.a.y),
   vec2(l.b.x, -l.b.y)
  ))
 end
 return r
end

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
 -- geometry
 local arrow = {
	 vline(
	  vec2(-1, 0),
	  vec2(1, 0)
	 ),
	 vline(
	  vec2(0, -1),
	  vec2(1, 0)
	 ),
	 vline(
	  vec2(0, 1),
	  vec2(1, 0)
	 )
	}
	
	claw = {
	 vline(
	  vec2(-1, 0),
	  vec2(1, 3)
	 ),
	 vline(
	  vec2(1, 3),
	  vec2(3, 2)
	 ),
	 vline(
	  vec2(3, 2),
	  vec2(0, 4)
	 ),
	 vline(
	  vec2(0, 4),
	  vec2(-3, 0)
	 )
	}
	for l in all(vflip(claw)) do
	 add(claw, l)
	end
	
	dart = {
	 vline(
	  vec2(0, 0),
	  vec2(-1, -1)
	 ),
	 vline(
	  vec2(-1, -1),
	  vec2(2, 0)
	 )
	}
	for l in all(vflip(dart)) do
	 add(dart, l)
	end
	
	model = claw
	
	-- setup
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
   local dart_p = vec2(0, 0)
   local dart_v = vec2(x, y) * 3
   add(darts, {dart_p, dart_v})
   fire_counter = fire_cooldown
  end
 else
  fire_counter -= 1
 end
 
 for i, d in pairs(darts) do
  local dart_p, dart_v = unpack(d)
  if abs(dart_p.x) > 64
  or abs(dart_p.y) > 64 then
   deli(darts, i)
  else
   d[1] += dart_v
  end
 end
end

function _draw()
 cls(c_black)
 
 if not pi_is_inited() then
  ?"waiting for pinput connection..."
  return
 end
 
 ?#darts
 
 for d in all(darts) do
  local dart_p, dart_v = unpack(d)
  local dart_theta = atan2(
   dart_v.x,
   dart_v.y
  )
  for vl in all(dart) do
   local vl_t = vl:rot(dart_theta)
    * 2 + vec2(64, 64)
    + dart_p
   vl_t:draw(c_white)
  end
 end
 
 for vl in all(claw) do
  local vl_t = vl:rot(theta)
   * 2 + vec2(64, 64)
  vl_t:draw(c_yellow)
 end
end

-->8
-- vector library

-- 2d vector

vec2_mt = {}
vec2_mt.__index = vec2_mt

function vec2(x, y)
 local self = {x = x, y = y}
 setmetatable(self, vec2_mt)
 return self
end

function vec2_mt.__tostring(self)
 return 'vec2(' .. self.x
  .. ', ' .. self.y .. ')'
end

function vec2_mt.__add(self, v)
 return vec2(
  self.x + v.x,
  self.y + v.y)
end

function vec2_mt.__sub(self, v)
 return vec2(
  self.x - v.x,
  self.y - v.y)
end

function vec2_mt.__mul(self, s)
 return vec2(
  self.x * s,
  self.y * s)
end

function vec2_mt.__div(self, s)
 return vec2(
  self.x / s,
  self.y / s)
end

function vec2_mt.dot(self, v)
 return self.x * v.x
  + self.y * v.y
end

function vec2_mt.mag(self)
 return sqrt(self:dot(self))
end

function vec2_mt.norm(self)
 local m = self:mag()
 if m == 0 then
  return self
 else
  return self / m
 end
end

function vec2_mt.rot(self, t)
 return vec2(
  self.x * cos(t)
  - self.y * sin(t),
  self.x * sin(t)
  + self.y * cos(t))
end

-- line

vline_mt = {}
vline_mt.__index = vline_mt

-- line from a to b
function vline(a, b)
 local self = {a = a, b = b}
 setmetatable(self, vline_mt)
 return self
end

function vline_mt.__tostring(self)
 return 'vline('
  .. tostr(self.a) .. ', '
  .. tostr(self.b) .. ')'
end

function vline_mt.draw(self, col)
 line(
  self.a.x,
  self.a.y,
  self.b.x,
  self.b.y,
  col)
end

function vline_mt.__add(self, v)
 return vline(
  self.a + v,
  self.b + v)
end

function vline_mt.__sub(self, v)
 return vline(
  self.a - v,
  self.b - v)
end

function vline_mt.__mul(self, s)
 return vline(
  self.a * s,
  self.b * s)
end

function vline_mt.__div(self, s)
 return vline(
  self.a / s,
  self.b / s)
end

function vline_mt.rot(self, t)
 return vline(
  self.a:rot(t),
  self.b:rot(t))
end

-->8
-- colors

c_black = 0
c_dark_blue = 1
c_dark_purple = 2
c_dark_green = 3
c_brown = 4
c_dark_gray = 5
c_light_gray = 6
c_white = 7
c_red = 8
c_orange = 9
c_yellow = 10
c_green = 11
c_blue = 12
c_indigo = 13
c_pink = 14
c_peach = 15

-->8
#include pinput.lua

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
