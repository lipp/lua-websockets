local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tools = require'websocket.tools'
local tinsert = table.insert
local tconcat = table.concat

local clean = function(self, was_clean,code,reason)
  self.state = 'CLOSED'
  self:sock_close()
  if self.on_close then
    self:on_close()
  end
  return nil,nil,was_clean,code,reason or 'closed'
end

local receive_init = function(self)
  self.first_opcode = nil
  self.frames = nil
  self.bytes = 3
  self.encoded = ''
end

local poll = function(self)
  if self.state ~= 'OPEN' and not self.is_closing then
    receive_init(self)
    return nil,nil,false,1006,'wrong state'
  end

  local chunk,err = self:sock_receive(self.bytes)
  if err and err ~= 'timeout' then
    receive_init(self)
    return clean(self, false,1006,err)
  end
  self.encoded = self.encoded..(chunk or '')
  local decoded,fin,opcode,_,masked = frame.decode(self.encoded)
  if not self.is_server and masked then
    receive_init(self)
    return clean(self, false,1006,'Websocket receive failed: frame was not masked')
  end
  if decoded then
    if opcode == frame.CLOSE then
      if not self.is_closing then
        local code,reason = frame.decode_close(decoded)
        -- echo code
        local msg = frame.encode_close(code)
        local encoded = frame.encode(msg,frame.CLOSE,not self.is_server)
        local n,err = self:sock_send(encoded)
        receive_init(self)
        if n == #encoded then
          return clean(self, true,code,reason)
        else
          return clean(self, false,code,err)
        end
      else
        receive_init(self)
        return decoded,opcode
      end
    end
    if not self.first_opcode then
      self.first_opcode = opcode
    end
    if not fin then
      if not self.frames then
        self.frames = {}
      elseif opcode ~= frame.CONTINUATION then
        receive_init(self)
        return clean(self, false,1002,'protocol error')
      end
      self.bytes = 3
      self.encoded = ''
      tinsert(self.frames,decoded)
    elseif not self.frames then
      receive_init(self)
      return decoded,self.first_opcode
    else
      tinsert(self.frames,decoded)
      receive_init(self)
      return tconcat(self.frames),self.first_opcode
    end
  else
    assert(type(fin) == 'number' and fin > 0)
    self.bytes = fin
  end
end

local send = function(self,data,opcode)
  if self.state ~= 'OPEN' then
    return nil,false,1006,'wrong state'
  end
  local encoded = frame.encode(data,opcode or frame.TEXT,not self.is_server)
  local n,err = self:sock_send(encoded)
  if n ~= #encoded then
    return nil,self:close(1006,err)
  end
  return true
end

local close = function(self,code,reason)
  if self.state ~= 'OPEN' then
    return false,1006,'wrong state'
  end
  if self.state == 'CLOSED' then
    return false,1006,'wrong state'
  end
  local msg = frame.encode_close(code or 1000,reason)
  local encoded = frame.encode(msg,frame.CLOSE,not self.is_server)
  local n,err = self:sock_send(encoded)
  local was_clean = false
  local code = 1005
  local reason = ''
  if n == #encoded then
    self.is_closing = true
    local rmsg,opcode = self:receive()
    if rmsg and opcode == frame.CLOSE then
      code,reason = frame.decode_close(rmsg)
      was_clean = true
    end
  else
    reason = err
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
  local ws_protocols_tbl = {''}
  if type(ws_protocol) == 'string' then
      ws_protocols_tbl = {ws_protocol}
  elseif type(ws_protocol) == 'table' then
      ws_protocols_tbl = ws_protocol
  end
  local key = tools.generate_key()
  local req = handshake.upgrade_request
  {
    key = key,
    host = host,
    port = port,
    protocols = ws_protocols_tbl,
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

  assert(obj.is_closing == nil)
  assert(obj.receive    == nil)
  assert(obj.send       == nil)
  assert(obj.close      == nil)
  assert(obj.connect    == nil)

  if not obj.is_server then
    assert(obj.sock_connect)
  end

  if not obj.state then
    obj.state = 'CLOSED'
  end

  obj.poll = poll
  obj.send = send
  obj.close = close
  obj.connect = connect

  receive_init(obj)

  return obj
end

return {
  extend = extend
}
