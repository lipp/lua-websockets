local ev = require'ev'

local async_send = function(sock,loop)
  assert(sock)
  loop = loop or ev.Loop.default
  local sock_send = sock.send
  local buffer
  local io
  return function(data,on_sent,on_err)
    --      print('BLA',#data)
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
          --               print('sending')
          local len = #buffer
          --             print('s',#buffer,index)
          local sent,err = sock_send(sock,buffer,index)
          --           print('err',err,index,sent)
          if not sent and err ~= 'timeout' then
            --                  print('ERR ',err,sent)
            write_io:stop(loop)
            if on_err then
              on_err(err)
            end
          elseif sent == len then
            --               print('sent',#buffer)
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

return {
  async_send = async_send
}
