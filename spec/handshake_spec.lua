require'busted'
package.path = package.path..'../src'

local handshake = require'websocket.handshake'
require'pack'

describe(
   'The handshake module',
   function()
      it(
	 'RFC 1.3: calculate the correct accept sum',
	 function()
	    local sec_websocket_key = "dGhlIHNhbXBsZSBub25jZQ=="
	    local accept = handshake.sec_websocket_accept(sec_websocket_key)
	    assert.is_same(accept,"s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
	 end)
   end)