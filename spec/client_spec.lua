require'busted'
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

   end)