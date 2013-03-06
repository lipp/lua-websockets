local ev = require'ev'
local frame = require'websocket.frame'
local tinsert = table.insert
local tconcat = table.concat

local async_send = function(sock,loop)
  assert(sock)
  loop = loop or ev.Loop.default
  local sock_send = sock.send
  local buffer
  local io
  return function(data,on_sent,on_err)
    if buffer then
      -- a write io is still running
      buffer = buffer..data
      return
    else
      buffer = data
    end
    if not io then
      local index
      io = ev.IO.new(
        function(loop,write_io)
          local len = #buffer
          local sent,err = sock_send(sock,buffer,index)
          if not sent and err ~= 'timeout' then
            write_io:stop(loop)
            if on_err then
              on_err(err)
            end
          elseif sent == len then
            buffer = nil
            write_io:stop(loop)
            if on_sent then
              on_sent()
            end
          else
            assert(sent < len)
            index = sent
          end
        end,sock:getfd(),ev.WRITE)
    end
    io:start(loop)
  end
end

local message_io = function(sock,loop,on_message,on_error)
  assert(sock)
  assert(loop)
  assert(on_message)
  assert(on_error)
  local last
  local frames = {}
  local first_opcode
  return ev.IO.new(
    function(loop,message_io)
      while true do
        local encoded,err,part = sock:receive(100000)
        if err then
          if err ~= 'timeout' then
            message_io:stop(loop)
            on_error(err)
            return
          elseif #part == 0 then
            return
          end
        end
        
        if last then
          encoded = last..(encoded or part)
          last = nil
        else
          encoded = encoded or part
        end
        
        repeat
          local decoded,fin,opcode,rest = frame.decode(encoded)
          if decoded then
            if not first_opcode then
              first_opcode = opcode
            end
            tinsert(frames,decoded)
            encoded = rest
            if fin == true then
              on_message(tconcat(frames),first_opcode)
              frames = {}
              first_opcode = nil
            end
          end
        until not decoded
        if #encoded > 0 then
          last = encoded
        end
      end
    end,sock:getfd(),ev.READ)
end

return {
  async_send = async_send,
  message_io = message_io
}
