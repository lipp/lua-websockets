package.path = package.path..'../src'

local server = require'websocket.server'
local client = require'websocket.client'
local ev = require'ev'
local port = os.getenv('LUAWS_SERVER_EV_PORT') or 8083
local url = 'ws://localhost:'..port

setloop('ev')

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
        
        after(
          function()
            s:close()
          end)
        
        it(
          'open and close handshake work (client closes)',
          async,
          function(done)
            local wsc = client.ev()
            on_new_echo_client = guard(
              function(client)
                assert.is_same(type(client),'table')
                assert.is_same(type(client.on_message),'function')
                assert.is_same(type(client.close),'function')
                assert.is_same(type(client.send),'function')
              end)
            wsc:on_open(guard(
                function()
                  wsc:on_close(guard(function(_,was_clean,code,reason)
                        assert.is_true(was_clean)
                        assert.is_true(code >= 1000)
                        assert.is_string(reason)
                        done()
                    end))
                  wsc:close()
              end))
            wsc:connect(url,'echo')
          end)
        
        it(
          'open and close handshake work (server closes)',
          async,
          function(done)
            local wsc = client.ev()
            on_new_echo_client = guard(
              function(client)
                assert.is_same(type(client),'table')
                assert.is_same(type(client.on_message),'function')
                assert.is_same(type(client.close),'function')
                assert.is_same(type(client.send),'function')
                client:on_close(guard(function(_,was_clean,code,reason)
                      assert.is_true(was_clean)
                      assert.is_true(code >= 1000)
                      assert.is_string(reason)
                      done()
                  end))
                client:close()
              end)
            wsc:connect(url,'echo')
          end)
        
        it(
          'echo works',
          async,
          function(done)
            local wsc = client.ev()
            on_new_echo_client = guard(
              function(client)
                client:on_message(
                  guard(
                    function(self,msg)
                      assert.is_equal(self,client)
                      self:send('Hello')
                  end))
              end)
            wsc:on_open(guard(
                function(self)
                  assert.is_equal(self,wsc)
                  self:send('Hello')
                  self:on_message(
                    guard(
                      function(_,message)
                        assert.is_same(message,'Hello')
                        self:close()
                        done()
                    end))
              end))
            wsc:connect(url,'echo')
          end)
        
        local random_text = function(len)
          local chars = {}
          for i=1,len do
            chars[i] = string.char(math.random(33,126))
          end
          return table.concat(chars)
        end
        
        it(
          'echo works with 127 byte messages',
          async,
          function(done)
            local message = random_text(127)
            local wsc = client.ev()
            on_new_echo_client = guard(
              function(client)
                client:on_message(
                  guard(
                    function(self,msg)
                      assert.is_equal(self,client)
                      self:send(message)
                  end))
              end)
            
            wsc:on_open(guard(
                function(self)
                  assert.is_equal(self,wsc)
                  self:send(message)
                  self:on_message(
                    guard(
                      function(_,echoed)
                        assert.is_same(message,echoed)
                        self:close()
                        done()
                    end))
              end))
            wsc:connect(url,'echo')
          end)
        
        it(
          'echo works with 0xffff-1 byte messages',
          async,
          function(done)
            local message = random_text(0xffff-1)
            local wsc = client.ev()
            on_new_echo_client = guard(
              function(client)
                client:on_message(
                  guard(
                    function(self,msg)
                      assert.is_equal(self,client)
                      self:send(message)
                  end))
              end)
            
            wsc:on_open(guard(
                function(self)
                  assert.is_equal(self,wsc)
                  self:send(message)
                  self:on_message(
                    guard(
                      function(_,echoed)
                        assert.is_same(message,echoed)
                        self:close()
                        done()
                    end))
              end))
            
            wsc:connect(url,'echo')
          end)
        
        it(
          'echo works with 0xffff+1 byte messages',
          async,
          function(done)
            local message = random_text(0xffff+1)
            local wsc = client.ev()
            on_new_echo_client = guard(
              function(client)
                client:on_message(
                  guard(
                    function(self,msg)
                      assert.is_equal(self,client)
                      self:send(message)
                  end))
              end)
            
            wsc:on_open(guard(
                function(self)
                  assert.is_equal(self,wsc)
                  self:send(message)
                  self:on_message(
                    guard(
                      function(_,echoed)
                        assert.is_same(message,echoed)
                        self:close()
                        done()
                    end))
              end))
            wsc:connect(url,'echo')
          end)
        
      end)
    
  end)

