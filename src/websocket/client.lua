local socket = require'socket'
local sync = require'websocket.sync'
local tools = require'websocket.tools'

local new = function(ws)
  ws =  ws or {}
  local sock = socket.tcp()
  if ws.timeout ~= nil then
    sock:settimeout(ws.timeout)
  end
  local self = {}
  
  self.sock_connect = function(self,host,port)
    local _,err = sock:connect(host,port)
    if err then
      error(err)
    end
  end
  
  self.sock_send = function(self,...)
    return sock:send(...)
  end
  
  self.sock_receive = function(self,...)
    return sock:receive(...)
  end
  
  self.sock_close = function(self)
    sock:shutdown()
    sock:close()
  end
  
  self = sync.extend(self)
  
  return self
end


return {
  new = new,
  sync = new,
  ev = require'websocket.client_ev',
  copas = require'websocket.client_copas'
}
