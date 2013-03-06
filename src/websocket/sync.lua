local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tools = require'websocket.tools'
local tinsert = table.insert
local tconcat = table.concat


local receive = function(self)
  if self.state ~= 'OPEN' and self.state ~= 'CLOSING' then
    error('Websocket not OPEN nor CLOSING (state='..(self.state or 'nil')..')')
  end
  local first_opcode
  local frames
  local bytes = 3
  local encoded = ''
  while true do
    local chunk,err = self:sock_receive(bytes)
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
        if self.state ~= 'CLOSING' then
          pcall(self.send,self,decoded,frame.CLOSE)
          self.state = 'CLOSED'
          return nil,'closed'
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
          tinsert(frames,decoded)
          return nil,'protocol',tconcat(frames),first_opcode,opcode
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
    error('not open')
  end
  local encoded = frame.encode(data,opcode or frame.TEXT,not self.is_server)
  local n,err = self:sock_send(encoded)
  if n ~= #encoded then
    error('Websocket client send failed:'..err)
  end
  return true
end

local close = function(self,code,reason)
  if self.state ~= 'OPEN' then
    return nil,'state'
  end
  local msg = frame.encode_close(code or 1000,reason)
  pcall(self.send,self,msg,frame.CLOSE)
  self.state = 'CLOSING'
  local ok,rmsg,opcode = pcall(self.receive,self)
  self:sock_close()
  if ok and rmsg then
    if rmsg:sub(1,2) == msg:sub(1,2) and opcode == frame.CLOSE then
      return true
    end
  end
  return nil,'protocol'
end

local connect = function(self,ws_url,ws_protocol)
  if self.state == 'OPEN' then
    error('already connected')
  end
  local protocol,host,port,uri = tools.parse_url(ws_url)
  if protocol ~= 'ws' then
    error('bad protocol')
  end
  self:sock_connect(host,port)
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
    error('Websocket Handshake failed due to socket send err: '..err)
  end
  local resp = {}
  repeat
    local line,err = self:sock_receive('*l')
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
