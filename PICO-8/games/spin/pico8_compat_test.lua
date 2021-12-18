-- most test cases reproduced from the PICO-8 manual

-- setup:
-- brew install luarocks
-- luarocks install luaunit

luaunit = require('luaunit')

require 'pico8_compat'

--{{{ table

test_pico8_compat_table = {}

function test_pico8_compat_table.test_all()
 local tbl = {1, 2, 3}
 local len = 0
 local sum = 0
 for x in all(tbl) do
  len = len + 1
  sum = sum + x
 end
 luaunit.assertEquals(
   len,
   3
 )
 luaunit.assertEquals(
   sum,
   6
 )
end

--}}}

--{{{ math

test_pico8_compat_math = {}

function test_pico8_compat_math.test_mid()
 luaunit.assertEquals(
   mid(7, 5, 10),
   7
 )
 luaunit.assertEquals(
   mid(5, 7, 10),
   5
 )
 luaunit.assertEquals(
   mid(5, 10, 7),
   7
 )
end

function test_pico8_compat_math.test_flr()
 luaunit.assertEquals(
   flr(4.1),
   4
 )
 luaunit.assertEquals(
   flr(-2.3),
   -3
 )
end

function test_pico8_compat_math.test_ceil()
 luaunit.assertEquals(
   ceil(4.1),
   5
 )
 luaunit.assertEquals(
   ceil(-2.3),
   -2
 )
end

function test_pico8_compat_math.test_sin()
 luaunit.assertEquals(
   sin(0.25),
   -1
 )
end

function test_pico8_compat_math.test_atan2()
 luaunit.assertEquals(
   atan2(0, -1),
   0.25
 )
end

function test_pico8_compat_math.sgn()
 luaunit.assertEquals(
   sgn(-1),
   -1
 )
 luaunit.assertEquals(
   sgn(0),
   1
 )
 luaunit.assertEquals(
   sgn(1),
   1
 )
end

--}}}

--{{{ string

test_pico8_compat_string = {}

function test_pico8_compat_string.test_chr()
 luaunit.assertEquals(
   chr(64),
   '@'
 )
 luaunit.assertEquals(
   chr(104, 101, 108, 108, 111),
   'hello'
 )
end

function test_pico8_compat_string.test_ord()
 luaunit.assertEquals(
   ord('@'),
   64
 )
 luaunit.assertEquals(
   ord('123', 2),
   50
 )
 -- /!\ this example is wrong in the PICO-8 manual
 luaunit.assertEquals(
   table.pack(ord('1234', 2, 3)),
   {50, 51, 52, n = 3}
 )
end

function test_pico8_compat_string.test_sub()
 local s = 'the quick brown fox'
 luaunit.assertEquals(
   sub(s, 5, 9),
   'quick'
 )
 luaunit.assertEquals(
   sub(s, 5),
   'quick brown fox'
 )
 luaunit.assertEquals(
   sub(s, 5, _),
   'q'
 )
end

function test_pico8_compat_string.test_split()
 luaunit.assertEquals(
   split('1,2,3'),
   {1, 2, 3}
 )
 luaunit.assertEquals(
   split('one:two:3', ':', false),
   {'one', 'two', '3'}
 )
 luaunit.assertEquals(
   split('1,,2,'),
   {1, '', 2, ''}
 )
 luaunit.assertEquals(
   split(',1,,2,'),
   {'', 1, '', 2, ''}
 )
end

function test_pico8_compat_string.test_tostr()
 luaunit.assertEquals(
   tostr(-32768, true),
   '0x8000.0000'
 )
 luaunit.assertEquals(
   tostr(32767.99999, true),
   '0x7fff.ffff'
 )
 luaunit.assertEquals(
   tostr(),
   ''
 )
 luaunit.assertEquals(
   tostr(nil),
   '[nil]'
 )
 luaunit.assertEquals(
   tostr(17),
   '17'
 )
 luaunit.assertEquals(
   tostr(17, 0x01),
   '0x0011.0000'
 )
 luaunit.assertEquals(
   tostr(17, 0x03),
   '0x00110000'
 )
 luaunit.assertEquals(
   tostr(17, 0x02),
   '1114112'
 )
end

function test_pico8_compat_string.test_tonum()
 luaunit.assertEquals(
   tonum('17.5'),
   17.5
 )
 luaunit.assertEquals(
   tonum(17.5),
   17.5
 )
 luaunit.assertEquals(
   table.pack(tonum('hoge')).n,
   0
 )
 luaunit.assertEquals(
   tonum('ff', 0x1),
   255
 )
 luaunit.assertEquals(
   tonum('1114112', 0x2),
   17
 )
 luaunit.assertEquals(
   tonum('1234abcd', 0x3),
   0x1234.abcd
 )
 luaunit.assertEquals(
   tonum('hoge', 0x4),
   0
 )
end

--}}}

os.exit(luaunit.LuaUnit.run())
