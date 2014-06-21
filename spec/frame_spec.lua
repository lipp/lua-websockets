package.path = package.path..'../src'

local frame = require'websocket.frame'

local bytes = string.char

-- from rfc doc
local hello_unmasked = bytes(0x81,0x05,0x48,0x65,0x6c,0x6c,0x6f)
local hello_masked = bytes(0x81,0x85,0x37,0xfa,0x21,0x3d,0x7f,0x9f,0x4d,0x51,0x58)
local hel = bytes(0x01,0x03,0x48,0x65,0x6c)
local lo = bytes(0x80,0x02,0x6c,0x6f)

describe(
  'The frame module',
  function()
    it(
      'exposes a table',
      function()
        assert.is_same(type(frame),'table')
      end)
    
    it(
      'provides a decode and a encode function',
      function()
        assert.is.same(type(frame.encode),'function')
        assert.is.same(type(frame.decode),'function')
        assert.is.same(type(frame.encode_close),'function')
        assert.is.same(type(frame.decode_close),'function')
      end)
    
    it(
      'provides correct OPCODES',
      function()
        assert.is.same(frame.CONTINUATION,0)
        assert.is.same(frame.TEXT,1)
        assert.is.same(frame.BINARY,2)
        assert.is.same(frame.CLOSE,8)
        assert.is.same(frame.PING,9)
        assert.is.same(frame.PONG,10)
      end)
    
    
    it(
      'RFC: decode a single-frame unmasked text message',
      function()
        local decoded,fin,opcode,rest,masked = frame.decode(hello_unmasked..'foo')
        assert.is_same(opcode,0x1)
        assert.is_true(fin)
        assert.is.same(decoded,'Hello')
        assert.is_same(rest,'foo')
        assert.is_false(masked)
      end)
    
    it(
      'RFC: decode a single-frame unmasked text message bytewise and check min length',
      function()
        for i=1,#hello_unmasked do
          local sub = hello_unmasked:sub(1,i)
          local decoded,fin,opcode,rest,masked = frame.decode(sub)
          if i ~= #hello_unmasked then
            assert.is_same(decoded,nil)
            assert.is_same(type(fin),'number')
            assert.is_truthy(i+fin <= #hello_unmasked)
          else
            assert.is_same(opcode,0x1)
            assert.is_true(fin)
            assert.is.same(decoded,'Hello')
            assert.is_same(rest,'')
            assert.is_false(masked)
          end
        end
      end)
    
    it(
      'RFC: decode a single-frame masked text message',
      function()
        local decoded,fin,opcode,rest,masked = frame.decode(hello_masked..'foo')
        assert.is_true(fin)
        assert.is_same(opcode,0x1)
        assert.is.same(decoded,'Hello')
        assert.is_same(rest,'foo')
        assert.is_truthy(masked)
      end)
    
    it(
      'RFC: decode a fragmented test message',
      function()
        local decoded,fin,opcode,rest,masked = frame.decode(hel)
        assert.is_falsy(fin)
        assert.is_same(opcode,0x1)
        assert.is.same(decoded,'Hel')
        assert.is_same(rest,'')
        assert.is_falsy(masked)
        
        decoded,fin,opcode,rest,masked = frame.decode(lo)
        assert.is_true(fin)
        assert.is_same(opcode,0x0)
        assert.is.same(decoded,'lo')
        assert.is_same(rest,'')
        assert.is_falsy(masked)
      end)
    
    it(
      'refuse incomplete unmasked frame',
      function()
        local decoded,fin,opcode = frame.decode(hello_unmasked:sub(1,4))
        assert.is_falsy(decoded)
        assert.is_same(fin,#hello_unmasked-4)
        assert.is_falsy(opcode)
      end)
    
    it(
      'refuse incomplete masked frame',
      function()
        local decoded,fin,opcode = frame.decode(hello_masked:sub(1,4))
        assert.is_falsy(decoded)
        assert.is_same(fin,#hello_masked-4)
        assert.is_falsy(opcode)
      end)
    
    it(
      'encode single-frame unmasked text',
      function()
        local encoded = frame.encode('Hello')
        assert.is_same(encoded,hello_unmasked)
        local encoded = frame.encode('Hello',frame.TEXT)
        assert.is_same(encoded,hello_unmasked)
        local encoded = frame.encode('Hello',frame.TEXT,false)
        assert.is_same(encoded,hello_unmasked)
        local encoded = frame.encode('Hello',frame.TEXT,false,true)
        assert.is_same(encoded,hello_unmasked)
        local decoded,fin,opcode,_,masked = frame.decode(encoded)
        assert.is_same('Hello',decoded)
        assert.is_true(fin)
        assert.is_same(opcode,frame.TEXT)
        assert.is_falsy(masked)
      end)
    
    local random_text = function(len)
      local chars = {}
      for i=1,len do
        chars[i] = string.char(math.random(33,126))
      end
      return table.concat(chars)
    end
    
    it(
      'encode and decode single-frame of length 127 unmasked text',
      function()
        local len = 127
        local text = random_text(len)
        assert.is_same(#text,len)
        local encoded = frame.encode(text)
        local decoded,fin,opcode,rest,masked = frame.decode(encoded)
        assert.is_same(text,decoded)
        assert.is_same(#text,len)
        assert.is_true(fin)
        assert.is_same(opcode,frame.TEXT)
        assert.is_same(rest,'')
        assert.is_falsy(masked)
      end)
    
    it(
      'encode and decode single-frame of length 0xffff-1 unmasked text',
      function()
        local len = 0xffff-1
        local text = random_text(len)
        assert.is_same(#text,len)
        local encoded = frame.encode(text)
        local decoded,fin,opcode,rest,masked = frame.decode(encoded)
        assert.is_same(text,decoded)
        assert.is_same(#text,len)
        assert.is_true(fin)
        assert.is_same(opcode,frame.TEXT)
        assert.is_same(rest,'')
        assert.is_falsy(masked)
      end)
    
    it(
      'encode and decode single-frame of length 0xffff+1 unmasked text',
      function()
        local len = 0xffff+1
        local text = random_text(len)
        assert.is_same(#text,len)
        local encoded = frame.encode(text)
        local decoded,fin,opcode = frame.decode(encoded)
        assert.is_same(text,decoded)
        assert.is_same(#text,len)
        assert.is_true(fin)
        assert.is_same(opcode,frame.TEXT)
      end)
    
    it(
      'encode single-frame masked text',
      function()
        local encoded = frame.encode('Hello',frame.TEXT,true)
        local decoded,fin,opcode,rest,masked = frame.decode(encoded)
        assert.is_same('Hello',decoded)
        assert.is_true(fin)
        assert.is_same(opcode,frame.TEXT)
        assert.is_same(rest,'')
        assert.is_truthy(masked)
      end)
    
    it(
      'encode fragmented unmasked text',
      function()
        local hel = frame.encode('Hel',frame.TEXT,false,false)
        local decoded,fin,opcode = frame.decode(hel)
        assert.is_falsy(fin)
        assert.is_same(opcode,0x1)
        assert.is.same(decoded,'Hel')
        
        local lo = frame.encode('lo',frame.CONTINUATION,false)
        decoded,fin,opcode = frame.decode(lo)
        assert.is_true(fin)
        assert.is_same(opcode,0x0)
        assert.is.same(decoded,'lo')
      end)
    
    it(
      'encodes and decodes close packet correctly',
      function()
        local reason = 'foobar'
        local code = 0xfff1
        local close_frame = frame.encode_close(code,reason)
        assert.is_same(#close_frame,2+#reason)
        local dcode,dreason = frame.decode_close(close_frame)
        assert.is_same(dcode,code)
        assert.is_same(dreason,reason)
      end)
    
  end)
