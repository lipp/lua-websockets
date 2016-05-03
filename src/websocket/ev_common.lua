local ev = require'ev'
local frame = require'websocket.frame'
local tinsert = table.insert
local tconcat = table.concat
local eps = 2^-40

local detach = function(f,loop)
  if ev.Idle then
    ev.Idle.new(function(loop,io)
        io:stop(loop)
        f()
      end):start(loop)
  else
    ev.Timer.new(function(loop,io)
        io:stop(loop)
        f()
      end,eps):start(loop)
  end
end

local async_send = function(sock,loop)
  assert(sock)
  loop = loop or ev.Loop.default
  local sock_send = sock.send
  local buffer
  local index
  local callbacks = {}
  local send = function(loop,write_io)
    local len = #buffer
    local sent,err,last = sock_send(sock,buffer,index)
    if not sent and err ~= 'timeout' then
      write_io:stop(loop)
      if callbacks.on_err then
        if write_io:is_active() then
          callbacks.on_err(err)
        else
          detach(function()
              callbacks.on_err(err)
            end,loop)
        end
      end
    elseif sent then
      local copy = buffer
      buffer = nil
      index = nil
      write_io:stop(loop)
      if callbacks.on_sent then
        -- detach calling callbacks.on_sent from current
        -- exection if thiis call context is not
        -- the send io to let send_async(_,on_sent,_) truely
        -- behave async.
        if write_io:is_active() then
          
          callbacks.on_sent(copy)
        else
          -- on_sent is only defined when responding to "on message for close op"
          -- so this can happen only once per lifetime of a websocket instance.
          -- callbacks.on_sent may be overwritten by a new call to send_async
          -- (e.g. due to calling ws:close(...) or ws:send(...))
          local on_sent = callbacks.on_sent
          detach(function()
              on_sent(copy)
            end,loop)
        end
      end
    else
      assert(last < len)
      index = last + 1
    end
  end
  local io = ev.IO.new(send,sock:getfd(),ev.WRITE)
  local stop = function()
    io:stop(loop)
    buffer = nil
    index = nil
  end
  local send_async = function(data,on_sent,on_err)
    if buffer then
      -- a write io is still running
      buffer = buffer..data
      return #buffer
    else
      buffer = data
    end
    callbacks.on_sent = on_sent
    callbacks.on_err = on_err
    if not io:is_active() then
      send(loop,io)
      if index ~= nil then
        io:start(loop)
      end
    end
    local buffered = (buffer and #buffer - (index or 0)) or 0
    return buffered
  end
  return send_async,stop
end

local message_io = function(sock,loop,on_message,on_error)
  assert(sock)
  assert(loop)
  assert(on_message)
  assert(on_error)
  local last
  local frames = {}
  local first_opcode
  assert(sock:getfd() > -1)
  local message_io
  local dispatch = function(loop,io)
    -- could be stopped meanwhile by on_message function
    while message_io:is_active() do
      local encoded,err,part = sock:receive(100000)
      if err then
        if err == 'timeout' and #part == 0 then
          return
        elseif #part == 0 then
          if message_io then
            message_io:stop(loop)
          end
          on_error(err,io,sock)
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
  end
  message_io = ev.IO.new(dispatch,sock:getfd(),ev.READ)
  message_io:start(loop)
  -- the might be already data waiting (which will not trigger the IO)
  dispatch(loop,message_io)
  return message_io
end

return {
  async_send = async_send,
  message_io = message_io
}
