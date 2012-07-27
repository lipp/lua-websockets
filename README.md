# About

A Lua binding for [libwebsockets](http://git.warmcat.com/cgi-bin/cgit/libwebsockets). 

# Build

```shell 
git clone git://github.com/lipp/lua-websockets.git
cd lua-websockets
luarocks make rockspecs/lua-websockets-scm-1.rockspec 
```

# Usage

See test-server.lua, which is the Lua equivalent to the test-server.c example from libwebsockets.

```shell
lua test-server/test-server.lua test-server/ 
```
run from cloned repo directory.
Connect with one or more browser windows on localhost:8002 /
127.0.0.1:8002 and enjoy.

## Simple echo server
This is the basic echo server. It uses libwebsocket's built in "event-loop" (via `context:service`).
Connect to it e.g. from Javascript with `ws = new WebSocket('ws://127.0.0.1:8002','echo');`. The server does not handle HTTP requests though. If you want to handle HTTP, see on_http callback.

```lua
-- load module
local websockets = require'websockets'
-- this is the callback which is called, whenever a new client connects.
-- ws is a new websocket instance
local echo_cb = function(ws)
      	      -- on_receive is called whenever data has been received from client
      	      ws:on_receive(function(ws,data)
			-- write/echo back the data
      	      		ws:write(data,websockets.WRITE_TEXT)
      	      end)
end
local context = websockets.context({
      port = 8080,
      protocols = {
      		echo = echo_cb
      }
})
-- use the libwebsocket loop
while true do
      context:service(100000)
end   
```

## On HTTP support
libwebsockets (and thus lua-webscokets) is designed for providing a
websockets API. The means for handle HTTP are very limited and
inconvient and mainly for providing self-containing tests/examples. If
you are looking for a feature rich webserver framework, have a look at
[orbit](http://keplerproject.github.com/orbit/) or others. 

It is no problem to work with a "normal" webserver and lua-websockets 
side by side (but on different ports!), since websockets are not subject of the 
'Same origin policy'.

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
		  ['echo'] = echo_cb,
		  ['super-test'] = super_test_cb
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
to be polled (sockets) with `fd` as argument. Useful for custom event handling, e.g. with lua-ev.

The `on_del_fd` callback gets called whenever a `fd` is not
used any more (can be removed from polling). Useful for custom event handling, e.g. with lua-ev.

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
websockets.WRITE_XYZ or nil (defaults to WRITE_TEXT). Behaves like `libwebsocket_write`.

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
