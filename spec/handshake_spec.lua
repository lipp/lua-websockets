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

      it(
	 'can parse handshake header',
	 function()
	    local request = [[
GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Origin: http://example.com
Sec-WebSocket-Protocol: chat, superchat
Sec-WebSocket-Version: 13
	 ]]
	 local headers = handshake.http_headers(request)
	 assert.is_same(type(headers),'table')
	 assert.is_same('websocket','websocket')
	 assert.is_same(headers['upgrade'],'websocket')
	 assert.is_same(headers['connection'],'upgrade')
	 assert.is_same(headers['sec-websocket-key'],'dGhlIHNhbXBsZSBub25jZQ==')
	 assert.is_same(headers['sec-websocket-version'],'13')
	 end)
	 
	 
   end)