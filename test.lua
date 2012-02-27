local websockets = require'websockets'
local close_testing
local log = 
   function(...)
      print(...)
   end

local plog = 
   function(prefix)
      return function(...) log(prefix,...) end
   end

local context = websockets.context{
   port = 8001,
   protocols = {
      {
	 name = 'http-only',
	 on_add_fd = plog('add_fd'),
	 on_del_fd = plog('del_fd'),
	 on_connected = 
	    function(ws)
	       log('connected',ws)
	       ws:on_receive(
		  function(ws,data)
		     log('receive',data)
		     ws:write(data,websockets.WRITE_TEXT)
		  end
	       )
	       ws:on_closed(
		  function()
		     log('closed')
		  end
	       )
	    end
      }
   }
}

while true do
   context:service(100000)
end

context:destroy()
