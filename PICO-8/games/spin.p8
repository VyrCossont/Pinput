pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- Geometry Wars demake
-- @vyr@demon.social

#include ../pinput.lua
#include spin/math.lua
#include spin/debug.lua
#include spin/init.lua
#include spin/update.lua
#include spin/draw.lua
#include spin/vspr.lua
#include spin/shapes.lua
#include spin/spawn.lua
#include spin/enemies.lua
#include spin/input.lua
#include spin/record_stubbed.lua

-- uncomment to include recording and replay functions
-- #include spin/format.lua
-- #include spin/record.lua

-- this has to be at the end after record.lua is loaded
-- uncomment to load replay data
-- /!\ replays that are too long will exhaust the token limit
-- #include spin/replay.lua

__gfx__
000000000f0f0f0f00000000c000000cc000000c00cccc00e000000e000d0000b000000b0b0000b0000000000000000000000000000000000000000000000000
00000000f0f0f0f00000c000000000000c0000c00c0000c0000000000000000000000000b000000b000000000000000000000000000000000000000000000000
000000000f0f0f0f000000000000000000000000c000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000f0f0f0f00c0000000000000000000000c000000c000000000000000d0000000000000000000000000000000000000000000000000000000000000000
000000000f0f0f0f000000c00000000000000000c000000c00000000d00000000000000000000000000000000000000000000000000000000000000000000000
00000000f0f0f0f0000000000000000000000000c000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000f0f0f0f000c0000000000000c0000c00c0000c0000000000000000000000000b000000b000000000000000000000000000000000000000000000000
00000000f0f0f0f000000000c000000cc000000c00cccc00e000000e0000d000b000000b0b0000b0000000000000000000000000000000000000000000000000
07777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07077070000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07077070000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700000f00f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070000f000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
707777070ffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0700007000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000007000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000c0000eeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aa0000000000000c0c000ee0000ee0eeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aa0a00007700000c000c00e0e00e0e0ee00ee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa0000000777700c00000c0e00ee00e0e0ee0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aa00000007700000c000c00e00ee00e0e0ee0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aa0a000000000000c0c000e0e00e0e0ee00ee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aa00000000000000c0000ee0000ee0eeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000eeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000008800888188808080000000018880000088808881888088800000000100000000000000010000000000000001000000000000000100
00000000000001000000008080808180808080080000018080000000808081008000800000000100000000000000010000000000000001000000000000000100
00000000000001000000008080880188808080000000018080000088808881088008800000000100000000000000010000000000000001000000000000000100
00000000000001000000008080808180808880080000018080000080000081008000800000000100000000000000010000000000000001000000000000000100
00000000000001000088808880808180808880000000018880080088800081888088800000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000080808881880088808880888180008880000000018880000088008801888088800000000100000000000000010000000000000001000000000000000100
00000080808081808080800800800180008080080000018080000008000801808080800000000100000000000000010000000000000001000000000000000100
0000008080888180808880080088018880808000000001808c000008000801888088800000000100000000000000010000000000000001000000000000000100
0000008080800180808080080080018c8c80800800000c8c80c0000800c8cc008080800000000100000000000000010000000000000001000000000000000100
11888118818111888181811811888188818881111111c188811811888c8881c18188811111111111111111111111111111111111111111111111111111111111
0000000000000100000000000000010c0c00000000000c0cc0c0000000c0cc000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100c0000000000001c00c000000000c01000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000007700000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000777000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000077000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000070000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000070010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000007770010000000000007701000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000077700010000000000777701000000000000000100
11111111111111c11111111111111111111111111111111111111111111111111111111111111c11111111111711111111111111117111111111111111111111
0000000000000c0c000000000000010000000000000001000000000000000100000000000000c1c00000000000000100000000000000010000000c0000000100
000000000000c100c0000000000001000000000000000100000000000000010000000000000c010c00000000000001000000000000000100000cc0cc00000100
0000000000000c0c000000000000010000000000000001000000000000000100000000000000c1c0000000000000010000000000000001000cc00000c0000100
00000000000001c00000000000000100000000000000010000000000000001000000000000000c000000000000000100000000000000010000cc00cc00000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000007700000cc0000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000777000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000077000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000071000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
0000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010c
000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000777700001c0
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000007700000c00
000000000000010000000000000001000000000000000100c00000000000010000000000000001000000000000000100000000000000010000000070000001c0
00000000000001000000000000000100000000000000010c0c00000000000100000000000000010000000000000001000000000000000100000000000000010c
00000000000001000000000000000100000000000000010c00c000000000010e0000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000000010000000000000001c000c000000000010eee00000000000100000000000000010000000000000001000000000000000100
000000000000010000000000000001000000000000000c00000c0000000001eeee00000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000000010000000000000001c000c00000000001ee0e00000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010c00c0000000000100ee00000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010c0c000000000001000000000000000100000000000000010000000007777701000000000000000100
000000000000010000000000000001000000000000000100c0000000000001000000000000000100000000000000010000000000777001000000000000000100
0000000000000100000000000000010000000000000001000000000000000100000000000000010000e000000000017700000000700001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000777000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000077000000000000001000000000000000100
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111171111111111111111111111111111111111
00000000000001000000000000000100000000000000010000000000000001000000000000000107700000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000777700000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000107000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000107000000000000010c00000000000001000000000000000100
0000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001c0c0000000000001000000000000000100
000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000c000c000000000001000000000000000100
0000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001ccc0000000000001000000000000000100
0000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001c0c0000000000001000000000000000100
0000000000000100000000000000010000000000000001ee000000000000010007000000000001000000000000000c0c0c000000000001000000000000000100
00000000000001000000000000000100000000000000ee0e0000000000000100770000000000010000000000000001c0c0000000000001000000000000000100
00000000000001000000000000000e00000000000000eee0e0000000000001077000000000000100000000000000010c00000000000001000000000000000100
000000000000010000000000000eeee00000000000000eeee000000000aaaa007000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000ee00ee00000000000000ee00000000aaaaa01000000000000000100000000000000010000000000000001000000000000000100
000000000000010000000000ee00e10e00000000000001000000000a00a001000000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000eeeee0e000000000000010000000000a0a001000a00000e00000100000000000000010000000000000001000000000000000100
1111111111111111111111111e11e1eee11111111111111111111111a11a11111a1111eee1111111111111111111111111111111111111111111111111111111
00000000000001000000000000e0e1ee0000000000000100000000000a0aa1000a000eeeee00010000000000000001000000000000000100000000e000000100
00000000000001000000000000eeee000000000000000100000000000a0aaaa00a0000eee0000100000000000000010c000000000000010000000eeee0000100
000000000000010000000000000e01000000000000000100000000000a0a010aaa00000e0000010000000000000001c0c0000000000001000000eeeee0000100
0000000000000100000000000000010000000000000001000000000aa0a001000a000000000001000000000000000c000c0000000000010000000eee00000100
0000000000000100000000000000010000000000a000a1a00000000000aaaaaaaa0000000000010000000000000001c0c0000000000001000000000e00000100
0000000000000100000000000000010000000000000001000000000a00000100000000000000010000000000000001c0c0000000000001000000000000000100
0000000000000100000000000000010000000000000001000000000a000001000000000000000100000000000000010c00000000000001000000000000000100
00000000000001000000000000000e00000000000000a100a0000a00e00001000000000000000100000000000000010000000000000001000000000000000100
000000000000010000000000000eeee0000000000000010000a000eeee0001000000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000ee00ee000000000000001000000ee00ee0001000000000000000100000000000000010000000000000001000000000000000100
000000000000010000000000ee00e10e0000000000000100000ee00e00e001000000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000eeeee0e000000000000010000e0eeeee0e001000000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000e00e1eee0000000000001000000e00e0eee01000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000e0e1ee000000000000010000000e0e0ee00100000000000000010000000000000001eeee000000000001000000000000000100
00000000000001c00000000000eeee00000000000000010000000eeee00001000000000000000c0000000000000001eeee000000000001000000000000000100
1111111111111c1c11111111111e11111111111111111111111111e111111111111111111111c1c111111111111111eeee111111111111111111111111111111
000000000000c100c0000000000001000000000000000100000000000000010000000000000c010c00000000000001eeee000000000001000000000000000100
0000000000000c0c000000000000010000000000000001000000000000000100000000000000c1c0000000000000010000000000000001000000000000000100
0000000000000c0c000000000000010000000000000001000000000000000100000000000000c1c0000000000000010000000000000001000000000000000100
00000000000001c00000000000000100000000000000010000000000000001000000000000000c00000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
000000000000010000000000000001000000000000000100c0000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010c0c000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010c00c00000000001000000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000000010000000000000001c000c00000000001000000000000000100000000000000010000000000000001000000000000000100
000000000000010000000000000001000000000000000c00000c0000000001000000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000000010000000000000001c000c0000000000100000000000000010000000000000001000000000000000100000000e000000100
00000000000001000000000000000100000000000000010c00c00000000001000000000000000100000000000000010000000000000001000000eeee00000100
00000000000001000000000000000100000000000000010c0c000000000001000000000000000100000000000000010000000000000001000000e0eee0000100
000000000000010000000000000001000000000000000100c00000000000010000000000000001000000000000000100000000000000010000000eee00000100
000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000e0000000100
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
00000000000001000000000000000100c0000000000001c00c000000000c01000000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000000010c0c00000000000c0cc0c0000000c0cc000000000000000100000000000000010000000000000001000000000000000100
000000000000010000000000000001c000c000000000c1c0c00c00000c0001c00000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000000010c0c00000000000c0c00c0000000c00c000000000000000100000000000000010000000000000001000000000000000100
0000000000000100000000000000010c0c00000000000c0cc0c0000000c0c1000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100c0000000000001c00c000000000c01000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100
00000000000001000000000000000100000000000000010000000000000001000000000000000100000000000000010000000000000001000000000000000100

__map__
0101010101010101010101010101010107020003070208060704090607050900110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
030100003d6603d6603c6603a660396403864036640356303363032620316202f6202c6102b6102b6102961002600026000260002600026000260002600016000060000600006000060000600006000060000600
