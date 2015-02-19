package = "lua-websockets-copas"
version = "scm-1"

source = {
  url = "git://github.com/lipp/lua-websockets.git",
}

description = {
  summary = "copas backend for websockets for Lua",
  homepage = "http://github.com/lipp/lua-websockets",
  license = "MIT/X11",
  detailed = "Provides async client and server for copas."
}

dependencies = {
  "lua >= 5.1",
  "lua-websockets-core",
  "luasocket",
  "copas"
}

build = {
  type = 'none',
  install = {
    lua = {
      ['websocket.client_copas'] = 'src/websocket/client_copas.lua',
      ['websocket.server_copas'] = 'src/websocket/server_copas.lua',
    }
  }
}

