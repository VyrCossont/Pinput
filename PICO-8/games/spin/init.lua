-- _init()

cartdata_highscore = 0

-- one-time init
function _init()
 cartdata("vyrcossont_geometry_wars_0")
 highscore = dget(cartdata_highscore)
 input_init()
 overlay_init()
 restart_init()
end

-- reusable init
function restart_init()
 record_init()
 world_init()
 spawn_init()
end

function world_init()
 waiting_to_start = true
 waiting_to_start_interval = 45
 waiting_to_start_blink = waiting_to_start_interval
 world_r = 128
 display_dead = 0
 particles = {}
 -- number of frames
 bomb_duration = 30
 -- treated as 32-bit int
 score = 0
 num_bombs = 3
 num_lives = 3
 max_bombs = 9
 max_lives = 9
 -- treated as 32-bit int
 incr_bombs = 100 * (10000 >> 16)
 -- treated as 32-bit int
 incr_lives = 75 * (10000 >> 16)
 max_multiplier = 10
 per_life_init()
end

function per_life_init()
 enemy_init()

 ship = {
  x = 0,
  y = 0,
  theta = 0,
 }
 bullets = {}
 fire_counter = 0
 fire_cooldown = 4
 -- if ttl >= 0, bomb is exploding
 bomb_blast = {
  x = 0,
  y = 0,
  r = 0,
  ttl = -1,
 }
 -- set to false when trigger pulled, set to true when trigger fully released
 bomb_ready = true
 multiplier = 1
 kills = 0
end

-- todo: move these

function end_run()
 -- save high score
 if score > highscore then
  highscore = score
  dset(cartdata_highscore, highscore)
 end

 -- restart game
 restart_init()
end

function kill_ship()
 -- particle blast from ship
 for _ = 1, 16 do
  add(particles, {
   x = ship.x,
   y = ship.x,
   dx = rnd(5) - 2.5,
   dy = rnd(5) - 2.5,
   color = 10,
  })
 end

 if num_lives == 1 then
  end_run()
 else
  num_lives = num_lives - 1

  -- mark player as dead for a second
  display_dead = 60

  per_life_init()
 end
end
