
local ev = require'ev'
local ev_common = require'websocket.ev_common'
local socket = require'socket'

setloop('ev')

describe('The ev_common helper module',function()
    
    local listen_io
    setup(function()
        local listener = socket.bind('*',12345)
        listener:settimeout(0)
        listen_io = ev.IO.new(
          function()
            local client_sock = listener:accept()
            client_sock:settimeout(0)
            local client_io = ev.IO.new(function(loop,io)
                repeat
                  local _,err = client_sock:receive(1000)
                  if err ~= 'timeout' then
                    io:stop(loop)
                    client_sock:close()
                  end
                until err
              end,client_sock:getfd(),ev.READ)
            client_io:start(ev.Loop.default)
          end,listener:getfd(),ev.READ)
        listen_io:start(ev.Loop.default)
      end)
    
    teardown(function()
        listen_io:stop(ev.Loop.default)
      end)
    
    local send,stop
    local sock
    before_each(function(done)
        sock = socket.tcp()
        sock:settimeout(0)
        ev.IO.new(async(function(loop,io)
              send,stop = ev_common.async_send(sock)
              io:stop(loop)
              done()
          end),sock:getfd(),ev.WRITE):start(ev.Loop.default)
        sock:connect('localhost',12345)
        send,stop = ev_common.async_send(sock)
      end)
    
    after_each(function()
        stop()
        sock:close()
      end)
    
    local chunk1 = 'some data'
    local chunk2 = string.rep('some more data',10000)
    
    it('calls on_sent callback',function(done)
        local on_sent = async(function(buf)
            assert.is_equal(buf,chunk1..chunk2)
            done()
          end)
        
        local on_err = async(function(err)
            assert.is_nil(err or 'should not happen')
          end)
        
        send(chunk1..chunk2,on_sent,on_err)
      end)
    
    it('can be stopped',function(done)
        local on_sent = async(function(buf)
            assert.is_nil(err or 'should not happen')
          end)
        
        local on_err = async(function(err)
            assert.is_nil(err or 'should not happen')
          end)
        
        send(string.rep('foo',3000000),on_sent,on_err)
        stop()
        ev.Timer.new(function() done() end,0.01):start(ev.Loop.default)
      end)
    
    it('calls on_error callback',function(done)
        sock:close()
        send('some data closing',
          async(function()
              assert.is_nil('should not happen')
            end),
          async(function(err)
              assert.is_equal(err,'closed')
              done()
          end))
      end)
    
  end)
