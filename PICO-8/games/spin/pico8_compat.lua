-- import these functions to make Lua 5.4 expose a more PICO-8-like API.
-- intended for getting some PICO-8 code to run in LuaUnit.

--{{{ table

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

--}}}

--{{{ math

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#MAX
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.max
max = math.max

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#MIN
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.min
min = math.min

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#MID
function mid(x, y, z)
 local min_xyz = math.min(x, y, z)
 local max_xyz = math.max(x, y, z)
 if x ~= min_xyz and x ~= max_xyz then
  return x
 elseif y ~= min_xyz and y ~= max_xyz then
  return y
 else
  return z
 end
end

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#FLR
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.floor
flr = math.floor

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#CEIL
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.ceil
ceil = math.ceil

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#COS
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.cos
function cos(x)
 return math.cos(x * (2 * math.pi))
end

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#COS
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.cos
function sin(x)
 return -math.sin(x * (2 * math.pi))
end

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#ATAN2
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.atan
function atan2(dx, dy)
 return math.atan(-dy, dx) / (2 * math.pi)
end

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#SQRT
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.sqrt
sqrt = math.sqrt

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#ABS
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.abs
abs = math.abs

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#RND
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.random
function rnd(x)
 if type(x) == table then
  return x[math.random(1, #x)]
 else
  return x * math.random()
 end
end

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#SRAND
-- https://www.lua.org/manual/5.4/manual.html#pdf-math.randomseed
function srand(x)
 math.randomseed(x)
end

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#Quirks_of_PICO_8
function sgn(x)
 if x < 0 then
  return -1
 else
  return 1
 end
end

--}}}

--{{{ string

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

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#SPLIT
function split(str, separator, convert_numbers)
 if separator == nil then
  separator = ','
 elseif separator == '' then
  separator = 1
 elseif type(separator) == 'string' then
  separator = string.sub(separator, 1, 1)
 end
 if convert_numbers == nil then
  convert_numbers = true
 end

 local groups = {}
 if type(separator) == 'number' then
  for i = 1, #str, separator do
   table.insert(groups, string.sub(str, i, i + separator - 1))
  end
 else
  local group_start = 1
  for i = 1, #str do
   if string.sub(str, i, i) == separator then
    table.insert(groups, string.sub(str, group_start, i - 1))
    group_start = i + 1
   end
   if i == #str then
    table.insert(groups, string.sub(str, group_start))
   end
  end
 end

 if convert_numbers then
  for k, v in ipairs(groups) do
   local v_num = tonumber(v)
   if v_num ~= nil then
    groups[k] = v_num
   end
  end
 end

 return groups
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

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#TONUM
-- https://www.lua.org/manual/5.4/manual.html#pdf-tonumber
function tonum(val, format_flags)
 -- todo: use format_flags
 return tonumber(val)
end

--}}}
