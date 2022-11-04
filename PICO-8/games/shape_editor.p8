pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- spin shape editor
-- @vyr@demon.social

-- globals

-- named items are color and modes,
-- items 1-n are pairs of coords
paths = {}
cpath = nil

-- cursor position
pos = {0, 0}

function error_beep()
 print "\ae-e-..dd"
end

-- serialize as Lua code
function serialize_paths_lua()
 local s = ""
 for path in all(paths) do
  s ..= " {\n"
  s ..= "  color = " .. tostr(path.color) .. ",\n"
  s ..= "  mirror_h = " .. tostr(path.mirror_h) .. ",\n"
  s ..= "  mirror_v = " .. tostr(path.mirror_v) .. ",\n"
  for point in all(path) do
   local x, y = unpack(point)
   s ..= "  {" .. tostr(x) .. ", " .. tostr(y) .. "},\n"
  end
  s ..= " },\n"
 end
 return s
end

-- serialize packed binary format
-- # of paths
-- path:
--  # of points in path
--  meta byte
--   bit 7: mirror_h
--   bit 6: mirror_v
--   bit 5: reserved
--   bits 4-0: color
--  points:
--   signed byte for x
--   signed byte for y
function serialize_paths_bin()
 local s = ""
 s ..= chr(#paths)
 for path in all(paths) do
  s ..= chr(#path)
  local meta = path.color
  if path.mirror_h then
   meta |= 1 << 7
  end
  if path.mirror_v then
   meta |= 1 << 6
  end
  s ..= chr(meta)
  for point in all(path) do
   local x, y = unpack(point)
   s ..= chr(x)
   s ..= chr(y)
  end
 end
 return s
end

-- serialize packed binary format as space-separated hex bytes
function serialize_paths_hex()
 local s = ""
 local bytes = serialize_paths_bin()
 for i = 1, #bytes do
  s ..= " " .. sub(tostr(ord(sub(bytes, i, i + 1)), 1), 5, 6)
 end
 return sub(s, 2)
end

function export_paths_lua()
 printh(serialize_paths_lua(), "@clip")
end

function export_paths_hex()
 printh(serialize_paths_hex(), "@clip")
end

function save_paths_to_cartdata()
 local bytes = serialize_paths_bin()
 if #bytes <= 256 then
  ?"\^!5e00" .. bytes
 else
  error_beep()
 end
end

function load_paths_from_cartdata()
 paths = {}
 cpath = nil

 local ptr = 0x5e00
 function next()
  assert(ptr < 0x5f00, "read past end of cartdata!")
  local byte = @ptr
  ptr += 1
  return byte
 end

 local num_paths = next()
 for _ = 1, num_paths do
  local path = {}
  local num_points = next()

  local meta = next()
  path.color = meta & 0b11111
  path.mirror_h = 1 == (meta >> 7) & 1
  path.mirror_v = 1 == (meta >> 6) & 1

  for _ = 1, num_points do
   local x = next()
   local y = next()
   add(path, {x, y})
  end

  add(paths, path)
 end
end

function _init()
 cartdata("vyrcossont_shape_editor")
 grid_init()
end

-->8
-- grid

function grid_init()
 grid_size = 7
 grid_max = 64 \ grid_size

 _draw = grid_draw
 _update60 = grid_update60
end

function path_transforms(path)
 local transforms = {{1, 1}}
 if path.mirror_h then
  add(transforms, {-1, 1})
 end
 if path.mirror_v then
  add(transforms, {1, -1})
 end
 if path.mirror_h and path.mirror_v then
  add(transforms, {-1, -1})
 end
 return transforms
end

function grid_draw()
 camera()
 cls(0)
 camera(-64, -64)

 -- mirror lines
 line(-64, 0, 64, 0, 1)
 line(0, -64, 0, 64, 1)

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

 -- lines
 for path in all(paths) do
  if #path > 1 then
   for i = 2, #path do
    local px1, py1 = unpack(path[i - 1])
    local px2, py2 = unpack(path[i])
    for transform in all(path_transforms(path)) do
     local tx, ty = unpack(transform)
     line(
      px1 * grid_size * tx,
      py1 * grid_size * ty,
      px2 * grid_size * tx,
      py2 * grid_size * ty,
      path.color
     )
    end
   end
  end
 end

 -- current path and cursor
 local c = 7
 local path = {}
 if cpath != nil then
  path = paths[cpath]
  c = path.color
 end
 local cx, cy = unpack(pos)

 -- dotted line between end of path and cursor
 if #path > 0 then
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
  for transform in all(path_transforms(path)) do
   local tx, ty = unpack(transform)
   line(
    px * grid_size * tx,
    py * grid_size * ty,
    cx * grid_size * tx,
    cy * grid_size * ty,
    c
   )
  end
  fillp()
 end

 -- dots on original (non-mirrored) path only
 for p in all(path) do
  local px, py = unpack(p)
  circfill(px * grid_size, py * grid_size, 2, c)
 end

 -- cursor
 circ(cx * grid_size, cy * grid_size, 2, c)
end

function grid_update60()
 local cx, cy = unpack(pos)
 if btnp(0) then cx -= 1 end
 if btnp(1) then cx += 1 end
 if btnp(2) then cy -= 1 end
 if btnp(3) then cy += 1 end
 cx = mid(-grid_max, cx, grid_max)
 cy = mid(-grid_max, cy, grid_max)
 pos = {cx, cy}

 if btnp(4) then
  if cpath == nil then
   error_beep()
  else
   add(paths[cpath], pos)
  end
 end

 if btnp(5) then
   local menu_items = {}
  if cpath == nil then
   menu_items =
   {
    {
     sprite=5,
     label="path",
     fn=
      function()
       menu_exit()
       palette_init()
      end,
    },
    {
     sprite=2,
     label="cancel",
     fn=menu_exit,
    },
    {
     sprite=7,
     label="lUA",
     fn=
      function()
       export_paths_lua()
       menu_exit()
      end,
    },
    {
     sprite=7,
     label="hex",
     fn=
      function()
       export_paths_hex()
       menu_exit()
      end,
    },
    {
     sprite=9,
     label="load",
     fn=
      function()
       load_paths_from_cartdata()
       menu_exit()
      end,
    },
    {
     sprite=9,
     label="save",
     fn=
      function()
       save_paths_to_cartdata()
       menu_exit()
      end,
    },
   }
  else
   menu_items =
   {
    {
     sprite=1,
     label="finish",
     fn=
      function()
       grid_menu_finish()
       menu_exit()
      end,
    },
    {
     sprite=2,
     label="cancel",
     fn=menu_exit,
    },
    {
     sprite=3,
     label="delete",
     fn=
      function()
       grid_menu_delete()
       menu_exit()
      end,
    },
   }
  end
  menu_init(menu_items)
 end
end

function grid_menu_finish()
 -- don't save zero-length paths
 if #paths[cpath] == 0 then
  deli(paths, cpath)
 end
 cpath = nil
end

function grid_menu_delete()
 if #paths[cpath] > 0 then
  deli(paths[cpath])
  if #paths[cpath] > 0 then
   pos = paths[cpath][#paths[cpath]]
  end
 end
end

-->8
-- menu

function menu_init(items)
 menu_items = items
 menu_selected = nil

 _draw = function()
  grid_draw()
  menu_draw()
 end
 _update60 = menu_update60
end

function menu_draw()
 camera(-64, -64)
 local r = 32
 local n = #menu_items

 -- shadow and pie
 fillp(0b1010010110100101)
 circfill(0, 0, r + 5, 1)
 fillp()
 circfill(0, 0, r, 6)

 -- highlight selected wedge
 if menu_selected != nil then
  for x = -r, r do
   for y = -r, r do
    local theta = atan2(x, y)
    if theta >= (menu_selected - 1) / n
    and theta < menu_selected / n
    and sqrt(x * x + y * y) < r + 1
    and pget(x, y) == 6 then
     pset(x, y, 13)
    end
   end
  end
 end

 -- for each menu choice
 for i = 1, n do
  -- wedge separator
  line(0, 0, r * cos((i - 1) / n), r * sin((i - 1) / n), 5)

  -- icon
  if i != menu_selected then
   pal(7, 5)
  end
  local x = r * 0.55 * cos((i - 0.5) / n)
  local y = r * 0.55 * sin((i - 0.5) / n)
  spr(menu_items[i].sprite, x - 4, y - 7)

  -- label
  local label = menu_items[i].label
  local max_line_chars = 0
  for label_line in all(split(label, "\n")) do
   max_line_chars = max(max_line_chars, #label_line)
  end
  print(label, x - max_line_chars * 2, y + 2, 7)
  pal()
 end
end

function menu_update60()
 if btnp(0) or btnp(2) then
  if menu_selected == nil then
   menu_selected = #menu_items
  else
   menu_selected += 1
   if menu_selected > #menu_items then menu_selected = 1 end
  end
 end

 if btnp(1) or btnp(3) then
  if menu_selected == nil then
   menu_selected = 1
  else
   menu_selected -= 1
   if menu_selected < 1 then menu_selected = #menu_items end
  end
 end

 if btnp(4) then
  if menu_selected == nil then
   error_beep()
  else
   menu_items[menu_selected].fn()
  end
 end

 if btnp(5) then
  error_beep()
 end
end

function menu_exit()
 grid_init()
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
 mirror_h = false
 mirror_v = false
end

function palette_draw()
 camera(-34, -14)
 local px, py = unpack(palette_coords)

 -- palette shadow
 clip(34 - 5, 14 - 5, 60 + 5 * 2, 80 + 5 * 2)
 fillp(0b1010010110100101)
 rectfill(-5, -5, 60 + 5, 80 + 5, 1)

 -- palette background
 clip(34, 14, 60, 80)
 fillp()
 rectfill(0, 0, 60 - 1, 80 - 1, 6)

 -- color swatches
 for kx = 0, 3 do
  for ky = 0, 3 do
   local c = (kx * 4) + ky
   local x = 1 + 2 * (kx + 1) + 12 * kx
   local y = 1 + 2 * (ky + 1) + 12 * ky
   rectfill(x, y, x + 12 - 1, y + 12 - 1, c)

   -- corner box
   local corner_color = 6
   local check_color = 5

   local hover = kx == px and ky == py
   if hover then
    corner_color = 13
    check_color = 7
   end

   local selected = false
   if palette_selected != nil then
    local sx, sy = unpack(palette_selected)
    selected = kx == sx and ky == sy
   end

   rectfill(x, y, x + 3, y + 3, corner_color)
   if selected then
    pal(7, check_color)
    spr(4, x, y)
    pal()
   end
  end
 end

 -- mode switches and ok button
 for k, label in pairs({"h", "v", "x", "o"}) do
  local kx = k - 1
  local x = 1 + 2 * (kx + 1) + 12 * kx
  local y = 60 + 4

  local box_color = 6
  local fg_color = 5

  local hover = kx == px and 4 == py
  if hover then
   box_color = 13
   fg_color = 7
  end

  rectfill(x, y, x + 12 - 1, y + 12 - 1, box_color)
  pal(7, fg_color)

  if label == "x" then
   spr(2, x + 2, y + 2)
  elseif label == "o" then
   spr(1, x + 2, y + 2)
  else
   print("\^w\^t" .. label, x + 3, y + 1, fg_color)
  end

  local selected = (kx == 0 and mirror_h) or (kx == 1 and mirror_v)
  if selected then
   spr(4, x, y)
  end

  pal()
 end
end

function palette_update60()
 local px, py = unpack(palette_coords)
 if btnp(0) then px -= 1 end
 if btnp(1) then px += 1 end
 if btnp(2) then py -= 1 end
 if btnp(3) then py += 1 end
 px %= 4
 -- line 4 is flip toggles and cancel/ok buttons
 py %= 5
 palette_coords = {px, py}

 if btnp(4) then
  if py < 4 then
   palette_selected = {unpack(palette_coords)}
  else
   if px == 0 then
    mirror_h = not mirror_h
   elseif px == 1 then
    mirror_v = not mirror_v
   elseif px == 2 then
    grid_init()
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
  error_beep()
 end
end

-- start a new line and exit palette mode
function palette_exit()
 local px, py = unpack(palette_selected)
 add(paths, {
   color = (px * 4) + py,
   mirror_h = mirror_h,
   mirror_v = mirror_v,
 })
 cpath = #paths
 grid_init()
end


__gfx__
00000000000007770077770000000700000700000000000000000000000770007777777700000000000000000000000000000000000000000000000000000000
00000000000007770777777000007770707000000007700000000000007777007000000700000070000000000000000000000000000000000000000000000000
00700700000007777700077700077777070000000007700000000000077777707077770700007777000000000000000000000000000000000000000000000000
00077000000707777700707700777770000000000777777007777770000770007000000700777777000000000000000000000000000000000000000000000000
00077000007777777707007707777700000000000777777007777770700770077777777777777770000000000000000000000000000000000000000000000000
00700700077777707770007777777070000000000007700000000000700770077700007777777070000000000000000000000000000000000000000000000000
00000000007777000777777007770007000000000007700000000000700000070700007707707000000000000000000000000000000000000000000000000000
00000000000700000077770000777777000000000000000000000000777777770077777700700000000000000000000000000000000000000000000000000000
