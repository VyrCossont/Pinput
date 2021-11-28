pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- spin shape editor
-- @vyr@demon.social

-- globals

-- item zero is the color,
-- items 1-n are pairs of coords
paths = {}
cpath = nil

function error_beep()
 print "\ae-e-..dd"
end

function _init()
 grid_init()
end

-->8
-- grid

function grid_init()
 pos = {0, 0}
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

 -- current path
 local c = 7
 local path = {}
 if cpath != nil then
  path = paths[cpath]
  c = path.color
 end

 -- todo: draw every path

 if #path > 0 then
  -- lines
  if #path > 1 then
   for i = 2, #path do
    local px1, py1 = unpack(path[i - 1])
    local px2, py2 = unpack(path[i])
    line(px1 * grid_size, py1 * grid_size, px2 * grid_size, py2 * grid_size, c)
   end
  end
  -- dots
  for p in all(path) do
   local px, py = unpack(p)
   circfill(px * grid_size, py * grid_size, 2, c)
  end
 end

 local cx, cy = unpack(pos)
 if #path > 0 then
  -- dotted line between last dot and cursor
  local px, py = unpack(path[#path])
  -- pick a pattern that won't make the line invisible
  local theta = 8 * atan2(cx - px, cy - py)
  if (theta < 1) or (theta > 3 and theta < 5) or (theta > 7) then
   -- vertical stripes
   fillp(0b1010101010101010)
  else
   -- horizontal stripes
   fillp(0b1111000011110000)
  end
  line(px * grid_size, py * grid_size, cx * grid_size, cy * grid_size, c)
  fillp()
 end

 -- cursor
 circ(cx * grid_size, cy * grid_size, 2, c)
end

function grid_update60()
 local cx, cy = unpack(pos)
 if (btnp(0)) cx -= 1
 if (btnp(1)) cx += 1
 if (btnp(2)) cy -= 1
 if (btnp(3)) cy += 1
 cx = mid(-grid_max, cx, grid_max)
 cy = mid(-grid_max, cy, grid_max)
 pos = {cx, cy}

 if btnp(4) then
  if cpath == nil then
   palette_init()
  else
   add(paths[cpath], pos)
  end
 end

 if btnp(5) then
--  if cpath == nil then
--   error_beep()
--  else
   menu_init()
--  end
 end
end

-->8
-- menu

function menu_init()
 _draw = function()
  grid_draw()
  menu_draw()
 end
 _update60 = menu_update60

 menu_selected = nil
end

function menu_draw()
 camera(-64, -64)

 circfill(0, 0, 32 + 2, 0)
 circfill(0, 0, 32, 6)

 for x = -32, 32 do
  for y = -32, 32 do
   local theta = atan2(x, y)
   if theta > 1/3 and theta < 2/3 and sqrt(x * x + y * y) < 32 + 1 and pget(x, y) == 6 then
    pset(x, y, 13)
   end
  end
 end

 line(0, 0, 32 * cos(0/3), 32 * sin(0/3), 5)
 line(0, 0, 32 * cos(1/3), 32 * sin(1/3), 5)
 line(0, 0, 32 * cos(2/3), 32 * sin(2/3), 5)
end

function menu_update60()


 if btnp(4) then
  error_beep()
 end

 if btnp(5) then
  menu_exit()
 end
end

function menu_exit()
 local saved_pos = pos
 grid_init()
 pos = saved_pos
end

-->8
-- palette

function palette_init()
 _draw = function()
  grid_draw()
  palette_draw()
 end
 _update60 = palette_update60

 palette_coords = {0, 0}
 palette_selected = nil
 h_flip = false
 v_flip = false
 close_loop = false
end

function palette_draw()
 camera(-34, -14)
 fillp()
 clip(34, 14, 60, 80)

 -- palette background
 fillp(0b0110110010010011)
 rectfill(0, 0, 60 - 1, 60 - 1, 5 | (13 << 4))
 fillp()

 -- control area
 rectfill(0, 60, 60 - 1, 80 - 1, 13)

 -- palette frame
 rect(0, 0, 60 - 1, 80 - 1, 6)

 -- color swatches
 for i = 0, 3 do
  for j = 0, 3 do
   local c = (i * 4) + j
   local x = 1 + 2 * (i + 1) + 12 * i
   local y = 1 + 2 * (j + 1) + 12 * j
   rectfill(x, y, x + 12 - 1, y + 12 - 1, c)
  end
 end

 -- currently selected color swatch
 local px, py = unpack(palette_coords)
 local x = 2 * (px + 1) + 12 * px
 local y = 2 * (py + 1) + 12 * py
 if (py > 3) y += 5
 fillp(0b1010010110100101)
 rect(x, y, x + 12 + 1, y + 12 + 1, 3 | (11 << 4))
 fillp()

 -- chosen color swatch
 if palette_selected != nil then
  local sx, sy = unpack(palette_selected)
  local x = 2 * (sx + 1) + 12 * sx
  local y = 2 * (sy + 1) + 12 * sy
  fillp(0b1100110000110011)
  rect(x, y, x + 12 + 1, y + 12 + 1, 3 | (11 << 4))
  fillp()
 end

 for k, label in pairs({"h", "v", "c", "ok"}) do
  local px = k - 1
  local x = 1 + 2 * (px + 1) + 12 * px
  local y = 60 + 4
  rectfill(x, y, x + 12 - 1, y + 12 - 1, 6)
  if px == 3 then
   print(label, x + 2, y + 3, 13)
  else
   print("\^w\^t" .. label, x + 3, y + 1, 13)
   if (px == 0 and h_flip)
   or (px == 1 and v_flip)
   or (px == 2 and close_loop) then
    fillp(0b1100110000110011)
    rect(x - 1, y - 1, x + 12, y + 12, 3 | (11 << 4))
    fillp()
   end
  end
 end
end

function palette_update60()
 local px, py = unpack(palette_coords)
 if (btnp(0)) px -= 1
 if (btnp(1)) px += 1
 if (btnp(2)) py -= 1
 if (btnp(3)) py += 1
 px %= 4
 -- line 4 is flip controls and ok button
 py %= 5
 palette_coords = {px, py}

 if btnp(4) then
  if py < 4 then
   palette_selected = {unpack(palette_coords)}
  else
   if px == 0 then
    h_flip = not h_flip
   elseif px == 1 then
    v_flip = not v_flip
   elseif px == 2 then
    close_loop = not close_loop
   elseif px == 3 then
    if palette_selected == nil then
     error_beep()
    else
     palette_exit()
    end
   end
  end
 end

 if btnp(5) then
  grid_init()
 end
end

-- start a new line and exit palette mode
function palette_exit()
 local px, py = unpack(palette_selected)
 cpath = #paths
 paths[cpath] = {
   ["color"] = (px * 4) + py,
   ["h_flip"] = h_flip,
   ["v_flip"] = v_flip,
   ["close_loop"] = close_loop,
 }
 grid_init()
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
