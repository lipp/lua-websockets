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
}

external_dependencies = {
   LIBWEBSOCKETS = {
      header = "libwebsockets.h",
      library = "libwebsockets.so"
   }
}

build = {
   type = "builtin",
   modules = {
      websockets = {
	 sources = {
	    "lua_websockets.c"
	 },		
	 libraries = {
            "websockets"
         },
      },
   },
}
