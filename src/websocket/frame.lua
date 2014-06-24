-- Following Websocket RFC: http://tools.ietf.org/html/rfc6455
local struct = require'struct'
local bit = require'websocket.bit'
local band = bit.band
local bxor = bit.bxor
local bor = bit.bor
local tremove = table.remove
local srep = string.rep
local ssub = string.sub
local sbyte = string.byte
local schar = string.char
local tinsert = table.insert
local tconcat = table.concat
local mmin = math.min
local strpack = struct.pack
local strunpack = struct.unpack
local mfloor = math.floor
local mrandom = math.random

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

local xor_mask = function(encoded,mask,payload)
  local transformed_arr = {}
  -- xor chunk-wise to prevent stack overflow.
  -- sbyte and schar multiple in/out values
  -- which require stack
  for p=1,payload,2000 do
    local transformed = {}
    local last = mmin(p+1999,payload)
    local original = {sbyte(encoded,p,last)}
    for i=1,#original do
      local j = (i-1) % 4 + 1
      transformed[i] = band(bxor(original[i],mask[j]), 0xFF)
    end
    local xored = schar(unpack(transformed))
    tinsert(transformed_arr,xored)
  end
  return tconcat(transformed_arr)
end

local encode = function(data,opcode,masked,fin)
  local encoded
  local header = opcode or 1-- TEXT is default opcode
  if fin == nil or fin == true then
    header = bor(header,bit_7)
  end
  local payload = 0
  if masked then
    payload = bor(payload,bit_7)
  end
  local len = #data
  if len < 126 then
    payload = bor(payload,len)
    encoded = strpack('bb',header,payload)
  elseif len < 0xffff then
    payload = bor(payload,126)
    encoded = strpack('bb>H',header,payload,len)
  elseif len < 2^53 then
    local high = mfloor(len/2^32)
    local low = len - high*2^32
    payload = bor(payload,127)
    encoded = strpack('bb>I>I',header,payload,high,low)
  end
  if not masked then
    encoded = encoded..data
  else
    local m1 = mrandom(0,0xff)
    local m2 = mrandom(0,0xff)
    local m3 = mrandom(0,0xff)
    local m4 = mrandom(0,0xff)
    local mask = {m1,m2,m3,m4}
    encoded = tconcat({
        encoded,
        strpack('bbbb',m1,m2,m3,m4),
        xor_mask(data,mask,#data)
    })
  end
  return encoded
end

local decode = function(encoded)
  local encoded_bak = encoded
  if #encoded < 2 then
    return nil,2
  end
  local header,payload,pos = struct.unpack('bb',encoded)
  local high,low
  encoded = ssub(encoded,pos)
  local bytes = 2
  local fin = band(header,bit_7) > 0
  local opcode = band(header,bit_0_3)
  local mask = band(payload,bit_7) > 0
  payload = band(payload,bit_0_6)
  if payload > 125 then
    if payload == 126 then
      if #encoded < 2 then
        return nil,2
      end
      payload,pos = struct.unpack('>H',encoded)
    elseif payload == 127 then
      if #encoded < 8 then
        return nil,8
      end
      high,low,pos = struct.unpack('>I>I',encoded)
      payload = high*2^32 + low
      if payload < 0xffff or payload > 2^53 then
        assert(false,'INVALID PAYLOAD '..payload)
      end
    else
      assert(false,'INVALID PAYLOAD '..payload)
    end
    encoded = ssub(encoded,pos)
    bytes = bytes + pos - 1
  end
  local decoded
  if mask then
    local bytes_short = payload + 4 - #encoded
    if bytes_short > 0 then
      return nil,bytes_short
    end
    local m1,m2,m3,m4,pos = struct.unpack('bbbb',encoded)
    encoded = ssub(encoded,pos)
    local mask = {
      m1,m2,m3,m4
    }
    decoded = xor_mask(encoded,mask,payload)
    bytes = bytes + 4 + payload
  else
    local bytes_short = payload - #encoded
    if bytes_short > 0 then
      return nil,bytes_short
    end
    if #encoded > payload then
      decoded = ssub(encoded,1,payload)
    else
      decoded = encoded
    end
    bytes = bytes + payload
  end
  return decoded,fin,opcode,encoded_bak:sub(bytes+1),mask
end

local encode_close = function(code,reason)
  if code then
    local data = struct.pack('>H',code)
    if reason then
      data = data..tostring(reason)
    end
    return data
  end
  return ''
end

local decode_close = function(data)
  local _,code,reason
  if data then
    if #data > 1 then
      code = struct.unpack('>H',data)
    end
    if #data > 2 then
      reason = data:sub(3)
    end
  end
  return code,reason
end

return {
  encode = encode,
  decode = decode,
  encode_close = encode_close,
  decode_close = decode_close,
  CONTINUATION = 0,
  TEXT = 1,
  BINARY = 2,
  CLOSE = 8,
  PING = 9,
  PONG = 10
}
