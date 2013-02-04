
require'pack'

local sha1 = require'websocket.tools'.sha1
local base64 = require'websocket.tools'.base64

local guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

local sec_websocket_accept = function(sec_websocket_key)
   local a = sec_websocket_key..guid
   local sha1 = sha1(a)
   assert((#sha1 % 2) == 0)
   return base64.encode(sha1)
end

local http_headers = function(request)
   local headers = {}
   if not request:match('GET /%w* HTTP/1%.1') then
      return 
   end
   request = request:match('[^\r\n]+\n(.*)')
   for line in request:gmatch('[^\r\n]+') do
      local name,val = line:match('([^%s]+)%s*:%s*([^%s%\n]+)')
      if not name then
	 return headers
      end
      name = name:lower()
      if not name:match('sec%-websocket') then
	 val = val:lower()
      end
      headers[name] = val
   end
end

local accept_upgrade = function(request)

end

return {
   sec_websocket_accept = sec_websocket_accept,
   http_headers = http_headers
       }