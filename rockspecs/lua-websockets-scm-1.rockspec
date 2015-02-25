package = "lua-websockets"
version = "scm-1"

source = {
  url = "git://github.com/lipp/lua-websockets.git",
}

description = {
  summary = "Websockets for Lua",
  homepage = "http://github.com/lipp/lua-websockets",
  license = "MIT/X11",
  detailed = "Provides sync and async clients and servers for copas and lua-ev."
}

dependencies = {
  "lua-websockets-core",
  "lua-websockets-sync",
  "lua-websockets-copas",
  "lua-websockets-ev",
}

build = {type = "builtin", modules = {}}
