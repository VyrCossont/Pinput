-- spawn subsystem

function spawn_init()
 -- start to the right of the "magic square"
 -- used by brightline
 spawn_x, spawn_y = 16, 0
 -- _update60 calls until spawn cursor advances
 spawn_interval = 60
 -- calls remaining until spawn cursor advances
 spawn_counter = 0
 -- enemies spawn in waves
 -- map of sprite_num to count remaining from that wave
 waves = {}
end

function spawn_update60()
 spawn_counter = spawn_counter - 1
 if spawn_counter > 0 then
  return
 end

 -- execute the current tile
 local sprite_num = mget(spawn_x, spawn_y)
 -- end-of-data marker
 if sprite_num == 17 then
  spawn_x = 16
  spawn_y = 0
  return
 end

 -- sprite sheet pixel coordinates
 local sprite_x = (sprite_num % 16) * 8
 -- todo: should be \, not flr(/),
 --       but Lua didn't introduce an equivalent until 5.3,
 --       and that equivalent is //, which is a C-compatible comment in P8 Lua.
 local sprite_y = flr((sprite_num / 16)) * 8
 -- turn each colored pixel into an enemy
 for sdx = 0, 7 do
  for sdy = 0, 7 do
   local c = sget(sprite_x + sdx, sprite_y + sdy)
   local world_x = (sdx * 127) / 7 - 64
   local world_y = (sdy * 127) / 7 - 64

   -- spawn around player
   world_x = world_x + ship.x
   world_y = world_y + ship.y

   -- stay inside the world
   world_x = mid(-world_r, world_x, world_r)
   world_y = mid(-world_r, world_y, world_r)

   -- switch on pixel color
   if c == 12 then
    add(diamonds, {
     wave = sprite_num,
     x = world_x,
     y = world_y,
     throb = 0,
    })
   elseif c == 14 then
    add(splitters, {
     wave = sprite_num,
     x = world_x,
     y = world_y,
     throb = 0,
    })
   end

   -- increment wave counter
    if waves[sprite_num] == nil then
     waves[sprite_num] = 0
    end
    waves[sprite_num] = waves[sprite_num] + 1
  end
 end

 -- advance the spawn cursor
 spawn_counter = spawn_interval
 spawn_x = spawn_x + 1
 if spawn_x <= 127 then
  return
 end
 -- go to next row of the map
 spawn_y = spawn_y + 1
 -- loop if we hit the end of spawn data.
 -- don't go into the bottom (shared) half of the map,
 -- in case we want to use all the sprites later.
 if spawn_y > 31 then
  spawn_y = 0
 end
 -- avoid magic square
 if spawn_y <= 15 then
  spawn_x = 16
 else
  spawn_x = 0
 end
end
