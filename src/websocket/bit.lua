local has_bit32,bit = pcall(require,'bit32')
if has_bit32 then
  -- lua 5.2
  bit.rol = bit32.lrotate
  bit.ror = bit32.rrotate
  return bit
else
  -- luajit / lua 5.1 + luabitop
  return require'bit'
end
