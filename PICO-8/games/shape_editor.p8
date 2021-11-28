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

 -- selected dot
 local cx, cy = unpack(pos)
 local c = 7
 if cline != nil then
  c = lines[cline].color
 end
 circ(cx * grid_size, cy * grid_size, 2, c)
 print(c, cx * grid_size, cy * grid_size, 8)
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
  if cline == nil then
   palette_init()
  else
   add(lines[cline], pos)
  end
 end
end

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
 camera()
 fillp()
 clip(34, 14, 60, 80)

 -- palette background
 fillp(0b0110110010010011)
 rectfill(34, 14, 94 - 1, 74 - 1, 5 | (13 << 4))
 fillp()

 -- control area
 rectfill(34, 74, 94 - 1, 94 - 1, 13)

 -- palette frame
 rect(34, 14, 94 - 1, 94 - 1, 6)

 -- color swatches
 for i = 0, 3 do
  for j = 0, 3 do
   local c = (i * 4) + j
   local x = 34 + 1 + 2 * (i + 1) + 12 * i
   local y = 14 + 1 + 2 * (j + 1) + 12 * j
   rectfill(x, y, x + 12 - 1, y + 12 - 1, c)
  end
 end

 -- currently selected color swatch
 local px, py = unpack(palette_coords)
 local x = 34 + 2 * (px + 1) + 12 * px
 local y = 14 + 2 * (py + 1) + 12 * py
 if (py > 3) y += 5
 fillp(0b1010010110100101)
 rect(x, y, x + 12 + 1, y + 12 + 1, 3 | (11 << 4))
 fillp()

 -- chosen color swatch
 if palette_selected != nil then
  local sx, sy = unpack(palette_selected)
  local x = 34 + 2 * (sx + 1) + 12 * sx
  local y = 14 + 2 * (sy + 1) + 12 * sy
  fillp(0b1100110000110011)
  rect(x, y, x + 12 + 1, y + 12 + 1, 3 | (11 << 4))
  fillp()
 end

 for k, label in pairs({"h", "v", "c", "ok"}) do
  local px = k - 1
  local x = 34 + 1 + 2 * (px + 1) + 12 * px
  local y = 74 + 4
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
 px = mid(0, px, 3)
 -- counts flip controls and commit button
 py = mid(0, py, 4)
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
     print "\ae-e-..dd"
    else
     palette_exit()
    end
   end
  end
 end
end

-- start a new line and exit palette mode
function palette_exit()
 local px, py = unpack(palette_selected)
 cline = #lines
 lines[cline] = {
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
