local ev = require'ev'
local ws_client = require('websocket.client').ev()

local params = {
  mode = "client",
  protocol = "tlsv1_2",
  verify = "none"
}

ws_client:on_open(function()
    print('connected')
  end)

ws_client:connect('wss://echo.websocket.org','echo',params)

ws_client:on_message(function(ws, msg)
    print('received',msg)
  end)

local i = 0

ev.Timer.new(function()
    i = i + 1
    ws_client:send('hello '..i)
end,1,1):start(ev.Loop.default)

ev.Loop.default:loop()
