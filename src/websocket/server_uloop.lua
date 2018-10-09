
local socket = require'socket'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local sync = require'websocket.sync'
require'uloop'
local tconcat = table.concat
local tinsert = table.insert

local clients = {}
local sock_clients = {}
local sock_events = {}

local client = function(sock,protocol)
  
  local self = {}
  
  self.state = 'OPEN'
  self.is_server = true
    
  self.sock_send = function(self,...)
    return sock:send(...)
  end
  
  self.sock_receive = function(self,...)
    return sock:receive(...)
  end
  
  self.sock_close = function(self)
    sock_clients[sock:getfd()] = nil
    sock_events[sock:getfd()]:delete()
    sock_events[sock:getfd()] = nil
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
  
  assert(opts and (opts.protocols or opts.default))
  local on_error = opts.on_error or function(s) print(s) end
  local listener = socket.tcp()
  listener:settimeout(0)
  listener:bind("*", opts.port or 80)
  listener:listen()

  local protocols = {}
  if opts.protocols then
    for protocol in pairs(opts.protocols) do
      clients[protocol] = {}
      tinsert(protocols,protocol)
    end
  end
  -- true is the 'magic' index for the default handler
  clients[true] = {}

  tcp_event = uloop.fd_add(listener, function(tfd, events)
    tfd:settimeout(3)
    local new_conn = assert(tfd:accept())
    if new_conn ~= nil then
      local request = {}
      repeat
        local line,err = new_conn:receive('*l')
        if line then
          request[#request+1] = line
        else
          new_conn:close()
          if on_error then
            on_error('invalid request')
          end
          return
        end
      until line == ''
      local upgrade_request = tconcat(request,'\r\n')
      local response,protocol = handshake.accept_upgrade(upgrade_request,protocols)
      if not response then
        new_conn:send(protocol)
        new_conn:close()
        if on_error then
          on_error('invalid request')
        end
        return
      end
      new_conn:send(response)
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
        new_conn:close()
        if on_error then
          on_error('bad protocol')
        end
        return
      end
      new_client = client(new_conn, protocol_index)
      sock_clients[new_conn:getfd()] = new_client
      clients[protocol_index][new_client] = true
      
      sock_events[new_conn:getfd()] = uloop.fd_add(new_conn, function(csocket, events)
        handler(sock_clients[csocket:getfd()])
      end, uloop.ULOOP_READ)
    end
  end, uloop.ULOOP_READ)

  local self = {}
  self.close = function(_,keep_clients)
    tcp_event:delete()
    tcp_event = nil
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
  listen = listen,
  clients = clients
}
