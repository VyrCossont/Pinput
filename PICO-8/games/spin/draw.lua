-- _draw()

cpu_draw = 0

function _draw()
 if record_replay == nil and not pi_is_inited() then
  cls()
  print("waiting for pinput connection...")
  return
 elseif record_replay == nil and not pi_flag(pi_connected) then
  cls()
  print("player #1, connect your gamepad...")
  return
 end

 local cpu_base = stat(1)
 draw()
 cpu_draw = stat(1) - cpu_base

 -- reset camera for profiling HUD
 camera()

 -- CPU
 print("    _draw: " .. cpu_draw .. "\n_update60: " .. cpu_update60, 2, 2, 8)
end

function draw()
 cls()

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

 if display_dead > 0 then
  spr(16, -4, -4)
  return
 end

 for bullet in all(bullets) do
  local bullet_theta = atan2(bullet.dx, bullet.dy)
  vspr(shape_bullet, bullet.x, bullet.y, 1, 1, bullet_theta)
 end

 vspr(shape_claw, ship.x, ship.y, 1.5, 1.5, ship.theta)

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
end
