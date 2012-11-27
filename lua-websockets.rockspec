package = "lua-websockets"
version = "@VERSION@-1"

source = {
   url = "git://github.com/downloads/lipp/lua-websockets/lua-websockets-@VERSION@.tar.gz",
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
   platforms = {
      macosx = {
         modules = {
            websockets = {               
               defines = {
                  "LWS_NO_FORK"
               }
            }
         }
      }
   },
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
