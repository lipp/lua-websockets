--- lua websocket equivalent to test-server.c from libwebsockets.
-- using build in 'event' loop
local websockets = require'websockets'
local file_dir = arg[1] or './'

local context 
context = websockets.context{
   port = 8002,
   on_http = 
      function(ws,uri)
	 if uri and uri == '/favicon.ico' then
	    ws:serve_http_file(file_dir..'favicon.ico','image/x-icon')
	 else
	    ws:serve_http_file(file_dir..'test.html','text/html')
	 end
      end,
   protocols = {
      ['dumb-increment-protocol'] =
         function(ws)
            print(ws,ws:get_socket_fd())
            local number = 0
            -- intercept broadcast and send custom content (as in test-server.c)
            ws:on_broadcast(
               function(ws)
                  ws:write(number,websockets.WRITE_TEXT)
                  number = number + 1
               end)
            -- reset counter if requested
            ws:on_receive(
               function(ws,data)
                  if data:match('reset') then
                     number = 0
                  end
               end)
         end,
      ['lws-mirror-protocol'] =
         function(ws)
            -- forward broadcast with type WRITE_TEXT
            ws:on_broadcast(websockets.WRITE_TEXT)
            ws:on_receive(
      	       function(ws,data)
      		  ws:broadcast(data)
      	       end)
         end
      
   }
}

print(context,context:canonical_hostname())

while true do
   -- service outstanding io with timeout 100ms
   context:service(100)
   -- notify the 'dumb-increment-protocol' to update their counters
   context:broadcast('dumb-increment-protocol','x')
end

context:destroy()
