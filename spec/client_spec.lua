require'busted'
package.path = package.path..'../src'

local client = require'websocket.client'

describe(
   'The client module',
   function()           
      it(
	 'exposes the correct interface',
	 function()
	    assert.is_same(type(client),'table')
	    assert.is_same(type(client.new),'function')
	 end)

      it(
	 'can be constructed',
	 function()
	    local wsc = client.new
	    {
	       url = 'ws://localhost:8080',
	       protocol = 'echo-protocol'
	    }
	 end)

   end)