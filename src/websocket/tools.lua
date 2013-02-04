
require'pack'
local bit = require'bit'
local rol = bit.rol
local bxor = bit.bxor
local bor = bit.bor
local band = bit.band
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local spack = string.pack
local sunpack = string.unpack
local srep = string.rep
local schar = string.char
local tremove = table.remove

local sha1 = function(msg)

   local h0 = 0x67452301
   local h1 = 0xEFCDAB89
   local h2 = 0x98BADCFE
   local h3 = 0x10325476
   local h4 = 0xC3D2E1F0

   local bits = #msg * 8
   -- append a '1' bit plus seven '0' bits
   msg = msg..schar(0x80) 
   
   -- 64 bit length will be appended
   local bytes = #msg + 8 
   
   -- 512 bit append stuff
   local fill_bytes = 64 - (bytes % 64) 
   if fill_bytes ~= 64 then
      msg = msg..srep(schar(0),fill_bytes)
   end
   
   -- append 64 big endian length
   local high = math.floor(bits/2^32)
   local low = bits - high*2^32
   msg = msg..spack('>I>I',high,low)

   assert(#msg % 64 == 0,#msg % 64)

   for j=1,#msg,64 do
      local chunk = msg:sub(j,j+63)
      assert(#chunk==64,#chunk)
      local words = {sunpack(chunk,srep('>I',16))}
      -- index 1 contains fragment from unpack
      tremove(words,1)
      assert(#words==16)
      for i=17,80 do
         words[i] = bxor(words[i-3],words[i-8],words[i-14],words[i-16])
         words[i] = rol(words[i],1)
      end       
      local a = h0
      local b = h1
      local c = h2
      local d = h3
      local e = h4
 
      for i=1,80 do
         local k,f
         if i > 0 and i < 21 then              
            f = bor(band(b,c),band(bnot(b),d))
            k = 0x5A827999
         elseif i > 20 and i < 41 then
            f = bxor(b,c,d)
            k = 0x6ED9EBA1
         elseif i > 40 and i < 61 then
            f = bor(band(b,c),band(b,d),band(c,d))
            k = 0x8F1BBCDC
         elseif i > 60 and i < 81 then
            f = bxor(b,c,d)
            k = 0xCA62C1D6
         end
         
         local temp = rol(a,5) + f + e + k + words[i]
         e = d
         d = c
         c = rol(b,30)
         b = a
         a = temp
      end

      h0 = h0 + a
      h1 = h1 + b
      h2 = h2 + c
      h3 = h3 + d
      h4 = h4 + e
   end

   return spack('>I>I>I>I>I',h0,h1,h2,h3,h4)
end

local base64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local base64_encode = function(data)
   local result = ''
   local padding = ''
   local count = #data % 3

   if count > 0 then
      for i=count,2 do
         padding = padding..'='
         data = data..'\0'
      end
   end
   assert(#data % 3 == 0,#data % 3)
   local bytes = 0
   for i=1,#data,3 do      
      local chars = {data:sub(i,i+2):byte(1,3)}
      assert(#chars==3,#chars)
      local n = lshift(chars[1],16) + lshift(chars[2],8) + chars[3]
      local narr = {}
      narr[1] = band(rshift(n,18),63)+1
      narr[2] = band(rshift(n,12),63)+1
      narr[3] = band(rshift(n,6),63)+1
      narr[4] = band(n,63)+1
      result = result..base64chars:sub(narr[1],narr[1])
      result = result..base64chars:sub(narr[2],narr[2])
      result = result..base64chars:sub(narr[3],narr[3])
      result = result..base64chars:sub(narr[4],narr[4])
   end
   return result:sub(1,#result-#padding)..padding         
end

return {
   sha1 = sha1,
   base64 = {
      encode = base64_encode
   }
       }