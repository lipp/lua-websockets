# About

A Lua binding for [libwebsockets](http://git.warmcat.com/cgi-bin/cgit/libwebsockets). To ease implementation, libwebsockets has been [modified](https://github.com/lipp/libwebsockets-exp) (no biggy, <10 lines). 

# Usage

See test-server.lua, which is the Lua equivalent to the test-server.c example from libwebsockets.

```shell
lua test-server/test-server.lua test-server/ 
```
run from cloned repo directory.

# Build

```shell 
luarocks make rockspecs/lua-websockets-scm-1.rockspec 
```
run from cloned repo directory.

# API

## context(settings)

```lua
context({
        port = 8001,
        interf = 'eth0',
        protocols = {
                  'echo' = 
                         function(ws)
                                ws:on_receive(
                                        function(data)
                                                ws:write(data,websockets.WRITE_TEXT)
                                        end  
                         end
        },
        ssl_cert_path,
        ssl_private_key_filepath,
        gid,
        uid,
        options
})
```
Behaves like libwebsocket_context_create. protocols is a table, which
holds entries with key=protocol_name and value=on_connect_callback.
if left out, all values default as described in C documentation.
