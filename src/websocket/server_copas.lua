
local socket = require'socket'
local copas = require'copas'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tconcat = table.concat
local tinsert = table.insert

local clients = {}

local client = function(sock,protocol)
   local copas = require'copas'
   local self = {}

   self.send = function(self,data,opcode)
      local encoded = frame.encode(data,opcode or frame.TEXT,true)
      local n,err = copas.send(sock,encoded)
      if n ~= #encoded then
	 error('Websocket server send failed:'..err)
      end
   end
   
   self.receive = function(self)
      local frames
      while true do
         local header,err = copas.receive(sock,3)
         if err then
            error('Websocket client receive failed:'..err)
         end
         local _,left = frame.decode(header)
         assert(_ == nil)
         assert(left > 0)
         local encoded,err = copas.receive(sock,left)
         encoded = header..encoded
         if err then
            error('Websocket client receive failed:'..err)
         end
         local decoded,fin = frame.decode(encoded)
         assert(decoded)
         if not fin then
            frames = frames or {}
            tinsert(frames,decoded)
         elseif not frames then
            return decoded
         else
            return tconcat(frames)
         end
      end
   end

   self.broadcast = function(_,...)
      for client in pairs(clients[protocol]) do
	 client:send(...)
      end
   end

   self.close = function()
      clients[protocol][self] = nil
      sock:shutdown()
      sock:close()
      sock = nil
   end

   return self
end

local listen = function(opts)
   local copas = require'copas'
   assert(opts and (opts.protocols or opts.default))
   local on_error = opts.on_error or function(s,err) print('Websocket unhandled error',s,err) end
   local listener = socket.bind(opts.interface or '*',opts.port or 80)
   local protocols = {}
   if opts.protocols then
      for protocol in pairs(opts.protocols) do
	 clients[protocol] = {}
         tinsert(protocols,protocol)
      end
   end
   copas.addserver(
      listener,
      function(sock)
         local request = {}
	 repeat
	    local line,err,part = copas.receive(sock,'*l')
	    if line then
	       if last then
		  line = last..line
		  last = nil
	       end
	       request[#request+1] = line
	    elseif err ~= 'timeout' then
	       on_error(self,'Websocket Handshake failed due to socket err:'..err)
	       sock:close()
	       return
	    else
	       last = part
	       return
	    end
	 until line == ''
	 local upgrade_request = tconcat(request,'\r\n')
	 local response,protocol = handshake.accept_upgrade(upgrade_request,protocols)
	 copas.send(sock,response)
	 if protocol and opts.protocols[protocol] then
	    local new_client = client(sock,protocol)
	    clients[protocol][new_client] = true
	    opts.protocols[protocol](new_client)
	 elseif opts.default then
	    local new_client = client(sock)
	    opts.default(new_client)
	 else
	    print('Unsupported protocol:',protocol or '"null"')
	 end	 
      end)
   local self = {}
   self.close = function(keep_clients)
      listener:close()
      listener = nil
      if not keep_clients then
	 for protocol,clients in pairs(clients) do
	    for client in pairs(clients) do
	       client:close()
	    end
	 end
      end
   end
   return self
end

return {
   listen = listen
       }