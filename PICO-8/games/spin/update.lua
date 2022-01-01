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

 local skip = slowdown_update60()
 if skip then
  return
 end

 overlay_update60()

 -- advance replay, if there is one
 record_playback_advance()

 -- read sticks here for recording purposes
 -- also used for actual input below
 local lx, ly = pi_stick(pi_l)
 local rx, ry = pi_stick(pi_r)
 local lt = pi_trigger(pi_lt)
 local rt = pi_trigger(pi_rt)
 record_frame_inputs(lx, ly, rx, ry, lt, rt)

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

 -- todo: collect all bomb code to its own subsystem

 -- update bomb
 if bomb_blast.ttl >= 0 then
  bomb_blast.ttl = bomb_blast.ttl - 1
  bomb_blast.r = bomb_blast.r + 3
 end

 -- drop bomb
 if max(lt, rt) > 0 and bomb_ready and bomb_blast.ttl < 0 then
  bomb_ready = false
  if num_bombs > 0 then
   num_bombs = num_bombs - 1
   bomb_blast.x = ship.x
   bomb_blast.y = ship.y
   bomb_blast.r = 0
   bomb_blast.ttl = bomb_duration
  end
 elseif max(lt, rt) == 0 then
  bomb_ready = true
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

 -- perform all enemy behavior
 -- todo: extract these to classes or ECS

 for i = #diamonds, 1, -1 do
  local diamond = diamonds[i]

  update_throb(diamonds, diamond)
  seek_player(diamonds, diamond)
  clamp_to_world(diamond)
  local ship_dead = check_ship_collision(diamonds, diamond)
  if ship_dead then
   return
  end
  check_bullet_collision(diamonds, diamond, i)
  check_bomb_collision(diamonds, diamond, i)
 end

 for i = #splitters, 1, -1 do
  local splitter = splitters[i]

  update_throb(splitters, splitter)
  seek_player(splitters, splitter)
  clamp_to_world(splitter)
  local ship_dead = check_ship_collision(splitters, splitter)
  if ship_dead then
   return
  end
  local dead = check_bullet_collision(splitters, splitter, i)
  if dead then
   splitter_split(splitter)
  end
  check_bomb_collision(splitters, splitter, i)
 end

 for i = #splitter_frags, 1, -1 do
  local splitter_frag = splitter_frags[i]

  update_throb(splitter_frags, splitter_frag)
  splitter_frag_orbit(splitter_frag)
  clamp_to_world(splitter_frag)
  local ship_dead = check_ship_collision(splitter_frags, splitter_frag)
  if ship_dead then
   return
  end
  check_bullet_collision(splitter_frags, splitter_frag, i)
  check_bomb_collision(splitter_frags, splitter_frag, i)
 end

 for i = #pinwheels, 1, -1 do
  local pinwheel = pinwheels[i]

  update_throb(pinwheels, pinwheel)
  drift(pinwheel)
  bounce(pinwheel)
  clamp_to_world(pinwheel)
  local ship_dead = check_ship_collision(pinwheels, pinwheel)
  if ship_dead then
   return
  end
  check_bullet_collision(pinwheels, pinwheel, i)
  check_bomb_collision(pinwheels, pinwheel, i)
 end

 for i = #leprechauns, 1, -1 do
  local leprechaun = leprechauns[i]

  update_throb(leprechauns, leprechaun)
  seek_player(leprechauns, leprechaun)
  dodge(leprechauns, leprechaun)
  clamp_to_world(leprechaun)
  local ship_dead = check_ship_collision(leprechauns, leprechaun)
  if ship_dead then
   return
  end
  check_bullet_collision(leprechauns, leprechaun, i)
  check_bomb_collision(leprechauns, leprechaun, i)
 end

 spawn_update60()
end
