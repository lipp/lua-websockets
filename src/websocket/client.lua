local socket = require'socket'
local sync = require'websocket.sync'
local tools = require'websocket.tools'

local new = function(ws)
  local protocol,host,port,uri = tools.parse_url(ws.url)
  if protocol ~= 'ws' then
    error('Protocol not supported:'..protocol)
  end
  local sock = socket.tcp()
  if ws.timeout ~= nil then
    sock:settimeout(ws.timeout)
  end
  local self = {}
  self.sock = sock
  
  self = sync.extend(self)
  
  self.connect = function(self)
    local _,err = sock:connect(host,port)
    if err then
      error('Websocket could not connect to '..ws.url..'('..host..','..port..')')
    end
    ws.host = host
    ws.uri = uri
    local ok,err = self:make_handshake(ws)
    self.connected = true
    return ok,err
  end
  
  return self
end


return {
  new = new,
  sync = new,
  ev = require'websocket.client_ev',
  copas = require'websocket.client_copas'
}
