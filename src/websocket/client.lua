local socket = require'socket'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tinsert = table.insert
local tconcat = table.concat

local sync = function(ws)
  local protocol,host,port,uri = tools.parse_url(ws.url)
  if protocol ~= 'ws' then
    error('Protocol not supported:'..protocol)
  end
  local sock = socket.tcp()
  if ws.timeout ~= nil then
    sock:settimeout(ws.timeout)
  end
  
  local connect = function(self)
    local _,err = sock:connect(host,port)
    if err then
      error('Websocket could not connect to '..ws.url)
    end
    local key = tools.generate_key()
    local req = handshake.upgrade_request
    {
      key = key,
      host = host,
      protocols = {ws.protocol or ''},
      origin = ws.origin,
      uri = uri
    }
    sock:send(req)
    local resp = {}
    repeat
      local line,err = sock:receive('*l')
      resp[#resp+1] = line
      if err then
        error('Websocket Handshake failed due to socket err:'..err)
      end
    until line == ''
    local response = table.concat(resp,'\r\n')
    local headers = handshake.http_headers(response)
    local expected_accept = handshake.sec_websocket_accept(key)
    if headers['sec-websocket-accept'] ~= expected_accept then
      local msg = 'Websocket Handshake failed: Invalid Sec-Websocket-Accept (expected %s got %s)'
      error(msg:format(expected_accept,headers['sec-websocket-accept'] or 'nil'))
    end
    self.connected = true
  end
  
  local send = function(self,data,opcode)
    if not self.connected then
      error('Websocket client send failed: not connected')
    end
    local encoded = frame.encode(data,opcode or frame.TEXT,true)
    local n,err = sock:send(encoded)
    if n ~= #encoded then
      error('Websocket client send failed:'..err)
    end
  end
  
  local receive = function(self)
    if not self.connected then
      error('Websocket client send failed: not connected')
    end
    return tools.receive_sync(sock)
  end
  
  local self = {
    connect = connect,
    send = send,
    receive = receive
  }
  
  return self
end


return {
  new = sync,
  sync = sync,
  ev = require'websocket.client_ev',
  copas = require'websocket.client_copas'
}
