require'busted'
package.path = package.path..'../src'

local tools = require'websocket.tools'
require'pack'

local bytes = function(...)
   local args = {...}
   local format = string.rep('b',#args)
   return string.pack(format,...)
end

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
   end)