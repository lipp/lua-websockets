local copas = require'copas'

-- this callback is called, whenever a new client connects.
-- ws is a new websocket instance
local echo_handler = function(ws)
  while true do
    local message = ws:receive()
    if message then
      ws:send(message)
    else
      ws:close()
      return
    end
  end
end

-- create a copas webserver and start listening
local server = require'websocket'.server.copas.listen
{
  -- listen on port 8080
  port = 8080,
  -- the protocols field holds
  --   key: protocol name
  --   value: callback on new connection
  protocols = {
    -- this callback is called, whenever a new client connects.
    -- ws is a new websocket instance
    echo = echo_handler
  },
  default = echo_handler
}

-- use the copas loop
copas.loop()
