package.path = package.path..'../src'

local client = require'websocket.client'

describe(
  'The client module',
  function()
    local wsc
    it(
      'exposes the correct interface',
      function()
        assert.is_same(type(client),'table')
        assert.is_same(type(client.new),'function')
        assert.is_equal(client.new,client.sync)
      end)
    
    it(
      'can be constructed',
      function()
        wsc = client.new
        {
          url = 'ws://localhost:8080',
          protocol = 'echo-protocol'
        }
      end)
    
    it(
      'can connect (requires external websocket server @port 8080)',
      function()
        assert.is_same(type(wsc.connect),'function')
        assert.has_no_error(function() wsc:connect() end)
      end)
    
    it(
      'can send (requires external websocket server @port 8080)',
      function()
        assert.is_same(type(wsc.send),'function')
        wsc:send('Hello again')
      end)
    
    it(
      'can receive (requires external websocket server @port 8080)',
      function()
        assert.is_same(type(wsc.receive),'function')
        local echoed = wsc:receive()
        assert.is_same(echoed,'Hello again')
      end)
    
    local random_text = function(len)
      local chars = {}
      for i=1,len do
        chars[i] = string.char(math.random(33,126))
      end
      return table.concat(chars)
    end
    
    it(
      'can send with payload 127 (requires external websocket server @port 8080)',
      function()
        local text = random_text(127)
        wsc:send(text)
        local echoed = wsc:receive()
        assert.is_same(text,echoed)
      end)
    
    it(
      'can send with payload 0xffff-1 (requires external websocket server @port 8080)',
      function()
        local text = random_text(0xffff-1)
        assert.is_same(#text,0xffff-1)
        wsc:send(text)
        local echoed = wsc:receive()
        assert.is_same(#text,#echoed)
        assert.is_same(text,echoed)
      end)
    
    it(
      'can send with payload 0xffff+1 (requires external websocket server @port 8080)',
      function()
        local text = random_text(0xffff+1)
        assert.is_same(#text,0xffff+1)
        wsc:send(text)
        local echoed = wsc:receive()
        assert.is_same(#text,#echoed)
        assert.is_same(text,echoed)
      end)
    
  end)
