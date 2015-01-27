-- connects to a echo websocket server running a localhost:8080
-- sends a strong every second and prints the echoed messages
-- to stdout

local ev = require'ev'
local ws_client = require('websocket.client').ev()

ws_client:on_connect(function()
    print('connected')
  end)

ws_client:connect('ws://localhost:8080','echo')

ws_client:on_message(function(msg)
    print('received',msg)
  end)

local i = 0

ev.Timer.new(function()
    i = i + 1
    ws_client:send('hello '..i)
  end,1,1)

ev.Loop.default:loop()
