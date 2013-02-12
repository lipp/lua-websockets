#!/usr/bin/env lua
--- lua websocket equivalent to test-server.c from libwebsockets.
-- using lua-copas copasent loop 
package.path = '../src/?.lua;../src/?/?.lua;'..package.path
local copas = require'copas'
local socket = require'socket'

local inc_clients = {}

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
         local inc_client = {
            number = 0,
            ws = ws
         }
         table.insert(inc_clients,inc_client)
         while true do            
            local message = ws:receive()            
            if message:match('reset') then
               inc_client.number = 0
            end
         end
      end
   },
   port = 12345
}

copas.addthread(
   function()
      local last = socket.gettime()
      while true do             
         copas.step(0.1)
         local now = socket.gettime()
         if (now - last) >= 0.1 then
            last = now
            for _,inc_client in pairs(inc_clients) do
               inc_client.number = inc_client.number + 1
               inc_client.ws:send(tostring(inc_client.number))
            end
         end
      end
   end)

print('Open browser:')
print('file://'..io.popen('pwd'):read()..'/index.html')

copas.loop()
