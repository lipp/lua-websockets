require'busted'
package.path = package.path..'../src'

local frame = require'websocket.frame'
require'pack'

local bytes = function(...)
   local args = {...}
   local format = string.rep('b',#args)
   return string.pack(format,...)
end

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
            local decoded,fin,opcode = frame.decode(hello_unmasked)
            assert.is_same(opcode,0x1)
            assert.is_true(fin)
            assert.is.same(decoded,'Hello')
         end)

      it(
         'RFC: decode a single-frame masked text message',
         function()
            local decoded,fin,opcode = frame.decode(hello_masked)
            assert.is_true(fin)
            assert.is_same(opcode,0x1)
            assert.is.same(decoded,'Hello')
         end)

      it(
         'RFC: decode a fragmented test message',
         function()
            local decoded,fin,opcode = frame.decode(hel)
            assert.is_falsy(fin)
            assert.is_same(opcode,0x1)
            assert.is.same(decoded,'Hel')

            decoded,fin,opcode = frame.decode(lo)
            assert.is_true(fin)
            assert.is_same(opcode,0x0)
            assert.is.same(decoded,'lo')
         end)


   end)