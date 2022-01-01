-- _init()

-- one-time init
function _init()
 pi_init()
 restart_init()
end

-- reusable init
function restart_init()
 record_init()
 world_init()
 enemy_init()
 spawn_init()
end

function world_init()
 world_r = 128
 display_dead = 0
 particles = {}
 score = 0
 num_bombs = 3
 num_lives = 3
 max_bombs = 9
 max_lives = 9
 max_multiplier = 10
 per_life_init()
end

function per_life_init()
 ship = {
  x = 0,
  y = 0,
  theta = 0,
 }
 bullets = {}
 fire_counter = 0
 fire_cooldown = 4
 bomb_counter = 0
 bomb_cooldown = 60
 multiplier = 1
 kills = 0
end

-- todo: move this
function kill_ship()
 -- restart game
 restart_init()

 -- mark player as dead for a second
 display_dead = 60

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
end
