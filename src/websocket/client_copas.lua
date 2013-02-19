local socket = require'socket'
local sync = require'websocket.sync'
local tools = require'websocket.tools'

local new = function(ws)
  ws = ws or {}
  local copas = require'copas'
  local sock = socket.tcp()
  if ws.timeout ~= nil then
    sock:settimeout(ws.timeout)
  end
  
  local self = {}
  
  self.sock_connect = function(self,host,port)
    local _,err = copas.connect(sock,host,port)
    if err and err ~= 'already connected' then
      error('Websocket client could not connect to:'..host..':'..port)
    end
  end
  
  self.sock_send = function(self,...)
    return copas.send(sock,...)
  end
  
  self.sock_receive = function(self,...)
    return copas.receive(sock,...)
  end
  
  self.sock_close = function(self)
    sock:shutdown()
    sock:close()
  end
  
  self = sync.extend(self)
  
  return self
end

return new
