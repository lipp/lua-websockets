local bit = {}

function bit.lshift(a,b)
  return a<<b
end
function bit.rshift(a,b)
  return a>>b
end
function bit.band(a,b)
  return a&b
end
function bit.bor(a,b)
  return a|b
end
function bit.bxor(a,b)
  return a~b
end

return bit
