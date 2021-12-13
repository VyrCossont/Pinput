-- string formatting functions

-- /!\ Lua strings are immutable,
-- and PICO-8 doesn't have table.concat,
-- so these will be sloooooow.
-- todo: use pack/unpack and ord/chr as necessary

function format_repeat(s, n)
 local r = ''
 for _ = 1, n do
  r = r .. s
 end
 return r
end

-- implement printf %0nd
function format_lzpad(s, n)
 s = tostr(s)
 return format_repeat('0', n - #s) .. s
end

-- insertion sort step for any x comparable
-- with the contents of t
function format_add_in_order(t, x)
 for i = 1, #t + 1 do
  if t[i] == nil or x < t[i] then
   add(t, x, i)
   return
  end
 end
end

-- convert value to Lua literal
function format_toliteral(x, indent)
 if type(x) == 'nil' then
  return 'nil'
 elseif type(x) == 'string' then
  return format_toliteral_string(x)
 elseif type(x) == 'table' then
  return format_toliteral_table(x, indent)
 else
  -- will not produce valid Lua for functions or coroutines
  return tostr(x)
 end
end

-- named Lua escapes
format_toliteral_lua_escapes = {
 ['\\'] = '\\\\',
 ["'"] = "\\\'",
 ['"'] = '\\"',
 ['\a'] = '\\a',
 ['\b'] = '\\b',
 ['\f'] = '\\f',
 ['\n'] = '\\n',
 ['\r'] = '\\r',
 ['\t'] = '\\t',
 ['\v'] = '\\v',
}

-- return quoted string,
-- using ASCII characters where possible
-- and named Lua escapes or hex escapes otherwise.
function format_toliteral_string(s)
 local q = '"'
 for i = 1, #s do
  local c = sub(s, i, nil)
  if c == "'" then
   -- using a double-quoted string,
   -- so we don't need to escape single quotes
   q = q .. c
  else
   local e = format_toliteral_lua_escapes[c]
   if e ~= nil then
    q = q .. e
   else
    local o = ord(c)
    if format_isascii(o) then
     q = q .. c
    else
     q = q .. '\\x' .. sub(tostr(o, 1), 5, 6)
    end
   end
  end
 end
 return q .. '"'
end

function format_isascii(o)
 return 0x00 <= o and o <= 0x7f
end

function format_isalpha(o)
 return (0x41 <= o and o <= 0x5a)
   or (0x61 <= o and o <= 0x7a)
   -- underscore
   or o == 0x5f
end

function format_isdigit(o)
 return 0x30 <= o and o <= 0x39
end

-- can this string be used as a Lua ID or unquoted string key?
function format_is_id(s)
 assert(type(s) == 'string')
 if #s == 0 then
  return false
 end
 local o = ord(sub(s, 1, nil))
 if not format_isalpha(o) then
  return false
 end
 for i = 2, #s do
  o = ord(sub(s, i, nil))
  if not (format_isalpha(o) or format_isdigit(o)) then
   return false
  end
 end
 return true
end

-- convert table to string in stable format
function format_toliteral_table(t, indent)
 -- get keys from pairs and sort them within type
 -- booleans can't be compared
 local false_key = false
 local true_key = false
 local string_keys = {}
 local number_keys = {}
 for k, _ in pairs(t) do
  if k == false then
   false_key = true
  elseif k == true then
   true_key = true
  elseif type(k) == 'string' then
   format_add_in_order(string_keys, k)
  elseif type(k) == 'number' then
   format_add_in_order(number_keys, k)
  else
   assert(false, "unexpected type as table key: " .. type(k))
  end
 end

 -- list string keys, then bool keys, then number keys
 local keys = string_keys
 if false_key then
  add(keys, false)
 end
 if true_key then
  add(keys, true)
 end
 for k in all(number_keys) do
  add(keys, k)
 end

 -- pretty-printing support
 local indent_space = ''
 local indent_newline = ''
 local indent_self = ''
 local indent_items = ''
 local recurse_indent
 if indent ~= nil then
  indent_space = ' '
  indent_newline = '\n'
  indent_self = format_repeat(' ', indent)
  indent_items = format_repeat(' ', indent + 1)
  recurse_indent = indent + 2
 end

 local s = '{' .. indent_newline
 for i, k in ipairs(keys) do
  s = s .. indent_items
  if type(k) == 'number'
    and k == flr(k)
    and k >= 1
    and k <= #t
  then
   -- use implicit key numbering and don't write the key
  else
   if type(k) == 'string' and format_is_id(k) then
    s = s .. k
   else
    s = s .. '[' .. format_toliteral(k) .. ']'
   end
   s = s .. indent_space .. '=' .. indent_space
  end
  s = s .. format_toliteral(t[k], recurse_indent)
  if indent ~= nil or i < #t then
   -- write a trailing comma
   s = s .. ','
  end
  s = s .. indent_newline
 end
 return s .. indent_self .. '}'
end
