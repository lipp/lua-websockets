local ev = require'ev'

-- this callback is called, whenever a new client connects.
-- ws is a new websocket instance
local echo_handler = function(ws)
  ws:on_message(function(ws,message)
      ws:send(message)
    end)
end

-- create a copas webserver and start listening
local server = require'websocket'.server.ev.listen
{
  -- listen on port 8080
  port = 8080,
  -- the protocols field holds
  --   key: protocol name
  --   value: callback on new connection
  protocols = {
    echo = echo_handler
  },
  default = echo_handler
}

-- use the lua-ev loop
ev.Loop.default:loop()
