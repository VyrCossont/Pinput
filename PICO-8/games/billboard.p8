pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
function _init()
 -- enable sprite 0
 poke(0x5f36, 0b1000)

 -- set each map cell in the
 -- upper left corner to sprites
 -- 0-255 in same order and
 -- shape as their sprite sheet
 -- numbers. this makes tline,
 -- which uses the map,
 -- equivalent to sspr,
 -- which uses the sprite sheet.
 for x = 0, 15 do
  for y = 0, 15 do
   local s = x + y * 16
   mset(x, y, s)
  end
 end
end

function _draw()
 cls()
 local n = 4
 for j = 0, n - 1 do
  for i = 0, n - 1 do
   local r = (i + n * j) / n ^ 2
	  vspr(
	   shape_diamond,
	   i * (128 / n) + (64 / n),
	   j * (128 / n) + (64 / n),
	   3 + cos(r),
	   3 + sin(r),
	   0
	  )
	 end
	end
end

-->8
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
    local x2, y2 = transform(unpack(path[2]))
    
    local sx = flr(min(x1, x2))
    local sy = flr(min(y1, y2))
    local sw = ceil(max(x1, x2)) - sx
    local sh = ceil(max(y1, y2)) - sy
    
    -- rectfill(
    -- sx, sy,
    -- sx + sw, sy + sh,
    --  2
    -- )
    
    line(x1, y1, x2, y2, path.color)
    
    -- use video memory as sprite sheet
    poke(0x5f54, 0x60)
    
    
    -- copy nw to ne
    sspr(
     -- src
     sx, sy,
     sw, sh,
     -- dst
     sx + sw - 1, sy,
     sw, sh,
     -- flips
     true,
     false
    )
    
    -- copy n to s
    sspr(
     -- src
     sx, sy,
     2 * sw - 1, sh,
     -- dst
     sx, sy + sh - 1,
     2 * sw - 1, sh,
     -- flips
     false,
     true
    )
    
    -- use sprite sheet as sprite sheet
    poke(0x5f54, 0x00)
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

shape_bullet = {
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
  mirror_h = false,
  mirror_v = false,
  {-1, -1},
  {1, -1},
  {1, 1},
  {-1, 1},
  {-1, -1},
 },
 {
  color = 14,
  mirror_h = false,
  mirror_v = false,
  {-1, -1},
  {1, 1},
 },
 {
  color = 14,
  mirror_h = false,
  mirror_v = false,
  {1, -1},
  {-1, 1},
 },
}

shape_pinwheel = {
 {
  color = 13,
  mirror_h = false,
  mirror_v = false,
  {0, 0},
  {0, -1},
  {-1, -1},
  {0, 0},
  {-1, 0},
  {-1, 1},
  {0, 0},
  {0, 1},
  {1, 1},
  {0, 0},
  {1, 0},
  {1, -1},
  {0, 0},
 },
}

shape_leprechaun = {
 {
  color = 11,
  mirror_h = false,
  mirror_v = false,
  {-1, -1},
  {-1, 1},
  {1, 1},
  {1, -1},
  {-1, -1},
 },
 {
  color = 11,
  mirror_h = false,
  mirror_v = false,
  {-1, 0},
  {0, -1},
  {1, 0},
  {0, 1},
  {-1, 0},
 },
}

shape_diamond = {
 {
  color = 12,
  mirror_h = false,
  mirror_v = false,
  {-1, 0},
  {0, -1},
  {1, 0},
  {0, 1},
  {-1, 0},
 },
}

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
