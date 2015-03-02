local struct = require'struct'
local bit = require'websocket.bit'
local rol = bit.rol
local bxor = bit.bxor
local bor = bit.bor
local band = bit.band
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local sunpack = string.unpack
local srep = string.rep
local schar = string.char
local tremove = table.remove
local tinsert = table.insert
local tconcat = table.concat
local mrandom = math.random

local function prequire(m)
  local ok, err = pcall(require, m)
  if ok then return err, m end
  return nil, err
end

local function orequire(...)
  for _, name in ipairs{...} do
    local mod = prequire(name)
    if mod then return mod, name end
  end
end

local function vrequire(...)
  local m, n = orequire(...)
  if m then return m, n end
  error("Can not fine any of this modules: " .. table.concat({...}, "/"), 2)
end

-- used for generate key random ops
math.randomseed(os.time())

-- SHA1 hashing from luacrypto, ldigest if available
local shalib, name = orequire('crypto', 'sha1', 'digest')
local sha1_digest if name == 'sha1' then
  sha1_digest = function(str) return shalib.digest(str, true) end
elseif name == 'crypto' then
  sha1_digest = function(str) return shalib.digest('sha1', str, true) end
elseif name == 'digest' then
  if _G.sha1 and _G.sha1.digest then
    shalib = _G.sha1
    sha1_digest = function(str) return shalib.digest(str, true) end
  end
end
if not sha1_digest then
-- from wiki article, not particularly clever impl
sha1_digest = function(msg)
  local h0 = 0x67452301
  local h1 = 0xEFCDAB89
  local h2 = 0x98BADCFE
  local h3 = 0x10325476
  local h4 = 0xC3D2E1F0
  
  local bits = #msg * 8
  -- append b10000000
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
  msg = msg..struct.pack('>I>I',high,low)
  
  assert(#msg % 64 == 0,#msg % 64)
  
  for j=1,#msg,64 do
    local chunk = msg:sub(j,j+63)
    assert(#chunk==64,#chunk)
    local words = {struct.unpack(srep('>I',16),chunk)}
    -- last item contains the index in chunk where it stopped reading
    tremove(words,17)
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
  
  -- necessary on sizeof(int) == 32 machines
  h0 = band(h0,0xffffffff)
  h1 = band(h1,0xffffffff)
  h2 = band(h2,0xffffffff)
  h3 = band(h3,0xffffffff)
  h4 = band(h4,0xffffffff)
  
  return struct.pack('>i>i>i>i>i',h0,h1,h2,h3,h4)
end
end

local base, name = vrequire("base64", "mime", "basexx")

local base64 = {} if name == 'basexx' then
  base64.encode = function(str) return base.to_base64(str)   end
  base64.decode = function(str) return base.from_base64(str) end
elseif name == 'mime' then
  base64.encode = function(str) return base.b64(str)  end
  base64.decode = function(str) return base.ub64(str) end
elseif name == 'base64' then
  base64.encode = function(str) return base.encode(str)  end
  base64.decode = function(str) return base.decode(str) end
end

local parse_url = function(url)
  local protocol,host = url:match('^(%w+)://([^:/]+)')
  local port,uri = url:match('.+//[^:/]+:?(%d*)(.*)')
  if port and port ~= '' then
    port = tonumber(port)
  elseif protocol == 'ws' then
    port = 80
  end
  if not uri or uri == '' then
    uri = '/'
  end
  if not protocol or not host or not port or not uri then
    error('Invalid URL:'..url)
  end
  return protocol,host,port,uri
end

local generate_key = function()
  local r1 = mrandom(0,0xfffffff)
  local r2 = mrandom(0,0xfffffff)
  local r3 = mrandom(0,0xfffffff)
  local r4 = mrandom(0,0xfffffff)
  local key = struct.pack('IIII',r1,r2,r3,r4)
  assert(#key==16,#key)
  return base64.encode(key)
end

return {
  sha1 = sha1_digest,
  base64 = base64,
  parse_url = parse_url,
  generate_key = generate_key,
}
