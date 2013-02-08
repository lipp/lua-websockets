require'busted'
package.path = package.path..'../src'

local client = require'websocket.client'
local ev = require'ev'
local frame = require'websocket.frame'

describe(
   'The client (ev) module',
   function()     
      local wsc
      it(
	 'exposes the correct interface',
	 function()
	    assert.is_same(type(client),'table')
	    assert.is_same(type(client.ev),'function')
	 end)

      it(
	 'can be constructed',
	 function()
--            assert.has_no_error(
--               function()
                  wsc = client.ev
                  {
                     url = 'ws://localhost:8080',
                     protocol = 'echo-protocol'
                  }
  --             end)
	 end)

      it(
	 'can connect (requires external websocket server @port 8080)',
         async,
	 function(done)            
            wsc.on_connect(
               guard(
                  function(ws)
                     assert.is_equal(ws,wsc)
                     done()
                  end))                          
            wsc:connect()
	 end)

      it(
         'can send and receive data(requires external websocket server @port 8080)',
         async,
         function(done)
            assert.is_same(type(wsc.send),'function')	    
            wsc.on_message( 
               guard(
                  function(ws,message,opcode)
                     assert.is_equal(ws,wsc)
                     assert.is_same(message,'Hello again')
                     assert.is_same(opcode,frame.TEXT)
                     ws:close()
                     done()
                  end))
               wsc:send('Hello again')
         end)
   end)

return function()
   ev.Loop.default:loop()
       end