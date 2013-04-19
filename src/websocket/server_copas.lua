
local socket = require'socket'
local copas = require'copas'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local sync = require'websocket.sync'
local tconcat = table.concat
local tinsert = table.insert

local clients = {}

local client = function(sock,protocol)
  local copas = require'copas'
  
  local self = {}
  
  self.state = 'OPEN'
  self.is_server = true
  
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
  
  self.on_close = function(self)
    clients[protocol][self] = nil
  end
  
  self.broadcast = function(_,...)
    for client in pairs(clients[protocol]) do
      client:send(...)
    end
  end
  
  return self
end

local listen = function(opts)
  local copas = require'copas'
  assert(opts and (opts.protocols or opts.default))
  local on_error = opts.on_error or function(s) print(s) end
  local listener = socket.bind(opts.interface or '*',opts.port or 80)
  local protocols = {}
  if opts.protocols then
    for protocol in pairs(opts.protocols) do
      clients[protocol] = {}
      tinsert(protocols,protocol)
    end
  end
  copas.addserver(
    listener,
    function(sock)
      local request = {}
      repeat
        local line,err,part = copas.receive(sock,'*l')
        if line then
          if last then
            line = last..line
            last = nil
          end
          request[#request+1] = line
        elseif err ~= 'timeout' then
          on_error('Websocket server Handshake failed due to copas receive err:'..err)
          sock:close()
          return
        else
          last = part
          return
        end
      until line == ''
      local upgrade_request = tconcat(request,'\r\n')
      local response,protocol = handshake.accept_upgrade(upgrade_request,protocols)
      copas.send(sock,response)
      if protocol and opts.protocols[protocol] then
        local new_client = client(sock,protocol)
        clients[protocol][new_client] = true
        opts.protocols[protocol](new_client)
      elseif opts.default then
        local new_client = client(sock)
        opts.default(new_client)
      else
        print('Unsupported protocol:',protocol or '"null"')
      end
    end)
  local self = {}
  self.close = function(keep_clients)
    listener:close()
    listener = nil
    if not keep_clients then
      for protocol,clients in pairs(clients) do
        for client in pairs(clients) do
          client:close()
        end
      end
    end
  end
  return self
end

return {
  listen = listen
}
