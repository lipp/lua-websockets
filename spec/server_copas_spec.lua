package.path = package.path..'../src'

local server = require'websocket.server'
local client = require'websocket.client'
local port = os.getenv('LUAWS_SERVER_COPAS_PORT') or 8084
local url = 'ws://localhost:'..port

local copas = require'copas'


setloop('copas')

describe(
  'The server (copas) module',
  function()
    local s
    it(
      'exposes the correct interface',
      function()
        assert.is_table(server)
        assert.is_table(server.copas)
        assert.is_function(server.copas.listen)
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
                assert.is_table(client)
                assert.is_function(client.receive)
                assert.is_function(client.close)
                assert.is_function(client.send)
                client:close()
                done()
              end)
            
            copas.addthread(
              guard(
                function()
                  local wsc = client.copas()
                  local ok,err = wsc:connect('ws://localhost:'..port,'echo')
                  assert.is_true(ok)
                  local was_clean,code,reason = wsc:close()
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
                  local wsc = client.copas()
                  local hello = 'Hello'
                  wsc:connect('ws://localhost:'..port,'echo')
                  wsc:send(hello)
                  local message,err = wsc:receive()
                  assert.is_same(#message,#hello)
                  assert.is_same(message,hello)
                  wsc:close()
                  done()
              end))
          end)
        
        local random_text = function(len)
          local chars = {}
          for i=1,len do
            chars[i] = string.char(math.random(33,126))
          end
          return table.concat(chars)
        end
        
        it(
          'echo 127 bytes works',
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
                  local wsc = client.copas()
                  wsc:connect('ws://localhost:'..port,'echo')
                  local message = random_text(127)
                  wsc:send(message)
                  local echoed = wsc:receive()
                  assert.is_same(message,echoed)
                  wsc:close()
                  done()
              end))
          end)
        
        it(
          'echo 0xffff-1 bytes works',
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
                  local wsc = client.copas()
                  wsc:connect('ws://localhost:'..port,'echo')
                  local message = random_text(0xffff-1)
                  wsc:send(message)
                  local echoed = wsc:receive()
                  assert.is_same(message,echoed)
                  wsc:close()
                  done()
              end))
          end)
        
        it(
          'echo 0xffff+1 bytes works',
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
                  local wsc = client.copas()
                  wsc:connect('ws://localhost:'..port,'echo')
                  local message = random_text(0xffff+1)
                  wsc:send(message)
                  local echoed = wsc:receive()
                  assert.is_same(message,echoed)
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

