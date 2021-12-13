-- import these functions to make Lua 5.2 expose a more PICO-8-like API.
-- intended for getting some PICO-8 code to run in LuaUnit.

-- not documented in PICO-8 manual
-- https://www.lua.org/manual/5.2/manual.html#pdf-table.pack
pack = table.pack

-- not documented in PICO-8 manual
-- https://www.lua.org/manual/5.2/manual.html#pdf-table.unpack
unpack = table.unpack

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#CHR
-- https://www.lua.org/manual/5.2/manual.html#pdf-string.char
chr = string.char

-- third arg has a different meaning from vanilla string.byte
-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#ORD
-- https://www.lua.org/manual/5.2/manual.html#pdf-string.byte
function ord(str, index, num_results)
 if type(str) ~= 'string' then
  return nil
 end
 if type(index) == 'number' and index > #str then
  return nil
 end
 local last_index = index
 if type(index) == 'number' and type(num_results) == 'number' then
  last_index = index + num_results - 1
 end
 return string.byte(str, index, last_index)
end

-- third arg has a different meaning from vanilla string.sub
-- and behaves differently if not provided (and thus default nil)
-- vs. if provided (and thus still nil)
-- but the number of function arguments is different.
-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#SUB
-- https://www.lua.org/manual/5.2/manual.html#pdf-string.sub
function sub(str, pos0, ...)
 local opt_args = pack(...)
 local pos1 = ...
 if opt_args.n >= 1 and type(pos1) ~= 'number' then
  pos1 = pos0
 end
 return string.sub(str, pos0, pos1)
end
