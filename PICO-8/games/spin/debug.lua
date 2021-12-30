-- debugging functions

-- draw functions to be called in draw calls until next update
overlay_deferreds = {}

-- defer a draw function from update code
-- until the camera's set up to draw it.
-- probably cheaper than capturing all the args in a closure.
function overlay_defer(fn, ...)
 add(overlay_deferreds, {fn, pack(...)})
end

-- draw debugging overlay
function overlay_draw()
 for overlay_deferred in all(overlay_deferreds) do
  local fn, args = unpack(overlay_deferred)
  fn(unpack(args))
 end
end

-- reset debugging overlay
function overlay_update60()
 overlay_deferreds = {}
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
