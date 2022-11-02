local socket = require'socket'
local poller = require 'websocket.poller'

local new = function(ws)
  ws =  ws or {}
  local self = {}
  
  self.sock_connect = function(self,host,port)
    self.sock = socket.tcp()
    if ws.timeout ~= nil then
      self.sock:settimeout(ws.timeout)
    end
    local _,err = self.sock:connect(host,port)
    if err then
      self.sock:close()
      return nil,err
    end
    self.sock:settimeout(0)
  end
  
  self.sock_send = function(self,...)
    return self.sock:send(...)
  end
  
  self.sock_receive = function(self,...)
    return self.sock:receive(...)
  end
  
  self.sock_close = function(self)
    self.sock:shutdown()
    self.sock:close()
  end
  
  self = poller.extend(self)
  return self
end

return new
