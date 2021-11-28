pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- spin shape editor
-- @vyr@demon.social

-- globals

-- item zero is the color,
-- items 1-n are pairs of coords
lines = {}
cline = nil

function _init()
 grid_init()
end

function grid_init()
 cx = 0
 cy = 0
 grid_size = 7
 grid_max = 64 \ grid_size

 _draw = grid_draw
 _update60 = grid_update60
end

function grid_draw()
 camera()
 cls(0)
 camera(-64, -64)

 -- grid dots
 for i = 0, 64, grid_size do
  for j = 0, 64, grid_size do
   for s = -1, 1, 2 do
    for t = -1, 1, 2 do
     pset(i * s, j * t, 6)
    end
   end
  end
 end

 -- selected dot
 circ(cx * grid_size, cy * grid_size, 2, 7)
end

function grid_update60()
 if (btnp(0)) cx -= 1
 if (btnp(1)) cx += 1
 if (btnp(2)) cy -= 1
 if (btnp(3)) cy += 1
 cx = mid(-grid_max, cx, grid_max)
 cy = mid(-grid_max, cy, grid_max)
 if (btnp(4)) palette_init()
end

function palette_init()
 _draw = function()
  grid_draw()
  palette_draw()
 end
 _update60 = palette_update60
 px = 0
 py = 0
end

function palette_draw()
 camera()
 clip(34, 34, 60, 60)
 fillp(0b0110110010010011)
 rectfill(34, 34, 94 - 1, 94 - 1, 5 | (13 << 4))
 fillp()
 rect(34, 34, 94 - 1, 94 - 1, 6)
 for i = 0, 3 do
  for j = 0, 3 do
   local c = (i * 4) + j
   local x = 34 + 1 + 2 * (i + 1) + 12 * i
   local y = 34 + 1 + 2 * (j + 1) + 12 * j
   rectfill(x, y, x + 12 - 1, y + 12 - 1, c)
  end
 end
 fillp(0b1010010110100101)
 x = 34 + 2 * (px + 1) + 12 * px
 y = 34 + 2 * (py + 1) + 12 * py
 rect(x, y, x + 12 + 1, y + 12 + 1, 3 | (11 << 4))
 fillp()
end

function palette_update60()
 if (btnp(0)) px -= 1
 if (btnp(1)) px += 1
 if (btnp(2)) py -= 1
 if (btnp(3)) py += 1
 px = mid(0, px, 3)
 py = mid(0, py, 3)
 if (btnp(4)) palette_exit()
end

-- start a new line and exit palette mode
function palette_exit()
 cline = #lines
 lines[cline] = {[0]=(px * 4) + py}
 grid_init()
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
