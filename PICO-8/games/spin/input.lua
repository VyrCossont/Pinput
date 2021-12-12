-- input

-- sticks
pi_l = 0
pi_r = 2

-- read normalized stick
-- /!\ pico-8 is upside down
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
