package = "lua-websockets-ev"
version = "scm-1"

source = {
  url = "git://github.com/lipp/lua-websockets.git",
}

description = {
  summary = "libev backend for websockets for Lua",
  homepage = "http://github.com/lipp/lua-websockets",
  license = "MIT/X11",
  detailed = "Provides async client and server for lua-ev."
}

dependencies = {
  "lua >= 5.1",
  "lua-websockets-core",
  "luasocket",
  "lua-ev",
}

build = {
  type = 'none',
  install = {
    lua = {
      ['websocket.client_ev'] = 'src/websocket/client_ev.lua',
      ['websocket.ev_common'] = 'src/websocket/ev_common.lua',
      ['websocket.server_ev'] = 'src/websocket/server_ev.lua',
    }
  }
}

