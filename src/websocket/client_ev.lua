
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
  local send_io_stop
  local async_send
  local self = {}
  self.state = 'CLOSED'
  local close_timer
  local user_on_message
  local user_on_close
  local user_on_open
  local user_on_error
  local cleanup = function()
    if close_timer then
      close_timer:stop(loop)
      close_timer = nil
    end
    if handshake_io then
      handshake_io:stop(loop)
      handshake_io:clear_pending(loop)
      handshake_io = nil
    end
    if send_io_stop then
      send_io_stop()
      send_io_stop = nil
    end
    if message_io then
      message_io:stop(loop)
      message_io:clear_pending(loop)
      message_io = nil
    end
    if sock then
      sock:shutdown()
      sock:close()
      sock = nil
    end
  end

  local on_close = function(was_clean,code,reason)
    cleanup()
    self.state = 'CLOSED'
    if user_on_close then
      user_on_close(self,was_clean,code,reason or '')
    end
  end
  local on_error = function(err,dont_cleanup)
    if not dont_cleanup then
      cleanup()
    end
    if user_on_error then
      user_on_error(self,err)
    else
      print('Error',err)
    end
  end
  local on_open = function()
    self.state = 'OPEN'
    if user_on_open then
      user_on_open(self)
    end
  end
  local handle_socket_err = function(err,io,sock)
    if self.state == 'OPEN' then
      on_close(false,1006,err)
    elseif self.state ~= 'CLOSED' then
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
        on_close(true,1005,'')
      end
    end
  end

  self.send = function(_,message,opcode)
    local encoded = frame.encode(message,opcode or frame.TEXT,true)
    async_send(encoded, nil, handle_socket_err)
  end

  self.connect = function(_,url,ws_protocol)
    if self.state ~= 'CLOSED' then
      on_error('wrong state',true)
      return
    end
    local protocol,host,port,uri = tools.parse_url(url)
    if protocol ~= 'ws' then
      on_error('bad protocol')
      return
    end
    local ws_protocols_tbl = {''}
    if type(ws_protocol) == 'string' then
        ws_protocols_tbl = {ws_protocol}
    elseif type(ws_protocol) == 'table' then
        ws_protocols_tbl = ws_protocol
    end
    self.state = 'CONNECTING'
    assert(not sock)
    sock = socket.tcp()
    fd = sock:getfd()
    assert(fd > -1)
    -- set non blocking
    sock:settimeout(0)
    sock:setoption('tcp-nodelay',true)
    async_send,send_io_stop = require'websocket.ev_common'.async_send(sock,loop)
    handshake_io = ev.IO.new(
      function(loop,connect_io)
        connect_io:stop(loop)
        local key = tools.generate_key()
        local req = handshake.upgrade_request
        {
          key = key,
          host = host,
          port = port,
          protocols = ws_protocols_tbl,
          origin = ws.origin,
          uri = uri
        }
        async_send(
          req,
          function()
            local resp = {}
            local response = ''
            local read_upgrade = function(loop,read_io)
              -- this seems to be possible, i don't understand why though :(
              if not sock then
                read_io:stop(loop)
                handshake_io = nil
                return
              end
              repeat
                local byte,err,pp = sock:receive(1)
                if byte then
                  response = response..byte
                elseif err then
                  if err == 'timeout' then
                    return
                  else
                    read_io:stop(loop)
                    on_error('accept failed')
                    return
                  end
                end
              until response:sub(#response-3) == '\r\n\r\n'
              read_io:stop(loop)
              handshake_io = nil
              local headers = handshake.http_headers(response)
              local expected_accept = handshake.sec_websocket_accept(key)
              if headers['sec-websocket-accept'] ~= expected_accept then
                self.state = 'CLOSED'
                on_error('accept failed')
                return
              end
              message_io = require'websocket.ev_common'.message_io(
                sock,loop,
                on_message,
              handle_socket_err)
              on_open(self)
            end
            handshake_io = ev.IO.new(read_upgrade,fd,ev.READ)
            handshake_io:start(loop)-- handshake
          end,
        handle_socket_err)
      end,fd,ev.WRITE)
    local connected,err = sock:connect(host,port)
    if connected then
      handshake_io:callback()(loop,handshake_io)
    elseif err == 'timeout' or err == 'Operation already in progress' then
      handshake_io:start(loop)-- connect
    else
      self.state = 'CLOSED'
      on_error(err)
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
    if handshake_io then
      handshake_io:stop(loop)
      handshake_io:clear_pending(loop)
    end
    if self.state == 'CONNECTING' then
      self.state = 'CLOSING'
      on_close(false,1006,'')
      return
    elseif self.state == 'OPEN' then
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

  return self
end

return ev
