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

## websockets table

### websockets.WRITE_TEXT

To be used as type with websocket:write(data,type)

### websockets.WRITE_BINARY

To be used as type with websocket:write(data,type)

### websockets.context(config)

```lua
local context = websockets.context({
        port = 8001,
        on_http = handle_http,
        on_add_fd = register_fd, --function, optional
        on_del_fd = unregister_fd, --function, optional
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
Behaves like `libwebsocket_context_create`. `'protocols'` is a table, which
holds entries with key=protocol_name and

value=on_connect_callback. The on_connect_callback gets a websocket
object as argument.

If not present, all values default as described in C documentation.
Returns a context object.

The `on_http` callback is called whenever http request are made and it
gets a `websocket` and the `uri` string passed.

The `on_add_fd` callback gets called for every new file descriptor which has
to be polled (sockets) with `fd` as argument.

The `on_del_fd` callback gets called whenever a `fd` is not
used any more (can be removed from polling).

## context methods

A context can be created via websockets.context(...).

### context:destroy()

```lua
context:destroy()
```
Destroys a context. Behaves like `libwebsocket_context_destroy`.

### context:service(timeout_ms)

```lua
while true do
      context:service(2000)
end
```
Services the context's outstanding io. Behaves like
`libwebsocket_service`. The integer `timeout_ms` value defaults to 0 (no timeout).

### context:canonical_hostname()
```lua
context:canonical_hostname()
```
Returns the context's canonical hostname (machine name). Behaves like
`libwebsocket_canonical_hostname`.

### context:broadcast(protocol_name,data)

```lua
context:broadcast('echo','hello')
```
Broadcast data for all open websockets of kind `protocol_name`. Behaves
like `libwebsockets_broadcast`. Both parameters are strings. 

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
        websockets.WRITE_TEXT -- must be websockets.WRITE_XYZ
        )
```

Writes data to websocket. The write_type must be
websockets.WRITE_XYZ. Behaves like `libwebsocket_write`.

### websocket:on_closed(callback)

```lua
websocket:on_closed(function() print('bye') end)
```

Registers an on_closed callback on the websocket. The callback gets no
parameters passed in.

### websocket:on_broadcast(callback_or_mode)

```lua  
websocket:on_broadcast(websockets.WRITE_TEXT) --forward broadcast as text
websocket:on_broadcast(websockets.WRITE_BINARY) --forward broadcast binary
websocket:on_broadcast(
        function(ws,data)
                ws:write(data..'hello',websockets.WRITE_TEXT)
        end)
```

Registers an on_broadcast callback on the websocket if
callback_or_mode is a function. If callback_or_mode is int
(websockets.WRITE_XYZ, any incoming braodcast events forward the message with the respective type. See
`libwebsockets_broadcast` and and handling of `LWS_CALLBACK_BROADCAST`.

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

```lua
websocket:broadcast('all echo hello')
```

Broadcasts data to all websockets of the same protocol. Behaves like `libwebsockets_broadcast`.

### websocket:get_socket_fd()

Returns the websocket's socket fd. Useful when using other event loop,
e.g. lua-ev.

### websocket:close(reason)

Closes the websocket with the optional integer reason. Behaves like `libwebsockets_close_and_free_session`.
