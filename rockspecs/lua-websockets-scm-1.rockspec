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
	LIBWEBSOCKETS = {
		header = "libwebsockets.h",
		library = "websockets",
	}
}
build = {
	type = "builtin",
	modules = {
		websockets = {
			sources = {"src/lwebsockets.c"},
			incdirs = "$(LIBWEBSOCKETS_INCDIR)",
			libdirs = "$(LIBWEBSOCKETS_LIBDIR)",
			libraries = {"websockets"},
		},
	},
}
