package.path = package.path..'../src'

local server = require'websocket.server'
local client = require'websocket.client'
local port = os.getenv('LUAWS_PORT') or 8081
local copas = require'copas'

setloop('copas')

describe(
  'The server (copas) module',
  function()
    local s
    it(
      'exposes the correct interface',
      function()
        assert.is_same(type(server),'table')
        assert.is_same(type(server.copas),'table')
        assert.is_same(type(server.copas.listen),'function')
      end)
    
    it(
      'call listen with default handler',
      function()
        local s = server.copas.listen
        {
          default = function() end,
          port = port
        }
        s:close()
      end)
    
    it(
      'call listen with protocol handlers',
      function()
        local s = server.copas.listen
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
            local s = server.copas.listen
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
            s = server.copas.listen
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
            on_new_echo_client = guard(
              function(client)
                assert.is_same(type(client),'table')
                assert.is_same(type(client.receive),'function')
                assert.is_same(type(client.close),'function')
                assert.is_same(type(client.send),'function')
                client:close()
                done()
              end)
            
            copas.addthread(
              guard(
                function()
                  local wsc = client.copas
                  {
                    url = 'ws://localhost:'..port,
                    protocol = 'echo'
                  }
                  wsc:connect()
              end))
          end)
        
        it(
          'echo works',
          async,
          function(done)
            on_new_echo_client = guard(
              function(client)
                local message = client:receive()
                client:send(message)
                client:close()
              end)
            
            copas.addthread(
              guard(
                function()
                  local wsc = client.copas
                  {
                    url = 'ws://localhost:'..port,
                    protocol = 'echo'
                  }
                  wsc:connect()
                  wsc:send('Hello')
                  local message = wsc:receive()
                  assert.is_same(message,'Hello')
                  wsc:close()
                  done()
              end))
          end)
        
        after(
          function()
            s:close()
          end)
      end)
    
  end)

