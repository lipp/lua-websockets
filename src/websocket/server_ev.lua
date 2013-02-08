
local socket = require'socket'
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tconcat = table.concat
local tinsert = table.insert
local loop

local client = function(sock)
   assert(sock and loop)
   sock:settimeout(0)
   local fd = sock:getfd()
   local message_io
   local on_message
   local on_error = function(s,err) print('Websocket unhandled error',s,err) end
   local on_close = function() end
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
      local encoded = frame.encode(message,opcode or frame.TEXT)
      send(encoded)
   end
   
   local last
   local frames = {}
   local message_io = ev.IO.new(
      function(loop,message_io)
         local encoded,err,part = sock:receive(4096)
         if encoded or #part > 0 then
            if last then
               encoded = last..(encoded or part)
               last = nil
            else
               encoded = encoded or part
            end
         elseif err ~= 'timeout' then                                 
            on_error(self,'Websocket message read io failed: '..err)
            message_io:stop(loop)
            return
         end
         
         repeat
            local decoded,fin,opcode,bytes = frame.decode(encoded)
            if decoded then
               tinsert(frames,decoded)
               encoded = encoded:sub(bytes)
            end
            if fin == true then
               on_message(self,tconcat(frames),opcode)
               frames = {}
            end
         until not decoded
         last = encoded
      end,fd,ev.READ)
   
   self.on_close = function(on_close_arg)
      on_close = on_close_arg
   end
   
   self.on_error = function(on_error_arg)
      on_error = on_error_arg
   end
   
   self.on_message = function(on_message_arg)
      if not on_message and message_io then
         message_io:start(loop)
      end
      on_message = on_message_arg      
   end
   
   self.close = function()
      message_io:stop(loop)
      sock:shutdown()
      sock:close()
      sock = nil
   end
   return self
end

local listen = function(opts)
   assert(opts and (opts.protocols or opts.default))
   local ev = require'ev'
   loop = opts.loop or ev.Loop.default
   local on_error = function(s,err) print('Websocket unhandled error',s,err) end   
   local protocols = {}
   if opts.protocols then
      for protocol in pairs(opts.protocols) do
         tinsert(protocols,protocol)
      end
   end
   
   local listener,err = socket.bind(opts.interface or '*',opts.port or 80)
   assert(listener,err)
   listener:settimeout(0)   
   listen_io = ev.IO.new(
      function()
         local client_sock = listener:accept()
         assert(client_sock)
         local request = {}
         ev.IO.new(
            function(loop,read_io)
               repeat 
                  local line,err,part = client_sock:receive('*l')
                  if line then
                     if last then
                        line = last..line
                        last = nil
                     end
                     request[#update_request+1] = line
                  elseif err ~= 'timeout' then
                     on_error(self,'Websocket Handshake failed due to socket err:'..err)
                  else
                     last = part
                     return
                  end
               until line == '' 
               read_io:stop(loop)
               local upgrade_request = tconcat(request,'\r\n')
               local response,protocol = handshake.accept_upgrade(upgrade_request,protocols)
               if protocol and opts.protocols[protocol] then
                  local new_client = client(sock)
                  opts.protocols[protocol](new_client)
               elseif not protocol and opts.default then
                  local new_client = client(sock)
                  opts.default(new_client)
               else
                  assert(false)
               end
            end,client_sock:getfd(),ev.READ):start(loop)
      end,listener:getfd(),ev.READ)
   local self = {}
   self.close = function()
      listen_io:stop(loop)
      listener:close()
   end
   listen_io:start(loop)
   return self
end

return {
   listen = listen
       }