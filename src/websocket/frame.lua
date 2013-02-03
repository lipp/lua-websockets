require'pack'
local bit = require'bit'
local band = bit.band
local bxor = bit.bxor
local sunpack = string.unpack
local tremove = table.remove
local spack = string.pack

local encode = function()
end
local bits = function(...)
   local n = 0
   for _,bitn in pairs{...} do
      n = n + 2^bitn
   end
   return n
end
local bit_7 = bits(7)
local bit_0_3 = bits(0,1,2,3)
local bit_0_6 = bits(0,1,2,3,4,5,6)

local decode_masked = function(encoded,payload)
   local pos,m1,m2,m3,m4 = sunpack(encoded,'bbbb')
   encoded = encoded:sub(pos,#encoded)
   local mask = {
      m1,m2,m3,m4
   }
   local transformed = {}
   local format = string.rep('b',payload)
   local original = {sunpack(encoded,format)}
   tremove(original,1)
   for i=1,#original do
      local j = (i-1) % 4 + 1
      transformed[i] = bxor(original[i],mask[j])
   end
   return spack(format,unpack(transformed))
end

local decode = function(encoded)
   local pos,header,payload = sunpack(encoded,'bb')
   encoded = encoded:sub(pos,#encoded)
   local fin = band(header,bit_7) > 0
   local opcode = band(header,bit_0_3)
   local mask = band(payload,bit_7) > 0
   payload = band(payload,bit_0_6)
   local decoded
   if mask then
      decoded = decode_masked(encoded,payload)
   else
      decoded = encoded
   end
   return decoded,fin,opcode
end

return {
   encode = encode,
   decode = decode,
   CONTINUATION = 0,
   TEXT = 1,
   BINARY = 2,
   CLOSE = 8,
   PING = 9,
   PONG = 10
       }