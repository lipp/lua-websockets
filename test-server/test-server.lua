local websockets = require'websockets'
local working_dir = arg[1] or './'
local close_testing
local log = print

local context 
context = websockets.context{
   port = 8002,
   on_http = 
      function(ws,uri)
	 if uri and uri == '/favicon.ico' then
	    ws:serve_http_file(working_dir..'favicon.ico','image/x-icon')
	 else
	    ws:serve_http_file(working_dir..'test.html','text/html')
	 end
      end,
   protocols = {
      ['dumb-increment-protocol'] = {
      	 on_established = 
   	    function(ws)
	       print(ws,ws:get_socket_fd())
   	       local number = 0
	       -- intercept broadcast and send custom content (as in test-server.c)
   	       ws:on_broadcast(
   		  function(ws)
   		     ws:write(tostring(number),websockets.WRITE_TEXT)
   		     number = number + 1
   		  end)
	       -- reset counter if requested
   	       ws:on_receive(
   		  function(ws,data)
   		     if data:match('reset') then
   			number = 0
   		     end
   		  end)
   	    end
      },
      ['lws-mirror-protocol'] = {
      	 on_established = 
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
}

while true do
   -- service outstanding io with timeout 200ms
   context:service(200)
   -- notify the 'dumb-increment-protocol' to update their counters
   context:broadcast('dumb-increment-protocol','x')
end

context:destroy()
