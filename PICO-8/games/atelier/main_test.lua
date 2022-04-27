luaunit = require('luaunit')

dofile('../spin/pico8_compat.lua')
require 'main'

test_Crafting_Element = {}

function test_Crafting_Element.test_new()
 luaunit.assertEquals(
   Crafting.Element.FIRE.name,
   'fire'
 )
end

os.exit(luaunit.LuaUnit.run())
