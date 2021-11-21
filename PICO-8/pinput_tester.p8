pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- pinput gamepad tester v0.1.2
-- @vyr@demon.social

function _init()
 pi_init()
end

trigger_rumble = true

ls_center_x = 32
ls_center_y = 48
ls_dx = 0
ls_dy = 0

rs_center_x = 96
rs_center_y = 48
rs_dx = 0
rs_dy = 0

stick_r = 16
stick_dot_r = 4

trigger_width = 32
trigger_height = 8
trigger_y = 16
lt_x = 16
rt_x = 80

lt_dx = 0
rt_dx = 0

clr_border = 5
clr_fill = 7

clrs_button = {[false]=clr_border, [true]=clr_fill}

⬆️_x = 32 - 4
⬆️_y = 80 - 8

⬇️_x = 32 - 4
⬇️_y = 80 + 8

⬅️_x = 32 - 8 - 4
⬅️_y = 80

➡️_x = 32 + 8 - 4
➡️_y = 80

a_x = 96 - 4
a_y = 80 - 8
a_x = 96 - 4
a_y = 80 + 8

b_x = 96 - 4
b_y = 80 + 8
b_x = 96 + 8 - 4
b_y = 80

x_x = 96 - 8 - 4
x_y = 80

y_x = 96 + 8 - 4
y_y = 80
y_x = 96 - 4
y_y = 80 - 8

btn_r = 4

ls_x = ls_center_x - 24
ls_y = ls_center_y

rs_x = rs_center_x + 24
rs_y = rs_center_y

lb_x = ls_center_x - 24
lb_y = trigger_y + 4

rb_x = rs_center_x + 24
rb_y = trigger_y + 4

guide_x = 64
back_x = guide_x - 8
start_x = guide_x + 8
meta_y = 32

battery_y = 96
battery_x = 64 - 4

function _draw()
 cls()
 
 if not pi_is_inited() then
  print('waiting for pinput connection...')
  return
 end
 
 -- buttons
 
 print("⬆️", ⬆️_x, ⬆️_y,
  clrs_button[pi_btn(pi_⬆️, 0)])
 
 print("⬇️", ⬇️_x, ⬇️_y,
  clrs_button[pi_btn(pi_⬇️, 0)])
 
 print("⬅️", ⬅️_x, ⬅️_y,
  clrs_button[pi_btn(pi_⬅️, 0)])
 
 print("➡️", ➡️_x, ➡️_y,
  clrs_button[pi_btn(pi_➡️, 0)])
	
 circ(a_x + 1, a_y + 2, btn_r, clr_border)
 print("a", a_x, a_y,
  clrs_button[pi_btn(pi_a, 0)])
 
 circ(b_x + 1, b_y + 2, btn_r, clr_border)
 print("b", b_x, b_y,
  clrs_button[pi_btn(pi_b, 0)])

 circ(x_x + 1, x_y + 2, btn_r, clr_border)
 print("x", x_x, x_y,
  clrs_button[pi_btn(pi_x, 0)])
 
 circ(y_x + 1, y_y + 2, btn_r, clr_border)
 print("y", y_x, y_y,
  clrs_button[pi_btn(pi_y, 0)])

 circ(ls_x, ls_y, btn_r * 1.5, clr_border)
 print("ls", ls_x - 3, ls_y - 2,
  clrs_button[pi_btn(pi_ls, 0)])

 circ(rs_x, rs_y, btn_r * 1.5, clr_border)
 print("rs", rs_x - 3, rs_y - 2,
  clrs_button[pi_btn(pi_rs, 0)])

 circ(lb_x, lb_y, btn_r * 1.5, clr_border)
 print("lb", lb_x - 3, lb_y - 2,
  clrs_button[pi_btn(pi_lb, 0)])

 circ(rb_x, rb_y, btn_r * 1.5, clr_border)
 print("rb", rb_x - 3, rb_y - 2,
  clrs_button[pi_btn(pi_rb, 0)])
  
 print("⬅️", back_x - 2, meta_y,
  clrs_button[pi_btn(pi_back, 0)])

 if pi_flag(pi_has_guide_button, 0) then
  print("⌂", guide_x - 2, meta_y,
   clrs_button[pi_btn(pi_guide, 0)])
 end

 if pi_flag(pi_has_misc_button, 0) then
  print("★", guide_x - 2, meta_y + 6,
   clrs_button[pi_btn(pi_misc, 0)])
 end
 
 print("➡️", start_x - 2, meta_y,
  clrs_button[pi_btn(pi_start, 0)])
	
 -- sticks

 circ(
  ls_center_x,
  ls_center_y,
  stick_r,
  clr_border)
 circfill(
  ls_center_x + ls_dx,
  ls_center_y + ls_dy,
  stick_dot_r,
  clr_fill)

 circ(
  rs_center_x,
  rs_center_y,
  stick_r,
  clr_border)
 circfill(
  rs_center_x + rs_dx,
  rs_center_y + rs_dy,
  stick_dot_r,
  clr_fill)
  
 -- triggers

 rectfill(
  lt_x,
  trigger_y,
  lt_x + lt_dx,
  trigger_y + trigger_height,
  clr_fill)
 rect(
  lt_x,
  trigger_y,
  lt_x + trigger_width,
  trigger_y + trigger_height,
  clr_border)
   
 rectfill(
  rt_x + (trigger_width - rt_dx),
  trigger_y,
  rt_x + trigger_width,
  trigger_y + trigger_height,
  clr_fill)
 rect(
  rt_x,
  trigger_y,
  rt_x + trigger_width,
  trigger_y + trigger_height,
  clr_border)

 -- battery

 if pi_flag(pi_has_battery, 0) then
  print("+-\n█", battery_x, battery_y, clr_border)
  if pi_flag(pi_charging, 0) then
   print("\n∧", battery_x, battery_y, clr_fill)
  end
  print(
   tostr("\n\n" .. flr(pi_battery(0) / 0xff * 100)) .. "%",
   battery_x, battery_y, clr_fill)
 end

 -- flags

 if pi_flag(pi_has_rumble, 0) then
  local rumbling = lt_dx > 0 or rt_dx > 0
  print('  \72\65\83\n\32\82\85\77\66\76\69',
   guide_x - 15, trigger_y,
   clrs_button[rumbling])
  end
