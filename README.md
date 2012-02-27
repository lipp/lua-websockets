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

## websocket 'global' methods

### websockets.context(config)

```lua
local context = websockets.context({
        port = 8001,
        on_http = function(ws,uri) ws:serve_http_file(uri,'text/html') end
        protocols = {
                  'echo' = 
                         function(ws)
                                ws:on_receive(
                                        function(data)
                                                ws:write(data,websockets.WRITE_TEXT)
                                        end) 
                         end
        },
        interf = 'eth0', --optional
        ssl_cert_path, --string, optional
        ssl_private_key_filepath, --string, optional
        gid, --int, optional
        uid, --int, optional
        options --int, optional
})
```
Behaves like libwebsocket_context_create. 'protocols' is a table, which
holds entries with key=protocol_name and
value=on_connect_callback. The on_connect_callback gets a websocket
object as argument.
If not present, all values default as described in C documentation.
Returns a context object.

## context methods

A context can be created via websockets.context(...).

### context:destroy()

Destroys a context. Behaves like libwebsocket_context_destroy.

### context:service(timeout_ms)

Services the context's outstanding io. Behaves like
libwebsocket_service. The integer timeout_ms value defaults to 0 (no timeout).

### context:canonical_hostname()

Returns the context's canonical hostname (machine name). Behaves like
libwebsocket_canonical_hostname.

### context:broadcast(protocol_name,data)

```lua
context:broadcast('echo','hello')
```
Broadcast data for all open websockets of kind protocol_name. Behaves
like libwebsockets_broadcast. Both parameters are strings. 

## websocket methods

A websocket can not be explicitly created, instead it gets passed to
various callback methods, e.g. the protocol connect callback handler
(see websockets.context)

### websocket:serve_http_file(filename,content_type)

```lua
websocket:serve_http_file('./index.html','text/html')
```

Serves a file from filesystem. Can only be called from within
context's on_http callback. Behaves like
libwebsockets_serve_http_file.

### websocket:write(data,write_type)

```lua
websocket:write('hello',
        websockets.WRITE_TEXT -- can be either websockets.WRITE_TEXT
        or websockets.WRITE_BINARY
        )
```

Writes data to websocket. The write_type must be .

### websocket:on_closed(callback)

Registers an on_closed callback on the websocket.

### websocket:on_broadcast(callback_or_mode)

```lua  
websocket:on_broadcast(websockets.WRITE_TEXT) --forward broadcast as text
websocket:on_broadcast(websockets.WRITE_BINARY) --forward broadcast binary
websocket:on_broadcast(
        function(ws)
                ws:write('hello',websockets.WRITE_TEXT)
        end)
```

Registers an on_broadcast callback on the websocket if
callback_or_mode is a function. If callback_or_mode is either
websockets.WRITE_TEXT or websockets.WRITE_BINARY, any incoming
braodcast events forward the message with the respective type. See
libwebsockets_broadcast and and handling of LWS_CALLBACK_BROADCAST.

### websocket:on_receive(callback)

```lua
websocket:on_receive(
        function(ws,data)
                ws:write(data,websockets.WRITE_TEXT)
        end)
```

Registers a receive handler for incoming data. The callback gets the
websocket and the data passed as arguments.

### websocket:broadcast(data)

Broadcasts data to all websockets of the same protocol. Behaves like libwebsockets_broadcast.

### websocket:get_socket_fd()

Returns the websocket's socket fd. Useful when using other event loop,
e.g. lua-ev.
