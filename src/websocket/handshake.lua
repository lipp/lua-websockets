local sha1 = require'websocket.tools'.sha1
local base64 = require'websocket.tools'.base64
local tinsert = table.insert

local guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

local sec_websocket_accept = function(sec_websocket_key)
  local a = sec_websocket_key..guid
  local sha1 = sha1(a)
  assert((#sha1 % 2) == 0)
  return base64.encode(sha1)
end

local http_headers = function(request)
  local headers = {}
  if not request:match('.*HTTP/1%.1') then
    return headers
  end
  request = request:match('[^\r\n]+\r\n(.*)')
  local empty_line
  for line in request:gmatch('[^\r\n]*\r\n') do
    local name,val = line:match('([^%s]+)%s*:%s*([^\r\n]+)')
    if name and val then
      name = name:lower()
      if not name:match('sec%-websocket') then
        val = val:lower()
      end
      if not headers[name] then
        headers[name] = val
      else
        headers[name] = headers[name]..','..val
      end
    elseif line == '\r\n' then
      empty_line = true
    else
      assert(false,line..'('..#line..')')
    end
  end
  return headers,request:match('\r\n\r\n(.*)')
end

local upgrade_request = function(req)
  local format = string.format
  local lines = {
    format('GET %s HTTP/1.1',req.uri or ''),
    format('Host: %s',req.host),
    'Upgrade: websocket',
    'Connection: Upgrade',
    format('Sec-WebSocket-Key: %s',req.key),
    format('Sec-WebSocket-Protocol: %s',table.concat(req.protocols,', ')),
    'Sec-WebSocket-Version: 13',
  }
  if req.origin then
    tinsert(lines,string.format('Origin: %s',req.origin))
  end
  if req.port and req.port ~= 80 then
    lines[2] = format('Host: %s:%d',req.host,req.port)
  end
  tinsert(lines,'\r\n')
  return table.concat(lines,'\r\n')
end

local accept_upgrade = function(request,protocols)
  local headers = http_headers(request)
  if headers['upgrade'] ~= 'websocket' or
  not headers['connection'] or
  not headers['connection']:match('upgrade') or
  headers['sec-websocket-key'] == nil or
  headers['sec-websocket-version'] ~= '13' then
    return nil,'HTTP/1.1 400 Bad Request\r\n\r\n'
  end
  local prot
  if headers['sec-websocket-protocol'] then
    for protocol in headers['sec-websocket-protocol']:gmatch('([^,%s]+)%s?,?') do
      for _,supported in ipairs(protocols) do
        if supported == protocol then
          prot = protocol
          break
        end
      end
      if prot then
        break
      end
    end
  end
  local lines = {
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: '..headers['connection'],
    string.format('Sec-WebSocket-Accept: %s',sec_websocket_accept(headers['sec-websocket-key'])),
  }
  if prot then
    tinsert(lines,string.format('Sec-WebSocket-Protocol: %s',prot))
  end
  tinsert(lines,'\r\n')
  return table.concat(lines,'\r\n'),prot
end

return {
  sec_websocket_accept = sec_websocket_accept,
  http_headers = http_headers,
  accept_upgrade = accept_upgrade,
  upgrade_request = upgrade_request,
}
