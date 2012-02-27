About
=====

A Lua binding for [libwebsockets](http://git.warmcat.com/cgi-bin/cgit/libwebsockets). To ease implementation, libwebsockets has been [modified](https://github.com/lipp/libwebsockets-exp) (no biggy, <10 lines). 

Usage
=====

See test-server.lua, which is the Lua equivalent to the test-server.c example from libwebsockets.

```shell
lua test-server/test-server.lua test-server/ 
```
run from cloned repo directory.

Build
=====

```shell 
luarocks make rockspecs/lua-websockets-scm-1.rockspec 
```
run from cloned repo directory.
