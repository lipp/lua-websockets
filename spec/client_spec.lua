package.path = package.path..'../src'

local port = os.getenv('LUAWS_WSTEST_PORT') or 8081
local url = 'ws://localhost:'..port

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
        wsc = client.new()
      end)
    
    it(
      'can connect (requires external websocket server)',
      function()
        assert.is_same(type(wsc.connect),'function')
        wsc:connect(url,'echo-protocol')
      end)
    
    it(
      'throws on invalid protocol',
      function()
        local c = client.new()
        assert.has_error(
          function()
            c:connect('wsc://localhost:8081','echo-protocol')
          end,'bad protocol')
      end)
    
    it(
      'throws socket errors',
      function()
        local c = client.new()
        assert.has_error(
          function()
            c:connect('ws://localhost:8009','echo-protocol')
          end,'connection refused')
        local c = client.new()
        assert.has_error(
          function()
            c:connect('ws://horst','echo-protocol')
          end,'host not found')
      end)
    
    it(
      'throws when sending in non-open state (requires external websocket server @port 8081)',
      function()
        local c = client.new()
        assert.has_error(
          function()
            c:send('bla')
          end,'not open')
        
        local c = client.new()
        c:connect(url,'echo-protocol')
        c:close()
        assert.has_error(
          function()
            c:send('bla')
          end,'not open')
      end)
    
    it(
      'throws when connecting twice (requires external websocket server @port 8081)',
      function()
        local c = client.new()
        c:connect(url,'echo-protocol')
        assert.has_error(
          function()
            c:connect(url,'echo-protocol')
          end,'already connected')
      end)
    
    it(
      'can send (requires external websocket server @port 8081)',
      function()
        assert.is_same(type(wsc.send),'function')
        wsc:send('Hello again')
      end)
    
    it(
      'can receive (requires external websocket server @port 8081)',
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
      'can send with payload 127 (requires external websocket server @port 8081)',
      function()
        local text = random_text(127)
        wsc:send(text)
        local echoed = wsc:receive()
        assert.is_same(text,echoed)
      end)
    
    it(
      'can send with payload 0xffff-1 (requires external websocket server @port 8081)',
      function()
        local text = random_text(0xffff-1)
        assert.is_same(#text,0xffff-1)
        wsc:send(text)
        local echoed = wsc:receive()
        assert.is_same(#text,#echoed)
        assert.is_same(text,echoed)
      end)
    
    it(
      'can send with payload 0xffff+1 (requires external websocket server @port 8081)',
      function()
        local text = random_text(0xffff+1)
        assert.is_same(#text,0xffff+1)
        wsc:send(text)
        local echoed = wsc:receive()
        assert.is_same(#text,#echoed)
        assert.is_same(text,echoed)
      end)
    
    it(
      'can close cleanly (requires external websocket server @port 8081)',
      function()
        assert.is_true(wsc:close())
      end)
    
  end)
