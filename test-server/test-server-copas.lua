#!/usr/bin/env lua
--- lua websocket equivalent to test-server.c from libwebsockets.
-- using lua-copas copasent loop 
package.path = '../src/?.lua;../src/?/?.lua;'..package.path
local copas = require'copas'
local server = require'websocket'.server.copas.listen
{
   protocols = {
      ['lws-mirror-protocol'] = function(ws)
	 while true do
	    local msg = ws:receive()
	    ws:broadcast(msg)
	 end
      end,
      ['dumb-increment-protocol'] = function(ws)	       
	 local number = 0
	 
	 -- ws:on_message(
	 --    function(ws,message)
	 --       if message:match('reset') then
	 -- 	  number = 0
	 --       end
	 --    end)
	 -- ws:on_close(
	 --    function()
	 --       timer:stop(loop)
	 --    end)
      end
   },
   port = 12345
}

print('Open browser:')
print('file://'..io.popen('pwd'):read()..'/index.html')
copas.loop()

