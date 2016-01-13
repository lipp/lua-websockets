
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
  
  self.broadcast = function(self,...)
    for client in pairs(clients[protocol]) do
      if client ~= self then
        client:send(...)
      end
    end
    self:send(...)
  end
  
  return self
end

local listen = function(opts)
  
  local copas = require'copas'
  assert(opts and (opts.protocols or opts.default))
  local on_error = opts.on_error or function(s) print(s) end
  local listener,err = socket.bind(opts.interface or '*',opts.port or 80)
  if err then
    error(err)
  end
  local protocols = {}
  if opts.protocols then
    for protocol in pairs(opts.protocols) do
      clients[protocol] = {}
      tinsert(protocols,protocol)
    end
  end
  -- true is the 'magic' index for the default handler
  clients[true] = {}
  copas.addserver(
    listener,
    function(sock)
      local request = {}
      repeat
        -- no timeout used, so should either return with line or err
        local line,err = copas.receive(sock,'*l')
        if line then
          request[#request+1] = line
        else
          sock:close()
          if on_error then
            on_error('invalid request')
          end
          return
        end
      until line == ''
      local upgrade_request = tconcat(request,'\r\n')
      local response,protocol = handshake.accept_upgrade(upgrade_request,protocols)
      if not response then
        copas.send(sock,protocol)
        sock:close()
        if on_error then
          on_error('invalid request')
        end
        return
      end
      copas.send(sock,response)
      local handler
      local new_client
      local protocol_index
      if protocol and opts.protocols[protocol] then
        protocol_index = protocol
        handler = opts.protocols[protocol]
      elseif opts.default then
        -- true is the 'magic' index for the default handler
        protocol_index = true
        handler = opts.default
      else
        sock:close()
        if on_error then
          on_error('bad protocol')
        end
        return
      end
      new_client = client(sock,protocol_index)
      clients[protocol_index][new_client] = true
      handler(new_client)
      -- this is a dirty trick for preventing
      -- copas from automatically and prematurely closing
      -- the socket
      while new_client.state ~= 'CLOSED' do
        local dummy = {
          send = function() end,
          close = function() end
        }
        copas.send(dummy)
      end
    end)
  local self = {}
  self.close = function(_,keep_clients)
    copas.removeserver(listener)
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
