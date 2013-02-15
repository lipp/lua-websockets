package.path = package.path..'../src'

local client = require'websocket.client'
local ev = require'ev'
local frame = require'websocket.frame'

setloop('ev')

describe(
  'The client (ev) module',
  function()
    local wsc
    it(
      'exposes the correct interface',
      function()
        assert.is_same(type(client),'table')
        assert.is_same(type(client.ev),'function')
      end)
    
    it(
      'can be constructed',
      function()
        wsc = client.ev
        {
          url = 'ws://localhost:8080',
          protocol = 'echo-protocol'
        }
      end)
    
    it(
      'can connect (requires external websocket server @port 8080)',
      async,
      function(done)
        wsc:on_connect(
          guard(
            function(ws)
              assert.is_equal(ws,wsc)
              done()
          end))
        wsc:connect()
      end)
    
    it(
      'can send and receive data(requires external websocket server @port 8080)',
      async,
      function(done)
        assert.is_same(type(wsc.send),'function')
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
      'can send and receive data 127 byte messages(requires external websocket server @port 8080)',
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
      'can send and receive data 0xffff-1 byte messages(requires external websocket server @port 8080)',
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
      'can send and receive data 0xffff+1 byte messages(requires external websocket server @port 8080)',
      async,
      function(done)
        local msg = random_text(0xffff+1)
        wsc:on_message(
          guard(
            function(ws,message,opcode)
              ws:close()
              assert.is_same(#msg,#message)
              assert.is_same(msg,message)
              assert.is_same(opcode,frame.TEXT)
              done()
          end))
        wsc:send(msg)
      end)
  end)
