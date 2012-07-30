--- lua websocket equivalent to test-server.c from libwebsockets.
-- using lua-ev event loop 
local ev = require'ev'
local websockets = require'websockets'
local file_dir = arg[1] or './'
local ws_ios = {}

local context 
context = websockets.context{
   port = 8002,
   on_add_fd = 
      function(fd)	
	 local io = ev.IO.new(
	    function(_,_,revents)
           -- specifically handle THIS fd with THIS revents               
	       context:service_fd(fd,revents)
           -- alternatively one could just service ALL fd with all possible
           -- outstanding revents
	       -- context:service(0)
	    end,fd,ev.READ)
	 ws_ios[fd] = io
	 io:start(ev.Loop.default)
      end,
   on_del_fd = 
      function(fd)
	 ws_ios[fd]:stop(ev.Loop.default)
	 ws_ios[fd] = nil
      end,
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

-- timer for peridically trigger broadcast
ev.Timer.new(
   function()
      context:broadcast('dumb-increment-protocol','x')
   end,
   0.1,0.1):start(ev.Loop.default)

ev.Loop.default:loop()

context:destroy()
