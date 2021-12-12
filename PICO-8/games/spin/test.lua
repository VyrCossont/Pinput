

luaunit = require('luaunit')

require 'pico8_compat'

test_pico8_compat = {
 test_ord = function()
  luaunit.assertEquals(ord("@"), 64)
  luaunit.assertEquals(ord("123", 2), 50)
  luaunit.assertEquals(table.pack(ord("123"), 2, 3), {50, 51, 52})
 end,
}

require 'format'

test_format = {
 test_format_is_id = function()
  luaunit.assertTrue(format_is_id("x"))
  luaunit.assertTrue(format_is_id("_"))
  luaunit.assertTrue(format_is_id("x1"))
  luaunit.assertTrue(format_is_id("_1"))
  luaunit.assertFalse(format_is_id("1"))
 end,
}

os.exit(luaunit.LuaUnit.run())
