#!/usr/bin/env lua
--- lua websocket equivalent to test-server.c from libwebsockets.
-- using lua-ev event loop
package.path = '../src/?.lua;../src/?/?.lua;'..package.path
local ev = require'ev'
local loop = ev.Loop.default
local websocket = require'websocket'
local server = websocket.server.ev.listen
{
  protocols = {
    ['lws-mirror-protocol'] = function(ws)
      ws:on_message(
        function(ws,data,opcode)
          if opcode == websocket.TEXT then
            ws:broadcast(data)
          end
        end)
    end,
    ['dumb-increment-protocol'] = function(ws)
      local number = 0
      local timer = ev.Timer.new(
        function()
          ws:send(tostring(number))
          number = number + 1
        end,0.1,0.1)
      timer:start(loop)
      ws:on_message(
        function(ws,message,opcode)
          if opcode == websocket.TEXT then
            if message:match('reset') then
              number = 0
            end
          end
        end)
      ws:on_close(
        function()
          timer:stop(loop)
        end)
    end
  },
  port = 12345
}

print('Open browser:')
print('file://'..io.popen('pwd'):read()..'/index.html')
loop:loop()

