package = "lua-websockets"
version = "scm-1"

source = {
   url = "git://github.com/lipp/lua-websockets.git",
}

description = {
   summary = "Lua bindings to libwebsockets (http://git.warmcat.com/cgi-bin/cgit/libwebsockets/).",
   homepage = "http://github.com/lipp/lua-websockets",
   license = "MIT/X11",
}

dependencies = {
   "lua >= 5.1",
   "lpack",
   "luasocket"
}
build = {
  type = 'none',
  install = {
    lua = {
      ['websocket'] = 'src/websocket.lua',
      ['websocket.client'] = 'src/websocket/client.lua',
      ['websocket.client_ev'] = 'src/websocket/client_ev.lua',
      ['websocket.server'] = 'src/websocket/server.lua',
      ['websocket.server_ev'] = 'src/websocket/server_ev.lua',
      ['websocket.handshake'] = 'src/websocket/handshake.lua',
      ['websocket.tools'] = 'src/websocket/tools.lua',
      ['websocket.frame'] = 'src/websocket/frame.lua',
    }
  }
}

