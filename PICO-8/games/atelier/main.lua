function _init()

end

function _draw()

end

function _update60()

end

--- [adapted from Lua wiki](http://lua-users.org/wiki/ObjectOrientationTutorial)
function make_class()
 local cls = {}
 function cls.new(...)
  local instance = setmetatable({}, cls)
  local init = cls._init
  if init then
   init(instance, ...)
  end
  return instance
 end
 function cls.__call(cls_, ...)
  return cls_.new(...)
 end
 return cls
end

--- @module Crafting
Crafting = {}

--- @class Crafting.Element
--- @field i number Index for arrays.
--- @field name string Human-readable name of element.
Crafting.Element = make_class()

function Crafting.Element:_init(i, name)
 self.i = i
 self.name = name
end
-- TODO: figure out why this isn't callable (run main_test.lua for error)
Crafting.Element.FIRE = Crafting.Element(1, 'fire')
Crafting.Element.ICE = Crafting.Element.new(2, 'ice')
Crafting.Element.LIGHTNING = Crafting.Element.new(3, 'lightning')
Crafting.Element.WIND = Crafting.Element.new(4, 'wind')

--- @class Crafting.Item
--- a usable item, piece of equipment, or material
--- @field recipe Crafting.Recipe
--- @field desc string
Crafting.Item = {}

--- @class Crafting.Recipe
--- the recipe for an item
--- @field start Crafting.Recipe.Node
Crafting.Recipe = {}

--- @class Crafting.Recipe.Requirement
--- a Ryza material loop
--- @field element Crafting.Element
--- @field count number
Crafting.Recipe.Requirement = {}

--- @class Crafting.Recipe.Node
--- a Ryza material loop
--- @field levels Crafting.Recipe.Node.Level[]
Crafting.Recipe.Node = {}

--- @class Crafting.Recipe.Node.Level
Crafting.Recipe.Node.Level = {}
