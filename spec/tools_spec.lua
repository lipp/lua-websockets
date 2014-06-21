package.path = package.path..'../src'

local tools = require'websocket.tools'

local bytes = string.char

-- from wiki article
local quick_brown_fox_sha1 = bytes(0x2f,0xd4,0xe1,0xc6,
  0x7a,0x2d,0x28,0xfc,
  0xed,0x84,0x9e,0xe1,
  0xbb,0x76,0xe7,0x39,
0x1b,0x93,0xeb,0x12)

describe(
  'The tools module',
  function()
    it(
      'SHA-1 algorithm works',
      function()
        local sha = tools.sha1('The quick brown fox jumps over the lazy dog')
        assert.is_same(sha,quick_brown_fox_sha1)
      end)
    
    it(
      'Base64 encoding works',
      function()
        local base64 = tools.base64.encode('pleasure')
        assert.is_same(base64,'cGxlYXN1cmU=')
        local base64 = tools.base64.encode('leasure')
        assert.is_same(base64,'bGVhc3VyZQ==')
        local base64 = tools.base64.encode('easure')
        assert.is_same(base64,'ZWFzdXJl')
      end)
    
    it(
      'Generate Key works',
      function()
        local keys = {}
        for i=1,200 do
          local key = tools.generate_key()
          assert.is_same(type(key),'string')
          assert.is_same(#key,24)
          assert.is_truthy(key:match('^[%w=/%+]*$'))
          for _,other in pairs(keys) do
            assert.is_not_same(other,key)
          end
          keys[i] = key
        end
      end)
    
    it(
      'URL parser works',
      function()
        local protocol,host,port,uri = tools.parse_url('ws://www.example.com')
        assert.is_same(protocol,'ws')
        assert.is_same(host,'www.example.com')
        assert.is_same(port,80)
        assert.is_same(uri,'/')
        
        local protocol,host,port,uri = tools.parse_url('ws://www.example.com:8080')
        assert.is_same(protocol,'ws')
        assert.is_same(host,'www.example.com')
        assert.is_same(port,8080)
        assert.is_same(uri,'/')
        
        local protocol,host,port,uri = tools.parse_url('ws://www.example.com:8080/foo')
        assert.is_same(protocol,'ws')
        assert.is_same(host,'www.example.com')
        assert.is_same(port,8080)
        assert.is_same(uri,'/foo')
        
        local protocol,host,port,uri = tools.parse_url('ws://www.example.com:8080/')
        assert.is_same(protocol,'ws')
        assert.is_same(host,'www.example.com')
        assert.is_same(port,8080)
        assert.is_same(uri,'/')
        
        local protocol,host,port,uri = tools.parse_url('ws://www.example.com/')
        assert.is_same(protocol,'ws')
        assert.is_same(host,'www.example.com')
        assert.is_same(port,80)
        assert.is_same(uri,'/')
        
        local protocol,host,port,uri = tools.parse_url('ws://www.example.com/foo')
        assert.is_same(protocol,'ws')
        assert.is_same(host,'www.example.com')
        assert.is_same(port,80)
        assert.is_same(uri,'/foo')
        
      end)
    
  end)
