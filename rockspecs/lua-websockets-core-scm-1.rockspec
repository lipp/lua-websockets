package = "lua-websockets-core"
version = "scm-1"

source = {
  url = "git://github.com/lipp/lua-websockets.git",
}

description = {
  summary = "Websockets for Lua",
  homepage = "http://github.com/lipp/lua-websockets",
  license = "MIT/X11",
  detailed = "Provides base functionality to implement websocket protocol."
}

dependencies = {
  "lua >= 5.1",
  "struct",
  "bit32",
}

build = {
  type = 'none',
  install = {
    lua = {
      ['websocket']           = 'src/websocket.lua',
      ['websocket.sync']      = 'src/websocket/sync.lua',
      ['websocket.client']    = 'src/websocket/client.lua',
      ['websocket.server']    = 'src/websocket/server.lua',
      ['websocket.handshake'] = 'src/websocket/handshake.lua',
      ['websocket.tools']     = 'src/websocket/tools.lua',
      ['websocket.frame']     = 'src/websocket/frame.lua',
      ['websocket.bit']       = 'src/websocket/bit.lua',
    }
  }
}

