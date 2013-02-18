local socket = require'socket'
local sync = require'websocket.sync'
local tools = require'websocket.tools'

local new = function(ws)
  local copas = require'copas'
  local protocol,host,port,uri = tools.parse_url(ws.url)
  if protocol ~= 'ws' then
    error('Protocol not supported:'..protocol)
  end
  local csock
  local sock = socket.tcp()
  if ws.timeout ~= nil then
    sock:settimeout(ws.timeout)
  end
  
  local self = {}
  
  self = sync.extend(self)
  
  self.connect = function(self)
    local _,err = copas.connect(sock,host,port)
    if err and err ~= 'already connected' then
      error('Websocket could not connect to '..ws.url)
    end
    ws.host = host
    ws.uri = uri
    self.sock = copas.wrap(sock)
    local ok,err = self:make_handshake(ws)
    self.connected = true
    return ok,err
  end
  
  local close = self.close
  self.close = function()
    close(self)
    sock:shutdown()
    sock:close()
  end
  
  return self
end

return new
