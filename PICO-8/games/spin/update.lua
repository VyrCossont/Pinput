-- _update60()

cpu_update60 = 0

function _update60()
 local cpu_base = stat(1)
 update60()
 cpu_update60 = stat(1) - cpu_base
end

function update60()
 -- if we have no inputs, give up
 if record_replay == nil
 and (not pi_is_inited() or not pi_flag(pi_connected)) then
  return
 end

 -- advance replay, if there is one
 record_playback_advance()

 -- read sticks here for recording purposes
 -- also used for actual input below
 local lx, ly = pi_stick(pi_l)
 local rx, ry = pi_stick(pi_r)
 record_frame_inputs(lx, ly, rx, ry)

 -- update particles
 -- do this even if we're dead
 for i = #particles, 1, -1 do
  if abs(particles[i].dx) < 0.01 or abs(particles[i].dy) < 0.01 then
   deli(particles, i)
  end
 end

 for particle in all(particles) do
  particle.x = particle.x + particle.dx
  particle.y = particle.y + particle.dy
  particle.dx = particle.dx * 0.9
  particle.dy = particle.dy * 0.9
 end

 if display_dead > 0 then
  display_dead = display_dead - 1
  cpu_update60 = stat(1) - cpu_base
  return
 end

 -- move the ship
 if lx ~= 0 or ly ~= 0 then
  ship.theta = atan2(lx, ly)
  ship.x = ship.x + lx
  ship.y = ship.y + ly

  -- keep ship inside world
  ship.x = mid(-world_r, ship.x, world_r)
  ship.y = mid(-world_r, ship.y, world_r)

  -- generate modest exhaust trail
  if rnd() > 0.3 then
   add(particles, {
    x = ship.x,
    y = ship.y,
    dx = rnd(0.5) - 0.25,
    dy = rnd(0.5) - 0.25,
    color = 10,
   })
  end
 end

 -- shoot bullets
 if fire_counter == 0 then
  if abs(rx) > 0.5
  or abs(ry) > 0.5 then
   add(bullets, {
    x = ship.x,
    y = ship.y,
    dx = rx * 3 + lx,
    dy = ry * 3 + ly,
   })
   fire_counter = fire_cooldown
  end
 else
  fire_counter = fire_counter - 1
 end

 -- move bullets
 for i = #bullets, 1, -1 do
  local bullet = bullets[i]
  -- vanish when edge is hit
  if abs(bullet.x) > world_r
  or abs(bullet.y) > world_r then
   deli(bullets, i)
  else
   bullet.x = bullet.x + bullet.dx
   bullet.y = bullet.y + bullet.dy
  end
 end

 for i = #diamonds, 1, -1 do
  local diamond = diamonds[i]

  update_throb(diamonds, diamond)
  seek_player(diamonds, diamond)
  clamp_to_world(diamond)
  local ship_dead = check_ship_collision(diamonds, diamond)
  if ship_dead then
   cpu_update60 = stat(1) - cpu_base
   return
  end
  check_bullet_collision(diamonds, diamond, i)
 end

 for i = #splitters, 1, -1 do
  local splitter = splitters[i]

  update_throb(splitters, splitter)
  seek_player(splitters, splitter)
  clamp_to_world(splitter)
  local ship_dead = check_ship_collision(splitters, splitter)
  if ship_dead then
   cpu_update60 = stat(1) - cpu_base
   return
  end
  local dead = check_bullet_collision(splitters, splitter, i)
  if dead then
   splitter_split(splitter)
  end
 end

 for i = #splitter_frags, 1, -1 do
  local splitter_frag = splitter_frags[i]

  update_throb(splitter_frags, splitter_frag)
  splitter_frag_orbit(splitter_frag)
  clamp_to_world(splitter_frag)
  local ship_dead = check_ship_collision(splitter_frags, splitter_frag)
  if ship_dead then
   cpu_update60 = stat(1) - cpu_base
   return
  end
  check_bullet_collision(splitter_frags, splitter_frag, i)
 end

 spawn_update60()
 cpu_update60 = stat(1) - cpu_base
end
