package.path = package.path..'../src'

local client = require'websocket.client'
local ev = require'ev'
local frame = require'websocket.frame'
local port = os.getenv('LUAWS_WSTEST_PORT') or 8081

local url = 'ws://localhost:'..port

setloop('ev')

describe(
  'The client (ev) module',
  function()
    local wsc
    it(
      'exposes the correct interface',
      function()
        assert.is_table(client)
        assert.is_function(client.ev)
      end)
    
    it(
      'can be constructed',
      function()
        wsc = client.ev()
      end)
    
    it(
      'can connect (requires external websocket server @port 8081)',
      async,
      function(done)
        wsc:on_open(
          guard(
            function(ws)
              assert.is_equal(ws,wsc)
              done()
          end))
        wsc:connect
        {
          url = url,
          protocol = 'echo-protocol'
        }
      end)
    
    it(
      'can send and receive data(requires external websocket server @port 8081)',
      async,
      function(done)
        assert.is_function(wsc.send)
        wsc:on_message(
          guard(
            function(ws,message,opcode)
              assert.is_equal(ws,wsc)
              assert.is_same(message,'Hello again')
              assert.is_same(opcode,frame.TEXT)
              done()
          end))
        wsc:send('Hello again')
      end)
    
    local random_text = function(len)
      local chars = {}
      for i=1,len do
        chars[i] = string.char(math.random(33,126))
      end
      return table.concat(chars)
    end
    
    it(
      'can send and receive data 127 byte messages(requires external websocket server @port 8081)',
      async,
      function(done)
        local msg = random_text(127)
        wsc:on_message(
          guard(
            function(ws,message,opcode)
              assert.is_same(#msg,#message)
              assert.is_same(msg,message)
              assert.is_same(opcode,frame.TEXT)
              done()
          end))
        wsc:send(msg)
      end)
    
    it(
      'can send and receive data 0xffff-1 byte messages(requires external websocket server @port 8081)',
      async,
      function(done)
        local msg = random_text(0xffff-1)
        wsc:on_message(
          guard(
            function(ws,message,opcode)
              assert.is_same(#msg,#message)
              assert.is_same(msg,message)
              assert.is_same(opcode,frame.TEXT)
              done()
          end))
        wsc:send(msg)
      end)
    
    it(
      'can send and receive data 0xffff+1 byte messages(requires external websocket server @port 8081)',
      async,
      function(done)
        local msg = random_text(0xffff+1)
        wsc:on_message(
          guard(
            function(ws,message,opcode)
              assert.is_same(#msg,#message)
              assert.is_same(msg,message)
              assert.is_same(opcode,frame.TEXT)
              done()
          end))
        wsc:send(msg)
      end)
    
    it(
      'closes nicely',
      async,
      function(done)
        wsc:on_close(guard(function(_,was_clean,code,reason)
              assert.is_true(was_clean)
              assert.is_true(code >= 1000)
              assert.is_string(reason)
              done()
          end))
        wsc:close()
      end)
  end)
