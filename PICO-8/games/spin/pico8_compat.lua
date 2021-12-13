-- import these functions to make Lua 5.4 expose a more PICO-8-like API.
-- intended for getting some PICO-8 code to run in LuaUnit.

-- not documented in PICO-8 manual
-- https://www.lua.org/manual/5.4/manual.html#pdf-table.pack
pack = table.pack

-- not documented in PICO-8 manual
-- https://www.lua.org/manual/5.4/manual.html#pdf-table.unpack
unpack = table.unpack

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#ADD
-- https://www.lua.org/manual/5.4/manual.html#pdf-table.insert
add = table.insert

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#ALL
-- https://www.lua.org/pil/7.html
function all(tbl)
 local i = 0
 function iter()
  i = i + 1
  if i > #tbl then
   return nil
  end
  return tbl[i]
 end
 return iter, nil, nil
end

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#CHR
-- https://www.lua.org/manual/5.4/manual.html#pdf-string.char
chr = string.char

-- third arg has a different meaning from vanilla string.byte
-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#ORD
-- https://www.lua.org/manual/5.4/manual.html#pdf-string.byte
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
-- https://www.lua.org/manual/5.4/manual.html#pdf-string.sub
function sub(str, pos0, ...)
 local opt_args = pack(...)
 local pos1 = ...
 if opt_args.n >= 1 and type(pos1) ~= 'number' then
  pos1 = pos0
 end
 return string.sub(str, pos0, pos1)
end

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#TOSTR
-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#Types_and_assignment
-- https://www.lua.org/manual/5.4/manual.html#pdf-tostring
-- https://www.lua.org/manual/5.4/manual.html#pdf-string.format
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.modf
function tostr(...)
 local args = pack(...)
 if args.n == 0 then
  return ''
 end
 local val, format_flags = ...
 if format_flags == nil then
  format_flags = 0
 elseif format_flags == false then
  format_flags = 0
 elseif format_flags == true then
  format_flags = 1
 end
 local type_val = type(val)

 -- not affected by either format flag
 if type_val == 'nil' or type_val == 'thread' then
  return '[' .. type_val .. ']'
 elseif type_val == 'string' then
  return val
 elseif type_val == 'boolean' then
  return tostring(boolean)
 end

 -- affected by hex flag
 local hex = (format_flags >> 0) & 1 == 1
 if type_val == 'function' or type_val == 'table' then
  if hex then
   return tostring(val)
  else
   return '[' .. type_val .. ']'
  end
 end

 -- at this point we should be down to numbers
 assert(type_val == 'number')
 local shift16 = (format_flags >> 1) & 1 == 1
 if not hex and not shift16 then
  return tostring(val)
 end
 val = math.modf(val * 2^16)
 if not hex and shift16 then
  return tostring(val)
 end
 val = string.format("%016x", val)
 if shift16 then
  val = string.sub(val, -8)
 else
  val = string.sub(val, -8, -5) .. '.' .. string.sub(val, -4)
 end
 return '0x' .. val
end
