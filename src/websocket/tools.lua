local bit = require'websocket.bit'
local mime = require'mime'
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

local read_n_bytes = function(str, pos, n)
  pos = pos or 1
  return pos+n, string.byte(str, pos, pos + n - 1)
end

local read_int8 = function(str, pos)
  return read_n_bytes(str, pos, 1)
end

local read_int16 = function(str, pos)
  local new_pos,a,b = read_n_bytes(str, pos, 2)
  return new_pos, lshift(a, 8) + b
end

local read_int32 = function(str, pos)
  local new_pos,a,b,c,d = read_n_bytes(str, pos, 4)
  return new_pos,
  lshift(a, 24) +
  lshift(b, 16) +
  lshift(c, 8 ) +
  d
end

local pack_bytes = string.char

local write_int8 = pack_bytes

local write_int16 = function(v)
  return pack_bytes(rshift(v, 8), band(v, 0xFF))
end

local write_int32 = function(v)
  return pack_bytes(
    band(rshift(v, 24), 0xFF),
    band(rshift(v, 16), 0xFF),
    band(rshift(v,  8), 0xFF),
    band(v, 0xFF)
  )
end

-- used for generate key random ops
math.randomseed(os.time())

-- SHA1 hashing from luacrypto, if available
local sha1_crypto
local done,crypto = pcall(require,'crypto')
if done then
  sha1_crypto = function(msg)
    return crypto.digest('sha1',msg,true)
  end
end

-- from wiki article, not particularly clever impl
local sha1_wiki = function(msg)
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
  msg = msg..write_int32(high)..write_int32(low)

  assert(#msg % 64 == 0,#msg % 64)

  for j=1,#msg,64 do
    local chunk = msg:sub(j,j+63)
    assert(#chunk==64,#chunk)
    local words = {}
    local next = 1
    local word
    repeat
      next,word = read_int32(chunk, next)
      tinsert(words, word)
    until next > 64
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

  return write_int32(h0)..write_int32(h1)..write_int32(h2)..write_int32(h3)..write_int32(h4)
end

local base64_encode = function(data)
  return (mime.b64(data))
end

local DEFAULT_PORTS = {ws = 80, wss = 443}

local parse_url = function(url)
  local protocol, address, uri = url:match('^(%w+)://([^/]+)(.*)$')
  if not protocol then error('Invalid URL:'..url) end
  protocol = protocol:lower()
  local host, port = address:match("^(.+):(%d+)$")
  if not host then
    host = address
    port = DEFAULT_PORTS[protocol]
  end
  if not uri or uri == '' then uri = '/' end
  return protocol, host, tonumber(port), uri
end

local generate_key = function()
  local r1 = mrandom(0,0xfffffff)
  local r2 = mrandom(0,0xfffffff)
  local r3 = mrandom(0,0xfffffff)
  local r4 = mrandom(0,0xfffffff)
  local key = write_int32(r1)..write_int32(r2)..write_int32(r3)..write_int32(r4)
  assert(#key==16,#key)
  return base64_encode(key)
end

return {
  sha1 = sha1_crypto or sha1_wiki,
  base64 = {
    encode = base64_encode
  },
  parse_url = parse_url,
  generate_key = generate_key,
  read_int8 = read_int8,
  read_int16 = read_int16,
  read_int32 = read_int32,
  write_int8 = write_int8,
  write_int16 = write_int16,
  write_int32 = write_int32,
}
