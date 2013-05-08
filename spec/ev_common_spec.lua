
local ev_common = require'websocket.ev_common'
local socket = require'socket'

setloop('ev')

describe('The ev_common helpr module',function()
    it('provides message_io and async_send methods',function()
        assert.is_function(ev_common.async_send)
        assert.is_function(ev_common.message_io)
      end)
    
    describe('async_send',function()
        local sock = socket.connect('www.google.com',80)
        sock:settimeout(0)
        local send,stop
        it('returns a function',function()
            send,stop = ev_common.async_send(sock)
            assert.is_function(send)
            assert.is_function(stop)
          end)
        
        it('calls on_sent callback once',async,function(done)
            local chunk1 = 'some data'
            local chunk2 = string.rep('some more data',10000)
            local on_sent = guard(function(buf)
                assert.is_equal(buf,chunk1..chunk2)
                done()
              end)
            
            local on_err = guard(function(err)
                assert.is_nil(err or 'should not happen')
              end)
            
            send(chunk1,on_sent,on_err)
            send(chunk2,on_sent,on_err)
          end)
                
        it('calls on_error callback',async,function(done)
            sock:close()
            send('some data',
              guard(function()
                  assert.is_nil('should not happen')
                end),
              guard(function(err)
                  assert.is_equal(err,'closed')
                  done()
              end))
          end)
      end)
    
  end)