end

function _update60()
 local lt = pi_trigger(pi_lt, 0)
 local rt = pi_trigger(pi_rt, 0)
 
 if pi_is_inited() and trigger_rumble then
  pi_rumble(pi_lo, lt, 0)
  pi_rumble(pi_hi, rt, 0)
 end
 
 lt_dx = lt / (0xff / trigger_width)
 rt_dx = rt / (0xff / trigger_width)
 
 ls_dx = max(-0x7fff, pi_axis(pi_lx, 0)) / (0x7fff / stick_r)
 ls_dy = -max(-0x7fff, pi_axis(pi_ly, 0)) / (0x7fff / stick_r)

 rs_dx = max(-0x7fff, pi_axis(pi_rx, 0)) / (0x7fff / stick_r)
 rs_dy = -max(-0x7fff, pi_axis(pi_ry, 0)) / (0x7fff / stick_r)
end

-->8
#include pinput.lua

__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000055555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555500000
00000500000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000050000
00005000000050005555555555555555555555555555555550000000000000000000000000000000555555555555555555555555555555555000500000005000
00050000000005005700000000000000000000000000000050000000000000000000000000000000500000000000000000777777777777775005000000000500
00500700077700505700000000000000000000000000000050000000000000000000000000000000500000000000000000777777777777775050077707770050
00500700070700505700000000000000000000000000000050000000000000000000000000000000500000000000000000777777777777775050070707070050
00500700077000505700000000000000000000000000000050000000000000000000000000000000500000000000000000777777777777775050077007700050
00500700070700505700000000000000000000000000000050000000000000000000000000000000500000000000000000777777777777775050070707070050
00500777077700505700000000000000000000000000000050000000000000000000000000000000500000000000000000777777777777775050070707770050
00050000000005005700000000000000000000000000000050000000000000000000000000000000500000000000000000777777777777775005000000000500
00005000000050005555555555555555555555555555555550000000000000000000000000000000555555555555555555555555555555555000500000005000
00000500000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000050000
00000055555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555500000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000555555500000000000000000005555500005550000555550000000000000000055555550000000000000000000000000000
00000000000000000000000000555000000055500000000000000055500550055555005500555000000000000055500000005550000000000000000000000000
00000000000000000000000055000000000000055000000000000055000550555555505500055000000000005500000000000005500000000000000000000000
00000000000000000000000500000000000000000500000000000055500550050505005500555000000000050000000000000000050000000000000000000000
00000000000000000000055000000000000000000055000000000005555500050555000555550000000005500000000000000000005500000000000000000000
00000000000000000000500000000000000000000000500000000000000000000000000000000000000050000000000000000000000050000000000000000000
00000000000000000000500000000000000000000000500000000000000000000000000000000000000050000000000000000000000050000000000000000000
00000000000000000005000000000000000000000000050000000000000000000000000000000000000500000000000000000000000005000000000000000000
00000000000000000050000000000000000000000000005000000000000000000000000000000000005000000000000000000000000000500000000000000000
00000000000000000050000000000000000000000000005000000000000000000000000000000000005000000000000000000000000000500000000000000000
00000055555000000500000000000000000000000000000500000000000000000000000000000000050000000000000000000000000000050000005555500000
00000500000500000500000000000000000000000000000500000000000000000000000000000000050000000000000000000000000000050000050000050000
00005000000050000500000000000000000000000000000500000000000000000000000000000000050000000000000777000000000000050000500000005000
00050000000005005000000000000000000000000000000050000000000000000000000000000000500000000000077777770000000000005005000000000500
00500500005500505000000000000000000000000000000050000000000000000000000000000000500000000000077777770000000000005050055500550050
00500500050000505000000000000000000000000000000050000000000000000000000000000000500000000000777777777000000000005050050505000050
00500500055500505000000000000000000000000000000050000000000000000000000000000000500000000000777777777000000000005050055005550050
00500500000500505000000000000000000000000000000050000000000000000000000000000000500000000000777777777000000000005050050500050050
00500555055000505000000000000000000000000000000050000000000000000000000000000000500000000000077777770000000000005050050505500050
00050000000005005000000000000000000000000000000050000000000000000000000000000000500000000000077777770000000000005005000000000500
00005000000050000500000000000000000000000000000500000000000000000000000000000000050000000000000777000000000000050000500000005000
00000500000500000500000000000000000000000000000500000000000000000000000000000000050000000000000000000000000000050000050000050000
00000055555000000500000000000000000000000000000500000000000000000000000000000000050000000000000000000000000000050000005555500000
00000000000000000050000000000000000000007770005000000000000000000000000000000000005000000000000000000000000000500000000000000000
00000000000000000050000000000000000000777777705000000000000000000000000000000000005000000000000000000000000000500000000000000000
00000000000000000005000000000000000000777777750000000000000000000000000000000000000500000000000000000000000005000000000000000000
00000000000000000000500000000000000007777777770000000000000000000000000000000000000050000000000000000000000050000000000000000000
00000000000000000000500000000000000007777777770000000000000000000000000000000000000050000000000000000000000050000000000000000000
00000000000000000000055000000000000007777777770000000000000000000000000000000000000005500000000000000000005500000000000000000000
00000000000000000000000500000000000000777777700000000000000000000000000000000000000000050000000000000000050000000000000000000000
00000000000000000000000055000000000000777777700000000000000000000000000000000000000000005500000000000005500000000000000000000000
00000000000000000000000000555000000055507770000000000000000000000000000000000000000000000055500000005550000000000000000000000000
00000000000000000000000000000555555500000000000000000000000000000000000000000000000000000000055555550000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055000550000000000000000000000000000000
00000000000000000000000000000777770000000000000000000000000000000000000000000000000000000050505050000000000000000000000000000000
00000000000000000000000000007770777000000000000000000000000000000000000000000000000000000500505005000000000000000000000000000000
00000000000000000000000000007700077000000000000000000000000000000000000000000000000000000500555005000000000000000000000000000000
00000000000000000000000000007700077000000000000000000000000000000000000000000000000000000500005005000000000000000000000000000000
00000000000000000000000000000777770000000000000000000000000000000000000000000000000000000050555050000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055000550000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000055500000555000005550000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000005500055000000000550005500000000000000000000000
00000000000000000000077777000000000005555500000000000000000000000000000000000000005050505000000000507770500000000000000000000000
00000000000000000000777007700000000055005550000000000000000000000000000000000000050050500500000005007070050000000000000000000000
00000000000000000000770007700000000055000550000000000000000000000000000000000000050005000500000005007700050000000000000000000000
00000000000000000000777007700000000055005550000000000000000000000000000000000000050050500500000005007070050000000000000000000000
00000000000000000000077777000000000005555500000000000000000000000000000000000000005050505000000000507770500000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000005500055000000000550005500000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000055500000555000005550000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055000550000000000000000000000000000000
00000000000000000000000000000555550000000000000000000000000000000000000000000000000000000050555050000000000000000000000000000000
00000000000000000000000000005500055000000000000000000000000000000000000000000000000000000500505005000000000000000000000000000000
00000000000000000000000000005500055000000000000000000000000000000000000000000000000000000500555005000000000000000000000000000000
00000000000000000000000000005550555000000000000000000000000000000000000000000000000000000500505005000000000000000000000000000000
00000000000000000000000000000555550000000000000000000000000000000000000000000000000000000050505050000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055000550000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

