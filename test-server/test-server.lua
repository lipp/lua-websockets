local websockets = require'websockets'
local working_dir = arg[1] or './'
local close_testing
local log = print

local context = websockets.context{
   port = 8001,
   on_http = 
      function(ws,uri)
	 log('serving HTTP URI',uri)
	 if uri and uri == '/favicon.ico' then
	    ws:serve_http_file(working_dir..'favicon.ico','image/x-icon')
	 else
	    ws:serve_http_file(working_dir..'test.html','text/html')
	 end
      end,
   protocols = {
      {
   	 name = 'dumb-increment-protocol',
   	 on_add_fd = print,
   	 on_del_fd = print,
   	 on_established = 
   	    function(ws)
   	       local number = 0
   	       ws:on_broadcast(
   		  function(ws)
   		     ws:write(tostring(number),websockets.WRITE_TEXT)
   		     number = number + 1
   		  end
   	       )
   	       ws:on_receive(
   		  function(data)
   		     if data and data == 'reset' then
   			number = 0
   		     end
   		  end
   	       )
   	    end
      }
   }
}

while true do
   context:service(20)
end

context:destroy()
