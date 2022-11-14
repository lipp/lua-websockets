local has_bit33, bit = pcall(require,'bit32')
local support_bitwise = loadstring("__xxx = 1 << 1")

-- For Lua 5.3.5+, 5.4+
if support_bitwise then
  bit = require"./bitpoly"
  return bit
end

if has_bit32 then
  -- lua 5.2 / bit32 library
  bit.rol = bit.lrotate
  bit.ror = bit.rrotate
  return bit
else
  -- luajit / lua 5.1 + luabitop
  return require'bit'
end
