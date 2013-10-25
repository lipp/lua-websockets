local websocket = require'websocket'
local server = require'websocket.server'
local client = require'websocket.client'
local port = os.getenv('LUAWS_SERVER_COPAS_PORT') or 8084
local url = 'ws://localhost:'..port
local socket = require'socket'

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
        setup(
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
          'client:connect forwards socket error',
          function()
            local wsc = client.copas()
            local ok,err = wsc:connect('ws://nonexisting.foo:'..port)
            assert.is_nil(ok)
            if socket.tcp6 then
              assert.is_equal(err,'host or service not provided, or not known')
            else
              assert.is_equal(err,'host not found')
            end
          end)
        
        it(
          'handshake works with clean close (server inits close)',
          function(done)
            on_new_echo_client = async(function(client)
                assert.is_table(client)
                assert.is_function(client.receive)
                assert.is_function(client.close)
                assert.is_function(client.send)
                local was_clean,code,reason = client:close()
                assert.is_true(was_clean)
                assert.is_true(code >= 1000)
                assert.is_string(reason)
                done()
              end)
            
            copas.addthread(async(function()
                  local wsc = client.copas()
                  local ok,err = wsc:connect('ws://localhost:'..port,'echo')
                  assert.is_true(ok)
                  local was_clean,code,reason = wsc:close()
                  assert.is_true(was_clean)
                  assert.is_true(code >= 1000)
                  assert.is_string(reason)
              end))
          end)
        
        it(
          'handshake works with clean close (client inits close)',
          function(done)
            on_new_echo_client = async(function(client)
                assert.is_table(client)
                assert.is_function(client.receive)
                assert.is_function(client.close)
                assert.is_function(client.send)
                local message,opcode,was_clean,code,reason = client:receive()
                assert.is_nil(message)
                assert.is_nil(opcode)
                assert.is_true(was_clean)
                assert.is_true(code >= 1000)
                assert.is_string(reason)
                done()
              end)
            
            copas.addthread(async(function()
                  local wsc = client.copas()
                  local ok = wsc:connect('ws://localhost:'..port,'echo')
                  assert.is_true(ok)
                  local was_clean,code,reason = wsc:close()
                  assert.is_true(was_clean)
                  assert.is_true(code >= 1000)
                  assert.is_string(reason)
              end))
          end)
        
        it(
          'echo works',
          function(done)
            on_new_echo_client = async(
              function(client)
                local message = client:receive()
                client:send(message)
                client:close()
              end)
            
            copas.addthread(
              async(
                function()
                  local wsc = client.copas()
                  local hello = 'Hello'
                  wsc:connect('ws://localhost:'..port,'echo')
                  wsc:send(hello)
                  local message = wsc:receive()
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
          function(done)
            on_new_echo_client = async(
              function(client)
                local message = client:receive()
                client:send(message)
                client:close()
              end)
            
            copas.addthread(
              async(
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
          function(done)
            on_new_echo_client = async(
              function(client)
                local message = client:receive()
                client:send(message)
                client:close()
              end)
            
            copas.addthread(
              async(
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
          function(done)
            on_new_echo_client = async(
              function(client)
                local message = client:receive()
                client:send(message)
                local was_clean = client:close()
                assert.is_true(was_clean)
              end)
            
            copas.addthread(
              async(
                function()
                  local wsc = client.copas()
                  wsc:connect('ws://localhost:'..port,'echo')
                  local message = random_text(0xffff+1)
                  wsc:send(message)
                  local echoed = wsc:receive()
                  assert.is_same(message,echoed)
                  local echoed,_,was_clean = wsc:receive()
                  assert.is_nil(echoed)
                  assert.is_true(was_clean)
                  done()
              end))
          end)
        
        it(
          'broadcast works',
          function(done)
            local n = 20
            local n_clients = 0
            local closed = 0
            on_new_echo_client = async(
              function(client)
                n_clients = n_clients + 1
                if n_clients == n then
                  client:broadcast('hello broadcast')
                end
                client.id = n_clients
                local message,opcode,was_clean = client:receive()
                assert.is_nil(message)
                assert.is_nil(opcode)
                assert.is_true(was_clean)
                n_clients = n_clients - 1
                if n_clients == 0 and closed == n then
                  done()
                end
              end)
            
            for i=1,n do
              copas.addthread(
                async(
                  function()
                    local wsc = client.copas()
                    local ok,err = wsc:connect('ws://localhost:'..port,'echo')
                    assert.is_nil(err)
                    assert.is_true(ok)
                    local message,opcode = wsc:receive()
                    assert.is_same(message,'hello broadcast')
                    assert.is_same(opcode,websocket.TEXT)
                    local was_clean = wsc:close()
                    assert.is_true(was_clean)
                    closed = closed + 1
                    if n_clients == 0 and closed == n then
                      done()
                    end
                end))
            end
          end)
        
        teardown(
          function()
            s:close(true)
          end)
        
      end)
    
    it(
      'on_error is called if request is incomplete due to socket close',
      function(done)
        local serv
        serv = server.copas.listen
        {
          port = port,
          protocols = {
            echo = function(client)
            end
          },
          on_error = async(function(err)
              assert.is_string(err)
              serv:close()
              done()
            end)
        }
        local s = socket.tcp()
        copas.connect(s,'localhost',port)
        s:send('GET / HTTP/1.1')
        s:close()
      end)
    
    it(
      'on_error is called if request is invalid',
      function(done)
        local serv = server.copas.listen
        {
          port = port,
          protocols = {
            echo = function(client)
            end,
          },
          on_error = function() end
        }
        copas.addthread(async(function()
              local s = socket.tcp()
              copas.connect(s,'localhost',port)
              copas.send(s,'GET / HTTP/1.1\r\n\r\n')
              local resp = copas.receive(s,'*l')
              assert.is_same(resp,'HTTP/1.1 400 Bad Request')
              local resp = copas.receive(s,2)
              assert.is_same(resp,'\r\n')
              s:close()
              serv:close()
              done()
          end))
      end)
    
    it(
      'default handler gets called when no protocol specified',
      function(done)
        local serv
        serv = server.copas.listen
        {
          port = port,
          protocols = {
            echo = async(function()
                assert.is_nil('should not happen')
              end)
          },
          default = async(function(client)
              client:send('hello default')
              local message,opcode,was_clean = client:receive()
              assert.is_nil(message)
              assert.is_nil(opcode)
              assert.is_true(was_clean)
            end),
        }
        copas.addthread(async(function()
              local wsc = client.copas()
              local ok = wsc:connect('ws://localhost:'..port)
              assert.is_true(ok)
              local message = wsc:receive()
              assert.is_same(message,'hello default')
              wsc:close()
              serv:close()
              done()
          end))
      end)
    
    it(
      'closing server closes all clients',
      function(done)
        local clients = 0
        local closed = 0
        local n = 2
        local serv
        serv = server.copas.listen
        {
          port = port,
          protocols = {
            echo = async(function(client)
                clients = clients + 1
                if clients == n then
                  copas.addthread(async(function()
                        serv:close()
                        assert.is_equal(closed,n)
                        done()
                    end))
                end
              end)
          }
        }
        
        for i=1,n do
          copas.addthread(async(function()
                local wsc = client.copas()
                local ok = wsc:connect('ws://localhost:'..port,'echo')
                assert.is_true(ok)
                local message,opcode,was_clean = wsc:receive()
                assert.is_nil(message)
                assert.is_nil(opcode)
                assert.is_true(was_clean)
                closed = closed + 1
            end))
        end
      end)
    
  end)

