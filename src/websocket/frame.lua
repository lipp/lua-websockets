-- Following Websocket RFC: http://tools.ietf.org/html/rfc6455
local bit = require'websocket.bit'
local band = bit.band
local bxor = bit.bxor
local bor = bit.bor
local tremove = table.remove
local srep = string.rep
local ssub = string.sub
local sbyte = string.byte
local schar = string.char
local band = bit.band
local rshift = bit.rshift
local tinsert = table.insert
local tconcat = table.concat
local mmin = math.min
local mfloor = math.floor
local mrandom = math.random
local unpack = unpack or table.unpack
local tools = require'websocket.tools'
local write_int8 = tools.write_int8
local write_int16 = tools.write_int16
local write_int32 = tools.write_int32
local read_int8 = tools.read_int8
local read_int16 = tools.read_int16
local read_int32 = tools.read_int32

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

-- TODO: improve performance
local xor_mask = function(encoded,mask,payload)
  local transformed,transformed_arr = {},{}
  -- xor chunk-wise to prevent stack overflow.
  -- sbyte and schar multiple in/out values
  -- which require stack
  for p=1,payload,2000 do
    local last = mmin(p+1999,payload)
    local original = {sbyte(encoded,p,last)}
    for i=1,#original do
      local j = (i-1) % 4 + 1
      transformed[i] = bxor(original[i],mask[j])
    end
    local xored = schar(unpack(transformed,1,#original))
    tinsert(transformed_arr,xored)
  end
  return tconcat(transformed_arr)
end

local encode_header_small = function(header, payload)
  return schar(header, payload)
end

local encode_header_medium = function(header, payload, len)
  return schar(header, payload, band(rshift(len, 8), 0xFF), band(len, 0xFF))
end

local encode_header_big = function(header, payload, high, low)
  return schar(header, payload)..write_int32(high)..write_int32(low)
end

local encode = function(data,opcode,masked,fin)
  local header = opcode or 1-- TEXT is default opcode
  if fin == nil or fin == true then
    header = bor(header,bit_7)
  end
  local payload = 0
  if masked then
    payload = bor(payload,bit_7)
  end
  local len = #data
  local chunks = {}
  if len < 126 then
    payload = bor(payload,len)
    tinsert(chunks,encode_header_small(header,payload))
  elseif len <= 0xffff then
    payload = bor(payload,126)
    tinsert(chunks,encode_header_medium(header,payload,len))
  elseif len < 2^53 then
    local high = mfloor(len/2^32)
    local low = len - high*2^32
    payload = bor(payload,127)
    tinsert(chunks,encode_header_big(header,payload,high,low))
  end
  if not masked then
    tinsert(chunks,data)
  else
    local m1 = mrandom(0,0xff)
    local m2 = mrandom(0,0xff)
    local m3 = mrandom(0,0xff)
    local m4 = mrandom(0,0xff)
    local mask = {m1,m2,m3,m4}
    tinsert(chunks,write_int8(m1,m2,m3,m4))
    tinsert(chunks,xor_mask(data,mask,#data))
  end
  return tconcat(chunks)
end

local decode = function(encoded)
  local encoded_bak = encoded
  if #encoded < 2 then
    return nil,2-#encoded
  end
  local pos,header,payload
  pos,header = read_int8(encoded,1)
  pos,payload = read_int8(encoded,pos)
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
        return nil,2-#encoded
      end
      pos,payload = read_int16(encoded,1)
    elseif payload == 127 then
      if #encoded < 8 then
        return nil,8-#encoded
      end
      pos,high = read_int32(encoded,1)
      pos,low = read_int32(encoded,pos)
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
    local m1,m2,m3,m4
    pos,m1 = read_int8(encoded,1)
    pos,m2 = read_int8(encoded,pos)
    pos,m3 = read_int8(encoded,pos)
    pos,m4 = read_int8(encoded,pos)
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
    local data = write_int16(code)
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
      _,code = read_int16(data,1)
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
  encode_header_small = encode_header_small,
  encode_header_medium = encode_header_medium,
  encode_header_big = encode_header_big,
  CONTINUATION = 0,
  TEXT = 1,
  BINARY = 2,
  CLOSE = 8,
  PING = 9,
  PONG = 10
}
