
local socket = require'socket'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tconcat = table.concat
local tinsert = table.insert

local ev = function(ws)
  local ev = require'ev'
  local protocol,host,port,uri = tools.parse_url(ws.url)
  if protocol ~= 'ws' then
    error('Protocol not supported:'..protocol)
  end
  local sock
  local loop = ws.loop or ev.Loop.default
  local fd
  local message_io
  local on_message
  local on_error = function(s,err) print('Websocket client unhandled error',s,err) end
  local on_close = function() end
  local on_connect = function() end
  local self = {}
  
  local send_buffer
  send = function(data,on_sent)
    if send_buffer then
      -- a write io is still running
      send_buffer = send_buffer..data
      return
    else
      send_buffer = data
    end
    local index
    ev.IO.new(
      function(loop,write_io)
        local len = #send_buffer
        local sent,err = sock:send(send_buffer,index)
        if not sent then
          write_io:stop(loop)
          if err == 'closed' then
            on_close(self)
          end
          on_error(self,'Websocket write failed '..err)
        elseif sent == len then
          send_buffer = nil
          write_io:stop(loop)
          if on_sent then
            on_sent()
          end
        else
          assert(sent < len)
          index = sent
        end
      end,fd,ev.WRITE):start(loop)
  end
  
  self.send = function(_,message,opcode)
    local encoded = frame.encode(message,opcode or frame.TEXT,true)
    send(encoded)
  end
  
  local connect = function(_,on_connect_arg)
    assert(not sock)
    sock = socket.tcp()
    fd = sock:getfd()
    -- set non blocking
    sock:settimeout(0)
    sock:setoption('tcp-nodelay',true)
    on_connect = on_connect_arg or on_connect
    ev.IO.new(
      function(loop,connect_io)
        connect_io:stop(loop)
        local key = tools.generate_key()
        local req = handshake.upgrade_request
        {
          key = key,
          host = host,
          protocols = {ws.protocol or ''},
          origin = ws.origin,
          uri = uri
        }
        send(
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
                    on_error(self,'Websocket Handshake failed due to socket err:'..err)
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
                on_connect(self)
                local last
                local frames = {}
                local first_opcode
                message_io = ev.IO.new(
                  function(loop,message_io)
                    local encoded,err,part = sock:receive(100000)
                    if err and err ~= 'timeout' then
                      on_error(self,'Websocket  message read io failed: '..err)
                      self:close()
                      return
                    else
                      if last then
                        encoded = last..(encoded or part)
                      else
                        encoded = encoded or part
                      end
                    end
                    
                    repeat
                      local decoded,fin,opcode,rest = frame.decode(encoded)
                      if decoded then
                        if not first_opcode then
                          first_opcode = opcode
                        end
                        tinsert(frames,decoded)
                        encoded = rest
                      end
                      if fin == true then
                        on_message(self,tconcat(frames),first_opcode)
                        frames = {}
                        first_opcode = nil
                      end
                    until not decoded
                    last = encoded
                  end,fd,ev.READ)
                if on_message then
                  message_io:start(loop)
                end
              end,fd,ev.READ)
            handshake_io:start(loop)-- handshake
          end)
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
  
  self.on_connect = function(_,on_connect_arg)
    on_connect = on_connect_arg
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
    sock = nil
  end
  self.connect = connect
  return self
end

return ev
