luaunit = require('luaunit')

require 'pico8_compat'
require 'format'

test_format = {}

function test_format.test_format_is_id()
 luaunit.assertTrue(format_is_id('x'))
 luaunit.assertTrue(format_is_id('_'))
 luaunit.assertTrue(format_is_id('x1'))
 luaunit.assertTrue(format_is_id('_1'))
 luaunit.assertFalse(format_is_id('1'))
end

function test_format.test_format_toliteral()
 luaunit.assertEquals(
   format_toliteral('x'),
   '"x"'
 )
 luaunit.assertEquals(
   format_toliteral(2),
   '2'
 )
 luaunit.assertEquals(
   format_toliteral({'a', 'b', 'c'}),
   '{"a","b","c"}'
 )
 luaunit.assertEquals(
   format_toliteral({'a', 'b', 'c'}, 0),
   '{\n "a",\n "b",\n "c",\n}'
 )
end

os.exit(luaunit.LuaUnit.run())
