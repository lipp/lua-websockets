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
    
    it(
      'URL parser works with IPv6 and WSS',
      function()
        local URLS = {
          [ "WS://[::1]"                          ] = { "ws",  "[::1]",               80,   "/"      };
          [ "ws://[::1]"                          ] = { "ws",  "[::1]",               80,   "/"      };
          ["wss://[0:0:0:0:0:0:0:1]"              ] = { "wss", "[0:0:0:0:0:0:0:1]",   443,  "/"      };
          ["wss://[0:0:0:0:0:0:0:1]:8080"         ] = { "wss", "[0:0:0:0:0:0:0:1]",   8080, "/"      };
          [ "ws://[0:0:0:0:0:0:0:1]"              ] = { "ws",  "[0:0:0:0:0:0:0:1]",   80,   "/"      };
          [ "ws://[0:0:0:0:0:0:0:1]:8080"         ] = { "ws",  "[0:0:0:0:0:0:0:1]",   8080, "/"      };
          [ "ws://[0:0:0:0:0:0:0:1]:8080/query"   ] = { "ws",  "[0:0:0:0:0:0:0:1]",   8080, "/query" };
          ["wss://127.0.0.1"                      ] = { "wss", "127.0.0.1",           443,  "/"      };
          ["wss://127.0.0.1:8080"                 ] = { "wss", "127.0.0.1",           8080, "/"      };
          [ "ws://127.0.0.1"                      ] = { "ws",  "127.0.0.1",           80,   "/"      };
          [ "ws://127.0.0.1:8080"                 ] = { "ws",  "127.0.0.1",           8080, "/"      };
          [ "ws://127.0.0.1:8080/query"           ] = { "ws",  "127.0.0.1",           8080, "/query" };
          ["wss://echo.websockets.org"            ] = { "wss", "echo.websockets.org", 443,  "/"      };
          ["wss://echo.websockets.org:8080"       ] = { "wss", "echo.websockets.org", 8080, "/"      };
          [ "ws://echo.websockets.org"            ] = { "ws",  "echo.websockets.org", 80,   "/"      };
          [ "ws://echo.websockets.org:8080"       ] = { "ws",  "echo.websockets.org", 8080, "/"      };
          [ "ws://echo.websockets.org:8080/query" ] = { "ws",  "echo.websockets.org", 8080, "/query" };
          -- unknown protocol
          ["w2s://echo.websockets.org/query"      ] = { "w2s", "echo.websockets.org", nil,    "/query" };
        }

        for url, res in pairs(URLS) do
          local a,b,c,d = tools.parse_url(url)
          assert.is_same(a, res[1])
          assert.is_same(b, res[2])
          assert.is_same(c, res[3])
          assert.is_same(d, res[4])
        end

      end
    )

  end)
