-- _draw()

-- custom characters
glyph_bomb = "\^:1c22414941221c00"
glyph_claw = "\^:002442663c180000"

-- _draw() call timer
cpu_draw = 0

function _draw()
 if record_replay == nil and not input_is_inited() then
  input_draw_instructions()
  return
 elseif record_replay == nil and not input_is_connected() then
  cls()
  print("player #1, connect your gamepad...")
  return
 end

 local cpu_base = stat(1)
 draw()
 cpu_draw = stat(1) - cpu_base

 overlay_draw()

 -- reset camera for HUD
 camera()

 -- profiling/debug HUD at bottom of screen
 overlay_draw_hud()

 -- game HUD at top of screen
 print(
  "SCORE     "
  .. hud_lives_text()
  .. hud_bombs_text()
  .. " HIGHSCORE",
  0, 0, 15
 )
 print(
  hud_score_text()
  .. "              "
  .. hud_highscore_text()
 )
end

-- todo: reuse/extract format functions

-- always 6 drawn chars wide
function hud_lives_text()
 if num_lives > 3 then
  return "    " .. num_lives .. glyph_claw
 else
  local s = ""
  for _ = 1, num_lives do
   s = glyph_claw .. s
  end
  for _ = 1, 6 - (num_lives * 2) do
   s = " " .. s
  end
  return s
 end
end

-- always 6 drawn chars wide
function hud_bombs_text()
 if num_bombs > 3 then
  return glyph_bomb .. num_bombs .. "    "
 else
  local s = ""
  for _ = 1, num_bombs do
   s = s .. glyph_bomb
  end
  for _ = 1, 6 - (num_bombs * 2) do
   s = s .. " "
  end
  return s
 end
end

-- x: 32-bit integer
function format_with_commas(x)
 local s = tostr(x, 2)
 local chunks = {}
 for i = #s, 1, -3 do
  add(
   chunks,
   sub(s, max(0, i - 2), i),
   1)
 end
 s = chunks[1]
 for i = 2, #chunks do
  s = s .. "," .. chunks[i]
 end
 return s
end

-- always 9 chars wide
function hud_score_text()
 local s = format_with_commas(score)
 while #s < 9 do
  s = s .. " "
 end
 return s
end

-- always 9 chars wide
function hud_highscore_text()
 local s = format_with_commas(highscore)
 while #s < 9 do
  s = " " .. s
 end
 return s
end

function draw()
 cls()

 -- remap peach to lime green
 pal(15, 138, 1)

 -- let the camera follow the player with a little parallax
 camera(-64 + (ship.x * 0.8), -64 + (ship.y * 0.8))

 -- draw basic grid
 for x = -world_r, world_r - 1, 16 do
  line(x, -world_r, x, world_r - 1, 1)
 end
 for y = -world_r, world_r - 1, 16 do
  line(-world_r, y, world_r - 1, y, 1)
 end

 -- draw edge of world
 rect(-world_r, -world_r, world_r - 1, world_r - 1, 6)

 -- draw the particles as streaks
 for particle in all(particles) do
  line(
   particle.x, particle.y,
   particle.x + particle.dx * 3, particle.y + particle.dy * 3,
   particle.color
  )
 end

 if waiting_to_start then
  camera()
  if waiting_to_start_blink >= 0 then
   -- todo: customize prompt for each input system
   print("press 🅾️ to start", 30, 62, 15)
  end
  return
 end

 if display_dead > 0 then
  return
 end

 for bullet in all(bullets) do
  local bullet_theta = atan2(bullet.dx, bullet.dy)
  vspr(shape_bullet, bullet.x, bullet.y, 1, 1, bullet_theta)
 end

 if bomb_blast.ttl >= 0 then
  for i = 0, 2 do
  circ(bomb_blast.x, bomb_blast.y, bomb_blast.r - i * 4, 7 - i)
  end
 end

 vspr(shape_claw, ship.x, ship.y, 1.5, 1.5, ship.theta)

 -- draw enemy shapes
 -- todo: extract these to classes or ECS

 for diamond in all(diamonds) do
  vspr(
   shape_diamond,
   diamond.x, diamond.y,
   3 + cos(diamond.throb), 3 + sin(diamond.throb),
   0
  )
 end

 for splitter in all(splitters) do
  vspr(
   shape_splitter,
   splitter.x, splitter.y,
   3, 3,
   splitter.throb
  )
 end

 for splitter_frag in all(splitter_frags) do
  vspr(
   shape_splitter,
   splitter_frag.x, splitter_frag.y,
   1.5, 1.5,
   splitter_frag.throb
  )
 end

 for pinwheel in all(pinwheels) do
  vspr(
   shape_pinwheel,
   pinwheel.x, pinwheel.y,
   3, 3,
   pinwheel.throb
  )
 end

 for leprechaun in all(leprechauns) do
  vspr(
   shape_leprechaun,
   leprechaun.x, leprechaun.y,
   3, 3,
   leprechaun.throb
  )
 end
end
