
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
  local async_send
  local self = {}
  self.state = 'CLOSED'
  local close_timer
  local user_on_message
  local user_on_close
  local user_on_open
  local user_on_error
  local on_error = function(s,err) print('Websocket client unhandled error',s,err) end
  local on_close = function(was_clean,code,reason)
    if close_timer then
      close_timer:stop(loop)
      close_timer = nil
    end
    if message_io then
      message_io:stop(loop)
    end
    self.state = 'CLOSED'
    if user_on_close then
      user_on_close(self,was_clean,code,reason or '')
    end
    sock:shutdown()
    sock:close()
  end
  local on_open = function()
    self.state = 'OPEN'
    if user_on_open then
      user_on_open(self)
    end
  end
  local handle_socket_err = function(err)
    if err == 'closed' then
      if self.state ~= 'CLOSED' then
        on_close(false,1006,'')
      end
    else
      on_error(err)
    end
  end
  local on_message = function(message,opcode)
    if opcode == frame.TEXT or opcode == frame.BINARY then
      if user_on_message then
        user_on_message(self,message,opcode)
      end
    elseif opcode == frame.CLOSE then
      if self.state ~= 'CLOSING' then
        self.state = 'CLOSING'
        local code,reason = frame.decode_close(message)
        local encoded = frame.encode_close(code)
        encoded = frame.encode(encoded,frame.CLOSE,true)
        async_send(encoded,
          function()
            on_close(true,code or 1005,reason)
          end,handle_socket_err)
      else
        on_close(true,code or 1005,reason)
      end
    end
  end
  
  self.send = function(_,message,opcode)
    local encoded = frame.encode(message,opcode or frame.TEXT,true)
    async_send(encoded, nil, handle_socket_error)
  end
  
  local connect = function(_,params)
    if self.state ~= 'CLOSED' then
      error('wrong state')
    end
    self.state = 'CONNECTING'
    local protocol,host,port,uri = tools.parse_url(params.url)
    if protocol ~= 'ws' then
      error('Protocol not supported:'..protocol)
    end
    assert(not sock)
    sock = socket.tcp()
    fd = sock:getfd()
    assert(fd > -1)
    -- set non blocking
    sock:settimeout(0)
    sock:setoption('tcp-nodelay',true)
    async_send = require'websocket.ev_common'.async_send(sock,loop)
    user_on_open = params.on_open or user_on_open
    
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
            assert(sock:getfd() > -1)
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
                handshake_io = nil
                local response = table.concat(resp,'\r\n')
                local headers = handshake.http_headers(response)
                local expected_accept = handshake.sec_websocket_accept(key)
                if headers['sec-websocket-accept'] ~= expected_accept then
                  local msg = 'Websocket Handshake failed: Invalid Sec-Websocket-Accept (expected %s got %s)'
                  msg = msg:format(expected_accept,headers['sec-websocket-accept'] or 'nil')
                  on_error(self,msg)
                  return
                end
                message_io = require'websocket.ev_common'.message_io(
                  sock,loop,
                  on_message,
                handle_socket_err)
                on_open(self)
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
    user_on_close = on_close_arg
  end
  
  self.on_error = function(_,on_error_arg)
    user_on_error = on_error_arg
  end
  
  self.on_open = function(_,on_open_arg)
    user_on_open = on_open_arg
  end
  
  self.on_message = function(_,on_message_arg)
    user_on_message = on_message_arg
  end
  
  self.close = function(_,code,reason,timeout)
    if self.state == 'CONNECTING' then
      self.state = 'CLOSING'
      assert(handshake_io)
      assert(not message_io)
      handshake_io:stop(loop)
      handshake_io = nil
      on_close(false,1006,'not open')
      return
    elseif self.state == 'OPEN' then
      assert(not handshake_io)
      assert(message_io)
      self.state = 'CLOSING'
      timeout = timeout or 3
      local encoded = frame.encode_close(code or 1000,reason)
      encoded = frame.encode(encoded,frame.CLOSE,true)
      -- this should let the other peer confirm the CLOSE message
      -- by 'echoing' the message.
      async_send(encoded)
      close_timer = ev.Timer.new(function()
          close_timer = nil
          on_close(false,1006,'timeout')
        end,timeout)
      close_timer:start(loop)
    end
  end
  self.connect = connect
  return self
end

return ev
