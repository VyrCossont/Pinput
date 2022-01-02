-- debugging functions

cartdata_overlay_enabled = 2

function overlay_init()
-- render debug overlay and profiling HUD
 overlay_enabled = dget(cartdata_overlay_enabled) == 0
 overlay_menuitem()
end

function overlay_menuitem()
 overlay_enabled = not overlay_enabled
 if overlay_enabled then
  menuitem(2, "◆ debug overlay", overlay_menuitem)
  dset(cartdata_overlay_enabled, 1)
 else
  menuitem(2, "○  debug overlay", overlay_menuitem)
  dset(cartdata_overlay_enabled, 0)
 end
 return true
end

-- draw functions to be called in draw calls until next update
overlay_deferreds = {}

-- defer a draw function from update code
-- until the camera's set up to draw it.
-- probably cheaper than capturing all the args in a closure.
function overlay_defer(fn, ...)
 if not overlay_enabled then
  return
 end
 add(overlay_deferreds, {fn, pack(...)})
end

-- draw debugging overlay
function overlay_draw()
 if not overlay_enabled then
  return
 end
 for overlay_deferred in all(overlay_deferreds) do
  local fn, args = unpack(overlay_deferred)
  fn(unpack(args))
 end
end

-- reset debugging overlay
function overlay_update60()
 overlay_deferreds = {}
end

-- draw profiling HUD
function overlay_draw_hud()
 if not overlay_enabled then
  return
 end
 -- todo: if we draw this at 108, it messes up the camera?
 print("    _draw: " .. cpu_draw, 0, 104, 8)
 print("_update60: " .. cpu_update60)
 print(" slowdown: " .. slowdown_divider .. ":1" .. " mouse: " .. stat(32) .. ", " .. stat(33))
end

-- slow time
slowdown_counter = 0
slowdown_divider = 1
-- arbitrary
slowdown_divider_max = 8
-- rough equivalent of btnp() repeat rate
slowdown_cooldown = 0
slowdown_cooldown_max = 15

-- returns whether we should skip the rest of this update
function slowdown_update60()
 -- adjust slowdown divider from button inputs
 if pi_btn(pi_x) and slowdown_cooldown == 0 then
  slowdown_divider = slowdown_divider - 1
  slowdown_cooldown = slowdown_cooldown_max
 end
 if pi_btn(pi_y) and slowdown_cooldown == 0 then
  slowdown_divider = slowdown_divider + 1
  slowdown_cooldown = slowdown_cooldown_max
 end
 slowdown_cooldown = max(0, slowdown_cooldown - 1)
 slowdown_divider = mid(slowdown_divider, 1, slowdown_divider_max)

 -- update the slowdown counter
 slowdown_counter = slowdown_counter + 1
 slowdown_counter = slowdown_counter % slowdown_divider
 return slowdown_counter ~= 0
end
