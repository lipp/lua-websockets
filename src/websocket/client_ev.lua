
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
   local sock = socket.tcp()
   -- set non blocking
   sock:settimeout(0)

   local loop = ws.loop or ev.Loop.default
   local fd = sock:getfd()
   local self = {
      on_error = function(s,err) print('Websocket unhandled error',s,err) end,
      on_message = function() end,
      on_close = function() end,
      on_connect = function() end,
   }  

   send = function(data,on_sent)
      local len = #data
      local index
      ev.IO.new(
         function(loop,write_io)
            local sent,err = sock:send(data,index)
            if not sent then
               write_io:stop(loop)
               if err == 'closed' then
                  self.on_close(self)
               end
               self.on_error(self,'Websocket write failed '..err)
            elseif sent == len then
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
  
   local message_io
   
   local connect = function()
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
                  ev.IO.new(
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
                              self.on_error(self,'Websocket Handshake failed due to socket err:'..err)
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
                           self.on_error(self,msg:format(expected_accept,headers['sec-websocket-accept'] or 'nil'))              
                           return
                        end                       
                        self.on_connect(self)
                        local last
                        local frames = {}
                        message_io = ev.IO.new(
                           function(loop,message_io)
                              local encoded,err,part = sock:receive(4096)
--                              print('XXXXXXXXXXXXXXXXX',encoded and #encoded,err,#part,last)
                              if encoded or #part > 0 then
                                 if last then
                                    encoded = last..(encoded or part)
                                    last = nil
                                 else
                                    encoded = encoded or part
                                 end
                              elseif err ~= 'timeout' then                                 
                                 self.on_error(self,'Websocket message read io failed: '..err)
                                 message_io:stop(loop)
                                 return
                              end
                              
                              repeat
                                 local decoded,fin,opcode,bytes = frame.decode(encoded)
                       --          print('BLABLABLABLABLA',decoded,fin)
                                 if decoded then
                                    tinsert(frames,decoded)
                                    encoded = encoded:sub(bytes)
                                 end
                                 if fin == true then                                 
                                    self.on_message(self,tconcat(frames),opcode)
                                    frames = {}
                                 end
                              until not decoded
                              last = encoded
                           end,fd,ev.READ)
                        message_io:start(loop)
                     end,fd,ev.READ):start(loop) -- handshake
               end)
         end,fd,ev.WRITE):start(loop) -- connect
   end
   local _,err = sock:connect(host,port)
   assert(_ == nil)
   if err ~= 'timeout' then
      error('Websocket could not connect to '..ws.url)
   end
   self.close = function()
      message_io:stop(loop)
      sock:shutdown()
      sock:close()
   end
   self.connect = connect
   return self
end

return ev