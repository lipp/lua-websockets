
local socket = require'socket'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local debug = require'debug'
local tconcat = table.concat
local tinsert = table.insert

local ev = function(ws)
  ws = ws or {}
  local ev = require'ev'
  local sock
  local loop = ws.loop or ev.Loop.default
  local fd
  local message_io
  local handshake_io
  local on_message
  local on_error = function(s,err) print('Websocket client unhandled error',s,err) end
  local on_close = function() end
  local on_open = function() end
  local self = {}
  local async_send
  
  local handle_socket_err = function(err)
    if err == 'closed' then
      on_close(self)
    else
      on_error(self,err)
    end
  end
  
  self.send = function(_,message,opcode)
    local encoded = frame.encode(message,opcode or frame.TEXT,true)
    async_send(encoded, nil, handle_socket_err)
  end
  
  local connect = function(_,params)
    local protocol,host,port,uri = tools.parse_url(params.url)
    if protocol ~= 'ws' then
      error('Protocol not supported:'..protocol)
    end
    assert(not sock)
    sock = socket.tcp()
    fd = sock:getfd()
    -- set non blocking
    sock:settimeout(0)
    sock:setoption('tcp-nodelay',true)
    async_send = require'websocket.ev_common'.async_send(sock,loop)
    on_open = params.on_open or on_open
    ev.IO.new(
      function(loop,connect_io)
        connect_io:stop(loop)
        local key = tools.generate_key()
        local req = handshake.upgrade_request
        {
          key = key,
          host = host,
          port = port,
          protocols = {params.protocol or ''},
          origin = ws.origin,
          uri = uri
        }
        async_send(
          req,
          function()
            local resp = {}
            local last
            handshake_io = ev.IO.new(
              function(loop,read_io)
                repeat
                  local line,err,part = sock:receive('*l')
                  if line then
                    if last then
                      line = last..line
                      last = nil
                    end
                    resp[#resp+1] = line
                  elseif err ~= 'timeout' then
                    read_io:stop(loop)
                    handle_socket_err(err)
                    return
                  else
                    last = part
                    return
                  end
                until line == ''
                read_io:stop(loop)
                local response = table.concat(resp,'\r\n')
                local headers = handshake.http_headers(response)
                local expected_accept = handshake.sec_websocket_accept(key)
                if headers['sec-websocket-accept'] ~= expected_accept then
                  local msg = 'Websocket Handshake failed: Invalid Sec-Websocket-Accept (expected %s got %s)'
                  msg = msg:format(expected_accept,headers['sec-websocket-accept'] or 'nil')
                  on_error(self,msg)
                  return
                end
                on_open(self)
                message_io = require'websocket.ev_common'.message_io(
                  sock,loop,
                  function(...)
                    if on_message then
                      on_message(self,...)
                    end
                  end,handle_socket_err)
                if on_message then
                  message_io:start(loop)
                end
              end,fd,ev.READ)
            handshake_io:start(loop)-- handshake
          end,
        handle_socket_err)
      end,fd,ev.WRITE):start(loop)-- connect
    local _,err = sock:connect(host,port)
    assert(_ == nil)
    if err ~= 'timeout' then
      error('Websocket could not connect to '..ws.url)
    end
  end
  
  self.on_close = function(_,on_close_arg)
    on_close = on_close_arg
  end
  
  self.on_error = function(_,on_error_arg)
    on_error = on_error_arg
  end
  
  self.on_open = function(_,on_open_arg)
    on_open = on_open_arg
  end
  
  self.on_message = function(_,on_message_arg)
    if not on_message and message_io then
      message_io:start(loop)
    end
    on_message = on_message_arg
  end
  
  self.close = function()
    if handshake_io then
      handshake_io:stop(loop)
    end
    if message_io then
      message_io:stop(loop)
    end
    sock:shutdown()
    sock:close()
    --    sock = nil
  end
  self.connect = connect
  return self
end

return ev
