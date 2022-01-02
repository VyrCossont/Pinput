-- input

-- sticks
pi_l = 0
pi_r = 2

-- read normalized stick
-- /!\ pico-8 is upside down
-- todo: extract this to Pinput SDK
function pi_stick(s, pl)
 pl = pl or 0
 local x = pi_axis(s, pl) >> 15
 local y = ~(pi_axis(s + 1, pl) >> 15)
 -- deadzone
 if abs(x ^ 2 + y ^ 2) < 0.1 then
  return 0, 0
 end
 return x, y
end

-- compatibility input modes
-- for when you're not cool enough to have Pinput installed

-- does nothing
function input_noop()
end

-- always returns true
function input_true()
 return true
end

-- initialize entire input system
function input_init()
 -- all supported input modes
 input_modes = {
  {
   name = "pINPUT",
   init = pi_init,
   is_inited = pi_is_inited,
   is_connected = function() return pi_flag(pi_connected) end,
   deinit = input_noop,
   stick = pi_stick,
   trigger = pi_trigger,
  },
  {
   name = "devkit",
   init = devkit_init,
   is_inited = input_true,
   is_connected = input_true,
   deinit = devkit_deinit,
   stick = devkit_pi_stick,
   trigger = devkit_pi_trigger,
  },
  {
   name = "p1+p2",
   init = input_noop,
   is_inited = input_true,
   is_connected = input_true,
   deinit = input_noop,
   stick = p1p2_pi_stick,
   trigger = p1p2_pi_trigger,
  },
  -- todo: add recording playback
 }

 -- currently selected mode
 input_mode_index = 1

 -- functions defined by current input mode
 input_is_inited = nil
 input_is_connected = nil
 input_stick = nil
 input_trigger = nil

 input_change_mode(input_mode_index)
end

function input_menuitem(menu_buttons)
 local i = input_mode_index - 1
 if menu_buttons & (1 << ⬅️) == (1 << ⬅️) then
  i = i - 1
 elseif menu_buttons & (1 << ➡️) == (1 << ➡️) then
  i = i + 1
 end
 i = i % #input_modes
 i = i + 1
 input_change_mode(i)
 return true
end

-- change active input mode
function input_change_mode(new_input_mode_index)
 if input_mode_index ~= new_input_mode_index then
  local prev_mode = input_modes[input_mode_index]
  prev_mode.deinit()
 end
 input_mode_index = new_input_mode_index
 local mode = input_modes[input_mode_index]
 menuitem(1, "◀▶ input: " .. mode.name, input_menuitem)
 mode.init()
 input_is_inited = mode.is_inited
 input_is_connected = mode.is_connected
 input_stick = mode.stick
 input_trigger = mode.trigger
end

-- devkit mode: mouse and keyboard

devkit_flags_addr = 0x5f2d

-- we won't get mouse lock on the BBS,
-- but can work without it
function devkit_init()
 poke(devkit_flags_addr, 1 | 4)
end

function devkit_deinit()
 poke(devkit_flags_addr, 0)
end

-- movement: WASD or arrows
-- aiming: mouse
-- see https://pico-8.fandom.com/wiki/Stat#.7B28.7D_Raw_keyboard
-- and https://github.com/libsdl-org/SDL/blob/main/include/SDL_scancode.h
function devkit_pi_stick(s)
 if s == pi_l then
  local x, y = 0, 0
  if stat(28, 26) or stat(28, 82) then
   y = y - 1
  end
  if stat(28, 22) or stat(28, 81) then
   y = y + 1
  end
  if stat(28, 4) or stat(28, 80) then
   x = x - 1
  end
  if stat(28, 7) or stat(28, 79) then
   x = x + 1
  end
  return x, y
 elseif s == pi_r then
  local x = (mid(0, stat(32), 127)  - 64) >> 6
  local y = (mid(0, stat(33), 127)  - 64) >> 6
  -- deadzone
  if abs(x ^ 2 + y ^ 2) < 0.1 then
   return 0, 0
  end
  return x, y
 end
end

-- space bar controls both triggers
function devkit_pi_trigger()
 if stat(28, 44) then
  return 0xff
 else
  return 0
 end
end

-- p1 + p2 mode: use two gamepads
-- (or more likely, two sets of keyboard controls)

-- movement: p2 d-pad (ESDF)
-- aiming: p1 d-pad (arrows)
function p1p2_pi_stick(s)
 local pl = 1 - (s >> 1)
 local x, y = 0, 0
 if btn(⬆️, pl) then
  y = y - 1
 end
 if btn(⬇️, pl) then
  y = y + 1
 end
 if btn(⬅️, pl) then
  x = x - 1
 end
 if btn(➡️, pl) then
  x = x + 1
 end
 return x, y
end

-- left trigger: either 🅾️
-- right trigger: either ❎
function p1p2_pi_trigger(t)
 local b = 4 + t
 if btn(b, 0) or btn(b, 1) then
  return 0xff
 else
  return 0
 end
end
