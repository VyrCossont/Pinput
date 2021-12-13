-- setup:
-- brew install luarocks
-- luarocks install luaunit

luaunit = require('luaunit')

require 'pico8_compat'

-- test cases reproduced from the PICO-8 manual
test_pico8_compat = {}

function test_pico8_compat.test_chr ()
 luaunit.assertEquals(
   chr(64),
   "@"
 )
 luaunit.assertEquals(
   chr(104, 101, 108, 108, 111),
   "hello"
 )
end

function test_pico8_compat.test_ord()
 luaunit.assertEquals(
   ord("@"),
   64
 )
 luaunit.assertEquals(
   ord("123", 2),
   50
 )
 -- /!\ this example is wrong in the PICO-8 manual
 luaunit.assertEquals(
   table.pack(ord("1234", 2, 3)),
   {50, 51, 52, n = 3}
 )
end

function test_pico8_compat.test_sub()
 local s = "the quick brown fox"
 luaunit.assertEquals(
   sub(s, 5, 9),
   "quick"
 )
 luaunit.assertEquals(
   sub(s, 5),
   "quick brown fox"
 )
 luaunit.assertEquals(
   sub(s, 5, _),
   "q"
 )
end

require 'format'

test_format = {}

function test_format.test_format_is_id()
 luaunit.assertTrue(format_is_id("x"))
 luaunit.assertTrue(format_is_id("_"))
 luaunit.assertTrue(format_is_id("x1"))
 luaunit.assertTrue(format_is_id("_1"))
 luaunit.assertFalse(format_is_id("1"))
end

os.exit(luaunit.LuaUnit.run())
