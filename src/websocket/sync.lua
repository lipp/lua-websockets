local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tools = require'websocket.tools'
local tinsert = table.insert
local tconcat = table.concat


local receive = function(self)
  if self.state ~= 'OPEN' and not self.is_closing then
    return nil,'wrong state'
  end
  local first_opcode
  local frames
  local bytes = 3
  local encoded = ''
  local clean = function(was_clean,code,reason)
    self.state = 'CLOSED'
    self:sock_close()
    if self.on_close then
      self:on_close()
    end
    return nil,was_clean,code,reason or 'closed'
  end
  while true do
    local chunk,err = self:sock_receive(bytes)
    if err then
      return clean(false,1006,err)
    end
    encoded = encoded..chunk
    local decoded,fin,opcode,_,masked = frame.decode(encoded)
    if not self.is_server and masked then
      return clean(false,1006,'Websocket receive failed: frame was not masked')
    end
    if decoded then
      if opcode == frame.CLOSE then
        if not self.is_closing then
          local code,reason = frame.decode_close(decoded)
          -- echo code
          local msg = frame.encode_close(code)
          local encoded = frame.encode(msg,frame.CLOSE,not self.is_server)
          local n,err = self:sock_send(encoded)
          if n == #encoded then
            return clean(true,code,reason)
          else
            return clean(false,code,err)
          end
        else
          return decoded,opcode
        end
      end
      if not first_opcode then
        first_opcode = opcode
      end
      if not fin then
        if not frames then
          frames = {}
        elseif opcode ~= frame.CONTINUATION then
          return clean(false,1002,'protocol error')
        end
        bytes = 3
        encoded = ''
        tinsert(frames,decoded)
      elseif not frames then
        return decoded,first_opcode
      else
        tinsert(frames,decoded)
        return tconcat(frames),first_opcode
      end
    else
      assert(type(fin) == 'number' and fin > 0)
      bytes = fin
    end
  end
end

local send = function(self,data,opcode)
  if self.state ~= 'OPEN' then
    return nil,'wrong state'
  end
  local encoded = frame.encode(data,opcode or frame.TEXT,not self.is_server)
  local n,err = self:sock_send(encoded)
  if n ~= #encoded then
    return self:close(1006,err)
  end
  return true
end

local close = function(self,code,reason)
  if self.state ~= 'OPEN' then
    return nil,'wrong state'
  end
  if self.state == 'CLOSED' then
    return nil,'wrong state'
  end
  local msg = frame.encode_close(code or 1000,reason)
  local encoded = frame.encode(msg,frame.CLOSE,not self.is_server)
  local n,err = self:sock_send(encoded)
  local was_clean = false
  local code = 1006
  local reason = ''
  if n == #encoded then
    self.is_closing = true
    local rmsg,opcode = self:receive()
    if rmsg and opcode == frame.CLOSE then
      code,reason = frame.decode_close(rmsg)
      was_clean = true
    end
  end
  self:sock_close()
  if self.on_close then
    self:on_close()
  end
  self.state = 'CLOSED'
  return was_clean,code,reason or ''
end

local connect = function(self,ws_url,ws_protocol)
  if self.state ~= 'CLOSED' then
    return nil,'wrong state'
  end
  local protocol,host,port,uri = tools.parse_url(ws_url)
  if protocol ~= 'ws' then
    return nil,'bad protocol'
  end
  local _,err = self:sock_connect(host,port)
  if err then
    return nil,err
  end
  local key = tools.generate_key()
  local req = handshake.upgrade_request
  {
    key = key,
    host = host,
    port = port,
    protocols = {ws_protocol or ''},
    origin = origin,
    uri = uri
  }
  local n,err = self:sock_send(req)
  if n ~= #req then
    return nil,err
  end
  local resp = {}
  repeat
    local line,err = self:sock_receive('*l')
    resp[#resp+1] = line
    if err then
      return nil,err
    end
  until line == ''
  local response = table.concat(resp,'\r\n')
  local headers = handshake.http_headers(response)
  local expected_accept = handshake.sec_websocket_accept(key)
  if headers['sec-websocket-accept'] ~= expected_accept then
    local msg = 'Websocket Handshake failed: Invalid Sec-Websocket-Accept (expected %s got %s)'
    return nil,msg:format(expected_accept,headers['sec-websocket-accept'] or 'nil')
  end
  self.state = 'OPEN'
  return true
end

local extend = function(obj)
  assert(obj.sock_send)
  assert(obj.sock_receive)
  assert(obj.sock_close)
  obj.receive = receive
  obj.send = send
  obj.close = close
  obj.connect = connect
  return obj
end

return {
  extend = extend
}
