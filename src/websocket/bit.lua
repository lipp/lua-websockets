local has_bit32,bit = pcall(require,'bit32')
if has_bit32 then
  -- lua 5.2
  return bit
else
  -- luajit / lua 5.1 + luabitop
  return require'bit'
end
