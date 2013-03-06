
local socket = require'socket'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tconcat = table.concat
local tinsert = table.insert
local ev
local loop

local clients = {}

local client = function(sock,protocol)
  assert(sock)
  sock:setoption('tcp-nodelay',true)
  local fd = sock:getfd()
  local message_io
  local on_message
  local on_error = function(s,err) print('Websocket server unhandled error with client instance',s,err) end
  local on_close = function() end
  local send_io
  local self = {}
  
  local async_send = require'websocket.ev_common'.async_send(sock,loop)
  
  self.send = function(_,message,opcode)
    local encoded = frame.encode(message,opcode or frame.TEXT)
    async_send(encoded)
  end
  
  local handle_sock_err = function(err)
    clients[protocol][self] = nil
    if err == 'closed' then
      on_close()
    else
      on_error(self,'Websocket message read io failed: '..err)
    end
  end
  
  local last
  local frames
  local first_opcode
  local message_io = require'websocket.ev_common'.message_io(
    sock,loop,
    function(...)
      if on_message then
        on_message(self,...)
      end
    end,
  handle_sock_err)
  
  self.on_close = function(_,on_close_arg)
    on_close = on_close_arg
  end
  
  self.on_error = function(_,on_error_arg)
    on_error = on_error_arg
  end
  
  self.on_message = function(_,on_message_arg)
    if not on_message and message_io then
      message_io:start(loop)
    end
    on_message = on_message_arg
  end
  
  self.broadcast = function(_,...)
    for client in pairs(clients[protocol]) do
      client:send(...)
    end
  end
  
  self.close = function()
    clients[protocol][self] = nil
    if message_io then
      message_io:stop(loop)
    end
    sock:shutdown()
    sock:close()
    sock = nil
  end
  return self
end

local listen = function(opts)
  assert(opts and (opts.protocols or opts.default))
  ev = require'ev'
  loop = opts.loop or ev.Loop.default
  local on_error = function(s,err) print('Websocket unhandled error',s,err) end
  local protocols = {}
  if opts.protocols then
    for protocol in pairs(opts.protocols) do
      clients[protocol] = {}
      tinsert(protocols,protocol)
    end
  end
  
  local listener,err = socket.bind(opts.interface or '*',opts.port or 80)
  assert(listener,err)
  listener:settimeout(0)
  listen_io = ev.IO.new(
    function()
      local client_sock = listener:accept()
      client_sock:settimeout(0)
      assert(client_sock)
      local request = {}
      ev.IO.new(
        function(loop,read_io)
          repeat
            local line,err,part = client_sock:receive('*l')
            if line then
              if last then
                line = last..line
                last = nil
              end
              request[#request+1] = line
            elseif err ~= 'timeout' then
              on_error(self,'Websocket Handshake failed due to socket err:'..err)
            else
              last = part
              return
            end
          until line == ''
          read_io:stop(loop)
          local upgrade_request = tconcat(request,'\r\n')
          local response,protocol = handshake.accept_upgrade(upgrade_request,protocols)
          if not response then
            print('Handshake failed, Request:')
            print(upgrade_request)
            client_sock:close()
            return
          end
          local index
          ev.IO.new(
            function(loop,write_io)
              local len = #response
              local sent,err = client_sock:send(response,index)
              if not sent then
                write_io:stop(loop)
                print('Websocket client closed while handshake',err)
              elseif sent == len then
                write_io:stop(loop)
                if protocol and opts.protocols[protocol] then
                  local new_client = client(client_sock,protocol)
                  clients[protocol][new_client] = true
                  opts.protocols[protocol](new_client)
                elseif opts.default then
                  local new_client = client(client_sock)
                  opts.default(new_client)
                else
                  print('Unsupported protocol:',protocol or '"null"')
                end
              else
                assert(sent < len)
                index = sent
              end
            end,client_sock:getfd(),ev.WRITE):start(loop)
        end,client_sock:getfd(),ev.READ):start(loop)
    end,listener:getfd(),ev.READ)
  local self = {}
  self.close = function(keep_clients)
    listen_io:stop(loop)
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
  listen_io:start(loop)
  return self
end

return {
  listen = listen
}
