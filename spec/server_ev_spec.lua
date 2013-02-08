require'busted'
package.path = package.path..'../src'

local server = require'websocket.server'
local client = require'websocket.client'
local ev = require'ev'
local port = os.getenv('LUAWS_PORT') or 8081

describe(
   'The server (ev) module',
   function()     
      local s
      it(
	 'exposes the correct interface',
	 function()
	    assert.is_same(type(server),'table')
	    assert.is_same(type(server.ev),'table')
	    assert.is_same(type(server.ev.listen),'function')
	 end)

      it(
	 'call listen with default handler',
	 function()
            local s = server.ev.listen
            {
               default = function() end,
               port = port
            }
            s:close()
	 end)

      it(
	 'call listen with protocol handlers',
	 function()
            local s = server.ev.listen
            {
               port = port,
               protocols = {
                  echo = function() end
               }
            }
            s:close()
	 end)

      it(
	 'call listen without default nor protocol handlers has errors',
	 function()
            assert.has_error(
               function()
                  local s = server.ev.listen
                  {
                     port = port
                  }
                  s:close()
               end)
	 end)

      describe(
         'communicating with clients',
         function()
            local s
            local on_new_echo_client
            before(
               function()
                  s = server.ev.listen
                  {
                     port = port,
                     protocols = {
                        echo = function(client)
                           on_new_echo_client(client)
                        end                       
                     }
                  }
               end)
            
            it(
               'handshake works',
               async,
               function(done)
                  local wsc = client.ev
                  {
                     url = 'ws://localhost:'..port,
                     protocol = 'echo'
                  }
                  on_new_echo_client = function(client)
                     assert.is_same(type(client),'table')
                     assert.is_same(type(client.on_message),'function')
                     assert.is_same(type(client.close),'function')
                     assert.is_same(type(client.send),'function')
                     client:close()
                     wsc:close()
                     done()
                  end
                  wsc:connect()
               end)
            
            after(
               function()
                  s:close()
               end)
         end)

   end)

return function()
   ev.Loop.default:loop()
       end