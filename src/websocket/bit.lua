-- luajit / lua 5.1 + luabitop
local ok, bit = pcall(require, 'bit')
if not ok then
  -- lua 5.2 / bit32 library
  bit = require 'bit32'
  bit.rol = bit.lrotate
  bit.ror = bit.rrotate
end

return bit
