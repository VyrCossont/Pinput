-- import these functions to be vaguely compatible with Lua 5.2.

-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#SUB
-- https://www.lua.org/manual/5.2/manual.html#pdf-string.sub
function sub(str, pos0, pos1)
 if type(pos1) ~= 'number' then
  pos1 = pos0
 end
 return string.sub(str, pos0, pos1)
end

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
