local server = require'websocket.server'
local client = require'websocket.client'
local socket = require'socket'
local ev = require'ev'
local loop = ev.Loop.default
local port = os.getenv('LUAWS_SERVER_EV_PORT') or 8083
local url = 'ws://127.0.0.1:'..port

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
      's:sock() provides access to the listening socket',
      function()
        local s = server.ev.listen
        {
          default = function() end,
          port = port
        }
        assert.is_truthy(tostring(s:sock()):match('tcp'))
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
        setup(
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
        
        teardown(
          function()
            s:close()
          end)
        
        it(
          'accepts socket connection and does not die when abruptly closing',
          function(done)
            local sock = socket.tcp()
            s:on_error(async(function()
                  s:on_error(nil)
                  done()
              end))
            sock:settimeout(0)
            local connected,err = sock:connect('127.0.0.1',port)
            local connect_io = ev.IO.new(async(function(loop,io)
                  io:stop(loop)
                  sock:close()
              end),sock:getfd(),ev.WRITE)
            if connected then
              connect_io:callback()(loop,connect_io)
            else
              connect_io:start(loop)
            end
          end)
        
        it(
          'open and close handshake work (client closes)',
          function(done)
            local wsc = client.ev()
            on_new_echo_client = async(
              function(client)
                assert.is_same(type(client),'table')
                assert.is_same(type(client.on_message),'function')
                assert.is_same(type(client.close),'function')
                assert.is_same(type(client.send),'function')
              end)
            wsc:on_open(async(
                function()
                  wsc:on_close(async(function(_,was_clean,code,reason)
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
          function(done)
            local wsc = client.ev()
            on_new_echo_client = async(
              function(client)
                assert.is_same(type(client),'table')
                assert.is_same(type(client.on_message),'function')
                assert.is_same(type(client.close),'function')
                assert.is_same(type(client.send),'function')
                client:on_close(async(function(_,was_clean,code,reason)
                      -- this is for hunting down some rare bug
                      if not was_clean then
                        print(debug.traceback('',2))
                      end
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
          function(done)
            local wsc = client.ev()
            on_new_echo_client = async(
              function(client)
                client:on_message(
                  async(
                    function(self,msg)
                      assert.is_equal(self,client)
                      self:send('Hello')
                  end))
              end)
            wsc:on_open(async(
                function(self)
                  assert.is_equal(self,wsc)
                  self:send('Hello')
                  self:on_message(
                    async(
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
          function(done)
            local message = random_text(127)
            local wsc = client.ev()
            on_new_echo_client = async(
              function(client)
                client:on_message(
                  async(
                    function(self,msg)
                      assert.is_equal(self,client)
                      self:send(message)
                  end))
              end)
            
            wsc:on_open(async(
                function(self)
                  assert.is_equal(self,wsc)
                  self:send(message)
                  self:on_message(
                    async(
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
          function(done)
            settimeout(3.0)
            local message = random_text(0xffff-1)
            local wsc = client.ev()
            on_new_echo_client = async(
              function(client)
                client:on_message(
                  async(
                    function(self,msg)
                      assert.is_equal(self,client)
                      self:send(message)
                  end))
              end)
            
            wsc:on_open(async(
                function(self)
                  assert.is_equal(self,wsc)
                  self:send(message)
                  self:on_message(
                    async(
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
          function(done)
            settimeout(3.0)
            local message = random_text(0xffff+1)
            local wsc = client.ev()
            on_new_echo_client = async(
              function(client)
                client:on_message(
                  async(
                    function(self,msg)
                      assert.is_equal(self,client)
                      self:send(message)
                  end))
              end)
            
            wsc:on_open(async(
                function(self)
                  assert.is_equal(self,wsc)
                  self:send(message)
                  self:on_message(
                    async(
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

