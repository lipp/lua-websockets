package = "lua-websockets"
version = "scm-1"
source = {
   url = "git://github.com/lipp/lua-websockets.git",
}
description = {
   summary = "Lua bindings to libwebsockets.",
   homepage = "http://github.com/lipp/lua-websockets",
   license = "MIT/X11",
}
dependencies = {
   "lua >= 5.1",
}
external_dependencies = {
}
build = {
   type = "builtin",
   modules = {
      websockets = {
	 sources = {
	    "src/lwebsockets.c",
	    "libwebsockets/lib/base64-decode.c",
	    "libwebsockets/lib/client-handshake.c",
	    "libwebsockets/lib/extension.c",
	    "libwebsockets/lib/extension-deflate-stream.c",
	    "libwebsockets/lib/handshake.c",
	    "libwebsockets/lib/libwebsockets.c",
	    "libwebsockets/lib/md5.c",
	    "libwebsockets/lib/parsers.c",
	    "libwebsockets/lib/sha-1.c",
	 },		
	 libraries = {"z"},
      },
   },
}
