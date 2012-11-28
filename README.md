# About
A Lua binding for [libwebsockets](http://git.warmcat.com/cgi-bin/cgit/libwebsockets) which provides easy websocket server functionality for Lua. It works standalone (using the built-in event-loop) or it can be employed together with event frameworks like [lua-ev](https://github.com/brimworks/lua-ev) by providing hooks to get access to raw filedescriptors.

Whereas it is very easy to provide a websockets message oriented server via libwebsockets (and thus lua-webscokets), its means for handle HTTP are very limited and rather inconvient and mainly for providing self-containing tests/examples. If you are looking for a feature rich webserver framework, have a look at [orbit](http://keplerproject.github.com/orbit/) or others. 

It is no problem to work with a "normal" webserver and lua-websockets side by side (but on different ports!), since websockets are not subject of the 'Same origin policy'.

# Usage
## Example 1: Simple echo server
This implements a basic echo server via Websockets protocol. Once you are connected with the server, all messages you send will be returned ('echoed') by the server immediately.

```lua
-- load module
local websockets = require'websockets'

-- you always need one context object
local context = websockets.context({
  -- listen on port 8080
  port = 8080,
  -- the protocols field holds
  --   key: protocol name
  --   value: callback on new connection
  protocols = {
    -- this callback is called, whenever a new client connects.
    -- ws is a new websocket instance
    echo = function(ws)
      -- on_receive is called whenever data / a message 
      -- has been received from the client
      ws:on_receive(function(ws,data)
        -- write/echo back the data
        ws:write(data,websockets.WRITE_TEXT)
      end)
    end
  }
})

-- use the libwebsocket loop to dispatch events.
while true do
   context:service(100000)
end   
```

There are some important points to notice here:
  - You need to load the websockets module via `require`
  - You have to define one context which describes 'global' attributes and behaviour
  - At least one protocol must be defined ('echo' in this example).
    The callback specified is called for every new connection. Inside you may register a callback,
    which is called whenever data is received.
  - You must somehow kickstart the service loop.
    In this example libwebsocket's built in "event-loop" is used (via `context:service`).

Connect to the from Javascript (e.g. chrome's debugging console) like this:
```Javascript
var echoWs = new WebSocket('ws://127.0.0.1:8002','echo');
```
In opposite to test-server.lua the server does not handle HTTP requests though. If you want to handle HTTP too, implement the context's `on_http` callback.

## Example 2: test-server.lua
To see a complete working example, have a look at test-server.lua, which is the Lua equivalent to the test-server.c example from the libwebsockets package. If you have downloaded or cloned the lua-websockets package, you can start the test-server.lua like this:

```shell
lua test-server/test-server.lua test-server/ 
```
Now the test-server is running and awaiting clients to connect.
You can connect with one or more browser windows on http://localhost:8002 or http://127.0.0.1:8002 and play around.

# API
lua-websockets' API tries to be as close to the underlying libwebsockets as possible. In most cases the original libwebsockets documentation is more detailed then this one. Therefor a mapping between the orginal C API and lua-websockets is gven:

<table>
  <tr><th>lua-websockets</th><th>C API</th></tr>
  <tr><td>websockets.context</td><td>libwebsocket_context_create<td></tr>
  <tr><td>websockets.context</td><td>libwebsocket_context_create<td></tr>
</table>

## websockets table

The websockets table is the modules root table/namespace.

### websockets.WRITE_TEXT

To be used as type with websocket:write(data,type)

### websockets.WRITE_BINARY

To be used as type with websocket:write(data,type)

### websockets.context(config)

```lua
local context = websockets.context({
   -- the port the websockets server listens for incoming connections
   port = 8001,
   -- a callback for http requests
   on_http = handle_http,
   -- an (optional) callback for a new fd to service; only
   -- relevant when using external event-loop
   on_add_fd = register_fd, --function, optional
   -- a (optional) callback for a fd which is no more to service; only
   -- relevant when using external event-loop
   on_del_fd = unregister_fd, --function, optional
   -- a map of protocol names and callbacks for this protocol
   -- at least one protocol must be provided.
   protocols = {
     ['echo'] = echo_cb,
     ['super-test'] = super_test_cb
   },
   -- a (optional) string desrcibing the interface to listen on
   interf = 'eth0',
   -- a (optional) string specifying the path to the ssl certificate
   ssl_cert_path, 
   -- a (optional) string specifying the path to the ssl private key
   ssl_private_key_path,
   gid, --int, optional
   uid, --int, optional
   options --int, optional
})
```

## context methods

A context can be created via websockets.context(...).

### context:destroy()
```lua
context:destroy()
```
Destroys a context. Behaves like `libwebsocket_context_destroy`.
The context's __gc metamethod calls destroy if necessary (garbage collection), so in general this is not required to be called explicitly. 

### context:service(timeout_ms)
```lua
while true do
      context:service(2000)
end
```
Services the context's outstanding io on ALL open fds. Behaves like
`libwebsocket_service`. The integer `timeout_ms` value defaults to 0
(no timeout, return immediatly after outstanding IO was performed).

### context:service_fd(fd,revent1,revent2,...)
```lua
-- example to employ service_fd with lua-ev.
local context
context = websockets.context{
  on_add_fd = function(fd)
    local io = ev.IO.new(function(_,_,revents)
      -- specifically handle THIS fd with THIS revents               
      context:service_fd(fd,revents)
    end,fd,ev.READ)
    io:start(ev.Loop.default)
  end,
   ...
}
```
Services the fd's specified revent related actions. Behaves like
`libwebsocket_service_fd`. At least one revent must be
specified. Multiple revents are bit OR'ed. The revents are not
interpreted by lua-websockets layer but directly forwarded to
`libwebsocket_service_fd`.

### context:broadcast(protocol_name,data)
```lua
context:broadcast('echo','hello')
```
Broadcasts data for all open websockets of kind `protocol_name`. Behaves
like `libwebsockets_broadcast`. Both parameters are strings. The
behavior of individual websockets may be changed with websocket:on_broadcast.

### context:canonical_hostname()
```lua
local hostname = context:canonical_hostname()
```
Returns the context's canonical hostname (machine name). Behaves like
`libwebsocket_canonical_hostname`.

### context:fork_service_loop()
Behaves like `libwebsockets_fork_service_loop`.

## websocket methods

A websocket can not be explicitly created, instead it gets passed to
various callback methods, e.g. the protocol connect callback handler
(see websockets.context)

### websocket:write(data,write_type)
```lua
websocket:write('hello',websockets.WRITE_TEXT)
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
websocket:on_broadcast(function(ws,data) -- intercept broadcast
  ws:write(data..'hello',websockets.WRITE_TEXT)
end)
```
Registers an on_broadcast callback on the websocket if
callback_or_mode is a function. If callback_or_mode is int
(websockets.WRITE_XYZ, any incoming braodcast events forward the message with the respective type. See
`libwebsockets_broadcast` and and handling of `LWS_CALLBACK_BROADCAST`.

### websocket:on_receive(callback)
```lua
websocket:on_receive(function(ws,data)
  ws:write(data,websockets.WRITE_TEXT)
end)
```
Registers a receive handler for incoming data. The callback gets the
websocket and the data passed as arguments.

### websocket:broadcast(data)
```lua
ws:broadcast('all echo hello')
```
Broadcasts data to all websockets of the same protocol. Behaves like `libwebsockets_broadcast`.

### websocket:get_socket_fd()
Returns the websocket's socket fd. Useful when using other event loop,
e.g. lua-ev.

### websocket:close(reason)
Closes the websocket with the optional integer reason. Behaves like `libwebsockets_close_and_free_session`.

### websocket:get_peer_addresses()
```lua
local name,rip = ws:get_peer_addresses()
```
Behaves like `libwebsocket_get_peer_addresses`.

### websocket:remaining_packet_payload()
```lua
local remaining = ws:remaining_packet_payload()
```
Behaves like `libwebsocket_remaining_packet_payload`.

### websocket:rx_flow_control(enable)
```lua
ws:rx_flow_control(true)
```
Enables / disables rx flow control. Behaves like `libwebsocket_remaining_packet_payload`.

### websocket:serve_http_file(filename,content_type)
```lua
ws:serve_http_file('./index.html','text/html')
```
Serves a file from filesystem. Can only be called from within
context's on_http callback. Behaves like
`libwebsockets_serve_http_file`.

# Install

## Install lua-websockets
[libwebsockets](http://git.warmcat.com/cgi-bin/cgit/libwebsockets) must be installed before lua-websockets can be installed. After having the _latest_ libwebsockets in place, lua-websockets can be installed. At the bottom of the page there are some instruction how to build libwebsockets for Unix and OSX. The prefered way is to install a tagged version from luarocks repository:

```shell 
$ sudo luarocks install lua-websockets
```

If you need the most recent version from github, you have to clone and perform a luarocks make:

```shell 
$ git clone git://github.com/lipp/lua-websockets.git
$ cd lua-websockets
$ luarocks make rockspecs/lua-websockets-scm-1.rockspec 
```

## Build and install libwebsockets

### Build libwebsockets with Ubuntu
This most problably applies to most other Linuxes.
Download the recent version and unpack. cd into the unpacked directory. 
```shell 
$ ./configure
$ make
$ sudo make install
```

### Build with OSX
You need to install: 
  - autoconf
  - automake
  - libtool

I was successfull using homebrew and using macports.
Then do the following.
```shell 
$ autoreconf
$ glibtoolize
$ ./configure --enable-nofork
$ make
$ sudo make install
```

