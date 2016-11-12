require'uloop'

uloop.init()

local server = require'websocket'.server.uloop
server.listen
{
  port = 8080,
  protocols = {
    echo = function(ws)
      local message = ws:receive()
      if message then
        ws:send(message)
      else
        ws:close()
        return
      end
	end
  },
  default = echo_handler
}

uloop.run()