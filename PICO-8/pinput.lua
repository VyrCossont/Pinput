-- pinput client
-- @vyr@demon.social

-- common

pi_gpio = 0x5f80

pi_magic = {
 0x46c7.2002,
 0x6e44.ab77,
 0xd67f.dcbe,
 0x4d98.77d2,
}

pi_num_players = 8
pi_gamepad_stride = 16

-- write pinput magic to gpio
function pi_init()
 for i = 1, #pi_magic do
  poke4(
   pi_gpio + 4 * (i - 1),
   pi_magic[i]
  )
 end
end

-- if magic is cleared,
-- pinput is ready
function pi_is_inited()
 return $pi_gpio != pi_magic[1]
end

-- buttons

pi_buttons_offset = 2
pi_num_buttons = 16

pi_⬆️ = 0
pi_⬇️ = 1
pi_⬅️ = 2
pi_➡️ = 3

pi_start = 4
pi_back = 5

pi_ls = 6
pi_rs = 7

pi_lb = 8
pi_rb = 9

pi_guide = 10

pi_reserved = 11

pi_a = 12
pi_🅾️ = pi_a
pi_b = 13
pi_❎ = pi_b
pi_x = 14
pi_y = 15

-- read a button
function pi_btn(b, pl)
 pl = pl or 0
 if pl < 0 or pl >= pi_num_players
 or b < 0 or b >= pi_num_buttons then
  return 0
 end
 
 local buttons = %(pi_gpio
  + pl * pi_gamepad_stride
  + pi_buttons_offset)
 return 1 & (buttons >> b)  
end

-- triggers

pi_trigger_offset = 4
pi_trigger_stride = 1

pi_lt = 0
pi_rt = 1

pi_num_triggers = 2

-- read a trigger
function pi_trigger(t, pl)
 pl = pl or 0
 if pl < 0 or pl >= pi_num_players
 or t < 0 or t >= pi_num_triggers then
  return 0
 end
 
 return @(pi_gpio
  + pl * pi_gamepad_stride
  + pi_trigger_offset
  + t * pi_trigger_stride)
end

-- sticks

pi_axis_offset = 6
pi_axis_stride = 2
pi_num_axes = 4

pi_lx = 0
pi_ly = 1

pi_rx = 2
pi_ry = 3

function pi_axis(a, pl)
 pl = pl or 0
 if pl < 0 or pl >= pi_num_players
 or a < 0 or a >= pi_num_axes then
  return 0
 end
 
 return %(pi_gpio
  + pl * pi_gamepad_stride
  + pi_axis_offset
  + a * pi_axis_stride)
end

-- todo:

-- gamepad capabilities
-- gamepad count
-- rumble
-- battery/charging status
