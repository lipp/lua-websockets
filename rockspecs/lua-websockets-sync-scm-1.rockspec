package = "lua-websockets-sync"
version = "scm-1"

source = {
  url = "git://github.com/lipp/lua-websockets.git",
}

description = {
  summary = "Sunc backend for websockets for Lua",
  homepage = "http://github.com/lipp/lua-websockets",
  license = "MIT/X11",
  detailed = "Provides sync client"
}

dependencies = {
  "lua >= 5.1",
  "lua-websockets-core",
  "luasocket",
}

build = {
  type = 'none',
  install = {
    lua = {
      ['websocket.sync']        = 'src/websocket/sync.lua',
      ['websocket.client_sync'] = 'src/websocket/client_sync.lua',
    }
  }
}

