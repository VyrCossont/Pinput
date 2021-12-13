-- enemy AI

-- init tables of enemy class properties,
-- which double as enemy lists
function enemy_init()
 diamonds = {
  -- color of sparks when one dies
  death_color = 12,
  -- collision radius with bullets
  bullet_r = 2,
  -- collision radius with ship
  ship_r = 4,
  -- speed towards player
  seek_speed = 0.1,
  -- per-frame increment for throb
  dthrob = 0.01,
 }

 splitters = {
  death_color = 14,
  bullet_r = 2,
  ship_r = 4,
  seek_speed = 0.2,
  dthrob = 0.01,
 }

 splitter_frags = {
  death_color = 14,
  bullet_r = 1,
  ship_r = 2,
  -- no seek speed: splitter frags don't seek
  orbit_r = 15,
  -- splitter frag throb is actually orbit speed
  dthrob = 0.02,
 }
end

-- update animation state
function update_throb(enemies, enemy)
 enemy.throb = (enemy.throb + enemies.dthrob) % 1
end

function seek_player(enemies, enemy)
 local dist_x = enemy.x - ship.x
 local dist_y = enemy.y - ship.y
 local dist = sqrt(dist_x ^ 2 + dist_y ^ 2)
 if dist > 0 then
  -- todo: don't let them move faster diagonally, do it right
  enemy.x = enemy.x - sgn(dist_x) * enemies.seek_speed
  enemy.y = enemy.y - sgn(dist_y) * enemies.seek_speed
 end
end

-- stay inside world
function clamp_to_world(enemy)
  enemy.x = mid(-world_r, enemy.x, world_r)
  enemy.y = mid(-world_r, enemy.y, world_r)
end

-- kill ship on contact
-- return whether ship was hit
function check_ship_collision(enemies, enemy)
 local dist_x = enemy.x - ship.x
 local dist_y = enemy.y - ship.y
 if abs(dist_x) < enemies.ship_r
 and abs(dist_y) < enemies.ship_r then
  kill_ship()
  return true
 end
 return false
end

-- die if close enough to a bullet
-- return whether enemy was hit
function check_bullet_collision(enemies, enemy, i)
 for b = #bullets, 1, -1 do
  local bullet = bullets[b]
  if abs(enemy.x - bullet.x) < enemies.bullet_r
  and abs(enemy.y - bullet.y) < enemies.bullet_r then
   deli(bullets, b)
   deli(enemies, i)

   -- particle blast
   for _ = 1, 8 do
    add(particles, {
     x = enemy.x,
     y = enemy.y,
     dx = rnd(5) - 2.5,
     dy = rnd(5) - 2.5,
     color = enemies.death_color,
    })
   end

   -- decrement wave counter
   waves[enemy.wave] = waves[enemy.wave] - 1
   if waves[enemy.wave] == 0 then
    waves[enemy.wave] = nil
    spawn_counter = 0
   end

   return true
  end
 end
 return false
end

-- break into three chunks on death
function splitter_split(splitter)
 for i = 1, 3 do
  local theta = (i - 1) / 3
  add(splitter_frags, {
   wave = splitter.wave,
   origin_x = splitter.x,
   origin_y = splitter.y,
   x = splitter.x + cos(theta) * splitter_frags.orbit_r,
   y = splitter.y + sin(theta) * splitter_frags.orbit_r,
   throb = theta,
  })
 end
 -- increment wave counter
 if waves[splitter.wave] == nil then
  waves[splitter.wave] = 0
 end
 waves[splitter.wave] = waves[splitter.wave] + 3
end

-- orbit around origin point
function splitter_frag_orbit(splitter_frag)
 splitter_frag.x = splitter_frag.origin_x
  + cos(splitter_frag.throb) * splitter_frags.orbit_r
 splitter_frag.y = splitter_frag.origin_y
  + sin(splitter_frag.throb) * splitter_frags.orbit_r
end