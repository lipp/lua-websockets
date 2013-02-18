local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tools = require'websocket.tools'
local tinsert = table.insert
local tconcat = table.concat


local receive = function(self)
  if self.state ~= 'OPEN' and self.state ~= 'CLOSING' then
    error('Websocket not OPEN nor CLOSING')
  end
  local first_opcode
  local frames
  local bytes = 3
  local encoded = ''
  while true do
    local chunk,err = self.sock:receive(bytes)
    if err then
      error('Websocket receive failed:'..err)
    end
    encoded = encoded..chunk
    local decoded,fin,opcode,_,masked = frame.decode(encoded)
    if not self.is_server and masked then
      return nil,'Websocket receive failed: frame was not masked'
    end
    if decoded then
      if opcode == frame.CLOSE then
        if not self.state == 'CLOSING' then
          pcall(self.send,self,decoded,frame.CLOSE)
          self.state = 'CLOSED'
          return nil,'Websocket closed'
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
          return nil,'Websocket receive failed: opcode CONTINUATION expected'
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
    error('Websocket not OPEN')
  end
  local encoded = frame.encode(data,opcode or frame.TEXT,not self.is_server)
  local n,err = self.sock:send(encoded)
  if n ~= #encoded then
    error('Websocket client send failed:'..err)
  end
  return true
end

local close = function(self,code,reason)
  if self.state ~= 'OPEN' then
    return nil,'Websocket not OPEN'
  end
  local msg = frame.encode_close(code or 1000,reason)
  pcall(self.send,self,msg,frame.CLOSE)
  self.state = 'CLOSING'
  local ok,rmsg,opcode = pcall(self.receive,self)
  if ok then
    if rmsg:sub(1,2) == msg:sub(1,2) and opcode == frame.CLOSE then
      return true
    end
  end
  return nil,'Websocket client close handshake failed'
end

local make_handshake = function(self,context)
  local key = tools.generate_key()
  local req = handshake.upgrade_request
  {
    key = key,
    host = context.host,
    protocols = {context.protocol or ''},
    origin = context.origin,
    uri = context.uri
  }
  local n,err = self.sock:send(req)
  if n ~= #req then
    error('Websocket Handshake failed due to socket send err: '..err)
  end
  local resp = {}
  repeat
    local line,err = self.sock:receive('*l')
    resp[#resp+1] = line
    if err then
      error('Websocket Handshake failed due to socket receive err: '..err)
    end
  until line == ''
  local response = table.concat(resp,'\r\n')
  local headers = handshake.http_headers(response)
  local expected_accept = handshake.sec_websocket_accept(key)
  if headers['sec-websocket-accept'] ~= expected_accept then
    local msg = 'Websocket Handshake failed: Invalid Sec-Websocket-Accept (expected %s got %s)'
    error(msg:format(expected_accept,headers['sec-websocket-accept'] or 'nil'))
  end
  self.state = 'OPEN'
end

local extend = function(obj)
  obj.state = 'CONNECTING'
  obj.receive = receive
  obj.send = send
  obj.close = close
  obj.make_handshake = make_handshake
  return obj
end

return {
  extend = extend
}
