/*
  Lua binding for libwebsockets.

  Copyright (c) 2011 by Gerhard Lipp <gelipp@gmail.com>
  
  License see accompanying COPYRIGHT file.
*/

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <libwebsockets.h>

#include <string.h>
#include <assert.h>
#include <stdio.h>

/* Some id string for the userdata meta tables */
#define WS_CONTEXT_META "websockets.ctx"
#define WS_WEBSOCKET_META "websockets.ws"

/* Currently not supported */
#define MAX_EXTENSIONS 1

/* An arbitrary number which must not conflict 
   with any value of libwebsocket_write_protocol 
*/
#define LUAWS_FORWARD -1

/* The maximum number of protocols. protocol_trampolines must have
   all valid entries (see PROTOCOL_TRAMPOLINE(i)).   
*/
#define MAX_PROTOCOLS 10 

/* Lua userdata for (connected) websocket.
   Is created in augmented_call with reason = LWS_CALLBACK_ESTABLISHED.
*/
struct websocket {
  lua_State *L;
  struct libwebsocket_context *context;
  struct libwebsocket *wsi;
  int broadcast_mode;
  int closed_function_ref;
  int receive_function_ref;
  int broadcast_function_ref;
  int server_writeable_function_ref;
  int ref;
};

/* Helper struct for each callback_protocol. 
   The respective callback_protocol (declared by PROTOCOL_TRAMPOLINE)
   passes in the corresponding struct augmented_args.
*/
struct augmented_args {
  lua_State *L;
  struct context *lcontext;
  int protocol_index;
};


/* An array of struct augmented_args, which is associated
   with to the respective protocol_trampoline index.
*/
struct augmented_args augmented_args_array[MAX_PROTOCOLS];


/* The function which gets called by the respective protocol_trampoline_X.
   The respective struct augmented_args will be passed in, to 
   allow protocol specific behaviour (call the right (Lua) callbacks).
*/
static int augmented_callback(struct libwebsocket_context * context,
                              struct libwebsocket *wsi,
                              enum libwebsocket_callback_reasons reason, void *user,
                              void *in, size_t len, struct augmented_args);


/* MACRO for defining protocol_trampoline_X trampoline function. */
#define PROTOCOL_TRAMPOLINE(PROT_INDEX)                                 \
  int protocol_trampoline_##PROT_INDEX(struct libwebsocket_context * context, \
                                       struct libwebsocket *wsi,        \
                                       enum libwebsocket_callback_reasons reason, void *user, \
                                       void *in, size_t len) {          \
    return augmented_callback(context, wsi, reason, user,               \
                              in, len, augmented_args_array[PROT_INDEX]); \
  }                                                                     \
  
/* Define MAX_PROTOCOLS trampoline functions */
PROTOCOL_TRAMPOLINE(0);
PROTOCOL_TRAMPOLINE(1);
PROTOCOL_TRAMPOLINE(2);
PROTOCOL_TRAMPOLINE(3);
PROTOCOL_TRAMPOLINE(4);
PROTOCOL_TRAMPOLINE(5);
PROTOCOL_TRAMPOLINE(6);
PROTOCOL_TRAMPOLINE(7);
PROTOCOL_TRAMPOLINE(8);
PROTOCOL_TRAMPOLINE(9);

/* Insert the functions to an array to make them available 
   programatically.
*/
void* protocol_trampolines[MAX_PROTOCOLS] = {
  protocol_trampoline_0,
  protocol_trampoline_1,
  protocol_trampoline_2,
  protocol_trampoline_3,
  protocol_trampoline_4,
  protocol_trampoline_5,
  protocol_trampoline_6,
  protocol_trampoline_7,
  protocol_trampoline_8,
  protocol_trampoline_9
};

/* The Lua userdata for the websocket_context.
   Created by function context_create (called by function context).
*/
struct context {
  lua_State *L;
  int http_function_ref;
  int add_fd_function_ref;
  int del_fd_function_ref;
  int set_mode_function_ref;
  int clear_mode_function_ref;
  int established_function_refs[MAX_PROTOCOLS];
  struct libwebsocket_context *context;
  int destroyed;
  int protocol_count;
  char protocol_names[MAX_PROTOCOLS][100];
  struct libwebsocket_protocols protocols[MAX_PROTOCOLS];
  struct libwebsocket_extension extensions[MAX_EXTENSIONS];
};

/* Creates the Lua userdata of type context with metatable
   and default values.
*/
static struct context *context_create(lua_State *L) {
  int i;
  struct context *user = lua_newuserdata(L, sizeof(struct context));;
  memset(user, 0, sizeof(struct context));
  user->L = L;
  user->http_function_ref = LUA_REFNIL;
  user->add_fd_function_ref = LUA_REFNIL;
  user->del_fd_function_ref = LUA_REFNIL;
  for(i = 0; i < MAX_PROTOCOLS; ++i) {
    user->established_function_refs[i] = LUA_REFNIL;
  }
  luaL_getmetatable(L, WS_CONTEXT_META);
  lua_setmetatable(L, -2);
  return user;
}

/* Creates the Lua userdata of type context  with metatable
   and default values.   
*/
static struct websocket *websocket_create(lua_State *L,struct libwebsocket_context *context, struct libwebsocket* wsi) {
  struct websocket *user = lua_newuserdata(L, sizeof(struct websocket));;
  memset(user, 0, sizeof(struct websocket));
  user->wsi = wsi;
  user->L = L;
  user->context = context;
  luaL_getmetatable(L, WS_WEBSOCKET_META);
  lua_setmetatable(L, -2);  
  user->ref = luaL_ref(L, LUA_REGISTRYINDEX);
  user->closed_function_ref = LUA_REFNIL;
  user->receive_function_ref = LUA_REFNIL;
  user->broadcast_function_ref = LUA_REFNIL;
  user->server_writeable_function_ref = LUA_REFNIL;
  return user;
}

/* Deletes the websocket userdata and unrefs all
   Lua callbacks.
*/
static void websocket_delete(struct websocket *user) {
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->ref);
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->closed_function_ref);
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->receive_function_ref);
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->broadcast_function_ref);
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->server_writeable_function_ref);
}


/* This callback is called for all protocols.
   
 */
static int augmented_callback(struct libwebsocket_context * context,
                              struct libwebsocket *wsi,
                              enum libwebsocket_callback_reasons reason, void *user,
                              void *in, size_t len, struct augmented_args args) {
  lua_State *L = args.L;
  if(reason == LWS_CALLBACK_ESTABLISHED) {
    struct websocket * ws = websocket_create(L, context, wsi);
    *(struct websocket **)user = ws;
    /* push Lua established callback function on stack */
    lua_rawgeti(L, LUA_REGISTRYINDEX, args.lcontext->established_function_refs[args.protocol_index]);  
    if(!lua_isfunction(L, -1)) {
      lua_pop(L, 1);
      return 0;
    }
    /* first arguments is websocket (userdata) */
    lua_rawgeti(L, LUA_REGISTRYINDEX, ws->ref);
    lua_call(L, 1, 0);
    return 0;
  }
  else if(reason == LWS_CALLBACK_CLOSED) {
    struct websocket * ws = *(struct websocket **)user;
    lua_rawgeti(L, LUA_REGISTRYINDEX, ws->closed_function_ref);  
    if(lua_isfunction(L, -1)) {
      lua_rawgeti(L, LUA_REGISTRYINDEX, ws->ref);  
      lua_call(L, 1, 0);
    }
    websocket_delete(ws);
    lua_pop(L, 1);
    return 0;
  }
  else if(reason == LWS_CALLBACK_RECEIVE) {   
    struct websocket * ws = *(struct websocket **)user;    
    lua_rawgeti(L, LUA_REGISTRYINDEX, ws->receive_function_ref);  
    if(!lua_isfunction(L, -1)) {
      lua_pop(L, 1);
      return 0;
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, ws->ref);  
    /* push data */
    assert(len >= 0 && in != NULL);
    lua_pushlstring(L,in,len);    
    lua_call(L, 2, 0);
    return 0;
  }
  else if(reason == LWS_CALLBACK_BROADCAST) {
    struct websocket * ws = *(struct websocket **)user;    
    if(ws->broadcast_mode == LUAWS_FORWARD) {
      lua_rawgeti(L, LUA_REGISTRYINDEX, ws->broadcast_function_ref);
      lua_rawgeti(L, LUA_REGISTRYINDEX, ws->ref);
      assert(len >= 0 && in != NULL);
      lua_pushlstring(L,in,len);    
      lua_call(L, 2, 0);
      return 0;
    }
    else {
      libwebsocket_write(ws->wsi, in, len, ws->broadcast_mode);
    }
  }
  else if(reason == LWS_CALLBACK_HTTP) {    
    struct websocket * ws = websocket_create(L, context, wsi);
    int argc;    
    lua_rawgeti(L, LUA_REGISTRYINDEX, args.lcontext->http_function_ref);      
    if(!lua_isfunction(L, -1)) {
      lua_pop(L, 1);
      return 0;
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, ws->ref);  
    /* push uri */
    lua_pushstring(L,in);
    lua_call(L, 2, 0);
    websocket_delete(ws);
    return 0;
  }
  else if(reason == LWS_CALLBACK_ADD_POLL_FD || reason == LWS_CALLBACK_DEL_POLL_FD) {
    if(reason == LWS_CALLBACK_ADD_POLL_FD) {
      lua_rawgeti(L, LUA_REGISTRYINDEX, args.lcontext->add_fd_function_ref);  
    }
    else {
      lua_rawgeti(L, LUA_REGISTRYINDEX, args.lcontext->del_fd_function_ref);  
    }
    if(!lua_isfunction(L, -1)) {
      lua_pop(L, 1);
      return 0;
    }
    /* push fd */
    lua_pushnumber(L,(int)(user));
    lua_call(L, 1, 0);
    return 0;
  }
  else if(reason == LWS_CALLBACK_SET_MODE_POLL_FD || reason == LWS_CALLBACK_SET_MODE_POLL_FD) {
    if(reason == LWS_CALLBACK_SET_MODE_POLL_FD) {
      lua_rawgeti(L, LUA_REGISTRYINDEX, args.lcontext->set_mode_function_ref);  
    }
    else {
      lua_rawgeti(L, LUA_REGISTRYINDEX, args.lcontext->clear_mode_function_ref);  
    }
    if(!lua_isfunction(L, -1)) {
      lua_pop(L, 1);
      return 0;
    }
    /* push fd */
    lua_pushnumber(L,(int)(user));
    /* push modification POLLIN or POLLOUT */
    lua_pushnumber(L,len);
    lua_call(L, 2, 0);
    return 0;
  }
  return 0;
}

static int context(lua_State *L) {
  int port = 0;
  const char* interf = NULL;
  const char* ssl_cert_filepath = NULL;
  const char* ssl_private_key_filepath = NULL;
  int gid = -1;
  int uid = -1;
  unsigned int options = 0;
  struct context *user = context_create(L);
  luaL_checktype(L, 1, LUA_TTABLE);
  /* read port table entry */
  lua_getfield(L, 1, "port");
  port = luaL_optint(L, -1, 0);    
  lua_pop(L, 1);

  /* read gid table entry */
  lua_getfield(L, 1, "gid");
  gid = luaL_optint(L, -1, -1);    
  lua_pop(L, 1);

  /* read uid table entry */
  lua_getfield(L, 1, "uid");
  uid = luaL_optint(L, -1, -1);    
  lua_pop(L, 1);

  /* read  table entry */
  lua_getfield(L, 1, "options");
  options = luaL_optint(L, -1, 0);    
  lua_pop(L, 1);

  /* read interf table entry */
  lua_getfield(L, 1, "interf");
  interf = luaL_optstring(L, -1, NULL);    
  lua_pop(L, 1);

  /* read ssl_cert_filepath table entry */
  lua_getfield(L, 1, "ssl_cert_filepath");
  ssl_cert_filepath = luaL_optstring(L, -1, NULL);    
  lua_pop(L, 1);

  /* read ssl_private_key_filepath table entry */
  lua_getfield(L, 1, "ssl_private_key_filepath");
  ssl_private_key_filepath = luaL_optstring(L, -1, NULL);    
  lua_pop(L, 1);

  /* get (unique) http handler */
  lua_getfield(L, 1, "on_http");
  user->http_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);

  /* push add_fd and store ref */
  lua_getfield(L, 1, "on_add_fd");
  user->add_fd_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  
  /* push remove_fd and store ref */
  lua_getfield(L, 1, "on_del_fd");
  user->del_fd_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);

  user->protocols[0].name = "http-only";
  user->protocols[0].callback = protocol_trampoline_0;
  augmented_args_array[0].L = L;
  augmented_args_array[0].protocol_index = 0;
  augmented_args_array[0].lcontext = user;
  user->protocol_count = 1;

  /* push protocols table on top */
  lua_getfield(L, 1, "protocols");
  if(lua_istable(L, -1)) {
    lua_pushvalue(L, 1);   
    lua_setfenv(L, -3);
    
    /* nil is top (-1) for starting lua_next with 'start' key */
    lua_pushnil(L);
    
    /* lua_next pushes key at -2 and value at -1 (top)  */
    while(user->protocol_count < MAX_PROTOCOLS && lua_next(L, -2) != 0) {
      /* read name */
      const int n = user->protocol_count;
      strcpy(user->protocol_names[n], luaL_checkstring(L, -2));
      user->protocols[n].name = user->protocol_names[n];
      /* lua protocol callback function lies on top */ 
      user->established_function_refs[n] = luaL_ref(L, LUA_REGISTRYINDEX);

      user->protocols[n].callback = protocol_trampolines[n];
      augmented_args_array[n].L = L;
      augmented_args_array[n].protocol_index = n;
      augmented_args_array[n].lcontext = user;
      /* the session user pointer will be initialized in the callback with reason LWS_ESTABLISHED */
      user->protocols[n].per_session_data_size = sizeof(struct websocket *); // will hold a luaL_ref to the websocket table

      ++user->protocol_count;
    }
    /* pop protocols table on top */
    lua_pop(L, 1);
  }
  user->context = libwebsocket_create_context(port, interf, user->protocols, user->extensions, ssl_cert_filepath, ssl_private_key_filepath, gid, uid, options);  

  if(user->context == NULL) {
    luaL_error(L, "websocket could not create context");
  }
  return 1;
}

static struct context * checked_context(lua_State *L) {
  struct context *user = (struct context *)luaL_checkudata(L, 1, WS_CONTEXT_META);  
  if(user->destroyed) {
    luaL_error(user->L, "websocket context destroyed");
  }  
  return user;
}

static int context_canonical_hostname(lua_State *L) {
  struct context *user = checked_context(L);
  lua_pushstring(L, libwebsocket_canonical_hostname(user->context));
  return 1;
}

static int context_destroy(lua_State *L) {  
  int n = 0;
  struct context *user = checked_context(L);
  if(!user->destroyed) {
    if(user->context != NULL) {
      libwebsocket_context_destroy(user->context);
    }
    luaL_argcheck(L, user, 1, "websocket context expected");
    luaL_unref(L, LUA_REGISTRYINDEX, user->add_fd_function_ref);
    luaL_unref(L, LUA_REGISTRYINDEX, user->del_fd_function_ref);
    while(user->established_function_refs[n]) {
      luaL_unref(L, LUA_REGISTRYINDEX, user->established_function_refs[n]);
      ++n;
    }
    luaL_unref(L, LUA_REGISTRYINDEX, user->http_function_ref);
    user->destroyed = 1;
  }
  return 0;
}

static int context_service_fd(lua_State *L) {  
  struct context *user = checked_context(L);
  int fd = lua_tointeger(L, 2); 
  int i;
  struct pollfd pfd;
  pfd.fd = fd;
  pfd.revents = 0;
  for(i = 3; i <= lua_gettop(L); ++i) {
    pfd.revents |= lua_tointeger(L, i);
  }
  lua_pushinteger(L, libwebsocket_service_fd(user->context, &pfd));
  return 1;
}

static struct websocket * checked_websocket(lua_State *L) {  
  struct websocket *user = (struct websocket *)luaL_checkudata(L, 1, WS_WEBSOCKET_META);  
  return user;
}

#ifndef LWS_NO_FORK
static int context_fork_service_loop(lua_State *L) {
  struct context *user = checked_context(L);  
  int n = libwebsockets_fork_service_loop(user->context);
  lua_pushinteger(user->L, n);
  return 1;
}
#endif

static int context_tostring(lua_State *L) {  
  struct context *user = checked_context(L);
  lua_pushfstring(L, "context %p", user);
  return 1;
}

static int websocket_tostring(lua_State *L) {  
  struct websocket *user = checked_websocket(L);
  lua_pushfstring(L, "websocket %p", user);
  return 1;
}
static int websocket_close(lua_State *L) {
  struct websocket *user = checked_websocket(L);
  int reason = luaL_optint(L, 2, LWS_CLOSE_STATUS_NOSTATUS);
  libwebsocket_close_and_free_session(user->context, user->wsi, reason);
  return 0;
}

static int websocket_write(lua_State *L) {
  struct websocket *user = checked_websocket(L);
  size_t len;
  const unsigned char *data = (unsigned char*) lua_tolstring(L, 2, &len);
  const int padded_len = LWS_SEND_BUFFER_PRE_PADDING + len + LWS_SEND_BUFFER_POST_PADDING; 
  unsigned char padded[padded_len];
  int protocol = luaL_optint(L, 3, LWS_WRITE_TEXT);
  int n;
  memcpy(padded + LWS_SEND_BUFFER_PRE_PADDING, data, len);
  n = libwebsocket_write(user->wsi, padded + LWS_SEND_BUFFER_PRE_PADDING, len, protocol);
  lua_pushinteger(L, n);
  return 1;
}

static int context_broadcast(lua_State *L) {
  struct context *user = checked_context(L);
  size_t len;
  const char *protocol_name = luaL_checkstring(L, 2);
  const unsigned char *data = (unsigned char*) lua_tolstring(L, 3, &len);
  const int padded_len = LWS_SEND_BUFFER_PRE_PADDING + len + LWS_SEND_BUFFER_POST_PADDING; 
  unsigned char padded[padded_len];
  int n;
  int i;
  struct libwebsocket_protocols *protocol = NULL;
  for(i = 0; i < user->protocol_count; ++i) {
    if(strcmp(user->protocol_names[i],protocol_name) == 0) {
      protocol = &user->protocols[i];
      break;
    }
  }
  if(protocol == NULL) {
    luaL_error(L, "websocket unknown protocol");
  }
  memcpy(padded + LWS_SEND_BUFFER_PRE_PADDING, data, len);
  n = libwebsockets_broadcast(protocol, padded + LWS_SEND_BUFFER_PRE_PADDING, len);
  lua_pushinteger(L, n);
  return 1;
}

static int websocket_broadcast(lua_State *L) {
  struct websocket *user = checked_websocket(L);
  size_t len;
  const unsigned char *data = (unsigned char*) lua_tolstring(L, 2, &len);
  const int padded_len = LWS_SEND_BUFFER_PRE_PADDING + len + LWS_SEND_BUFFER_POST_PADDING; 
  unsigned char padded[padded_len];
  int n;
  memcpy(padded + LWS_SEND_BUFFER_PRE_PADDING, data, len);
  n = libwebsockets_broadcast(libwebsockets_get_protocol(user->wsi), padded + LWS_SEND_BUFFER_PRE_PADDING, len);
  lua_pushinteger(L, n);
  return 1;
}

static int websocket_serve_http_file(lua_State *L) {  
  struct websocket *user = checked_websocket(L);
  const char * filename = luaL_checkstring(L, 2);
  const char * content_type = luaL_checkstring(L, 3);
  lua_pushinteger(L, libwebsockets_serve_http_file(user->wsi, filename, content_type));
  return 1;
}

static int websocket_on_closed(lua_State *L) {
  struct websocket *user = checked_websocket(L);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  user->closed_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return 0;
}

static int websocket_on_receive(lua_State *L) {
  struct websocket *user = checked_websocket(L);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  user->receive_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return 0;
}

static int websocket_on_broadcast(lua_State *L) {
  struct websocket *user = checked_websocket(L);
  /* push add_fd and store ref */
  switch(lua_type(L, -1)) {
  case LUA_TNUMBER:
    user->broadcast_mode = lua_tointeger(L, -1);
    break;
  case LUA_TFUNCTION:
    user->broadcast_mode = LUAWS_FORWARD;
    user->broadcast_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    break;
  default:
    luaL_error(L, "websocket on_broadcast value not supported");
    break;
  }
  return 0;
}

static int websocket_on_server_writeable(lua_State *L) {
  struct websocket *user = checked_websocket(L);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  user->server_writeable_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return 0;
}

static int websocket_get_socket_fd(lua_State *L) {  
  struct websocket *user = checked_websocket(L);
  lua_pushinteger(L, libwebsocket_get_socket_fd(user->wsi));
  return 1;
}

static int websocket_service(lua_State *L) {  
  struct websocket *user = checked_websocket(L);
  int fd = libwebsocket_get_socket_fd(user->wsi);
  int i;
  struct pollfd pfd;
  pfd.fd = fd;
  pfd.revents = 0;
  for(i = 2; i < lua_gettop(L); ++i) {
    pfd.revents |= lua_tointeger(L, i);
  }
  lua_pushinteger(L, libwebsocket_service_fd(user->context, &pfd));
  return 1;
}

static int websocket_get_peer_addresses(lua_State *L) {  
  char name[100];
  char rip[100];
  struct websocket *user = checked_websocket(L);  
  int fd = libwebsocket_get_socket_fd(user->wsi);
  libwebsockets_get_peer_addresses(fd, name, sizeof(name), rip, sizeof(rip));  
  lua_pushstring(L, name);
  lua_pushstring(L, rip);
  return 2;
}

static int websocket_remaining_packet_payload(lua_State *L) {  
  struct websocket *user = checked_websocket(L);  
  lua_pushnumber(L, libwebsockets_remaining_packet_payload(user->wsi));
  return 1;
}

static int websocket_rx_flow_control(lua_State *L) {  
  struct websocket *user = checked_websocket(L);
  int enable = luaL_checkint(L, 2);
  int n = libwebsocket_rx_flow_control(user->wsi, enable);
  lua_pushinteger(L, n);
  return 1;
}

static int context_service(lua_State *L) {
  struct context *user = checked_context(L);
  int timeout_ms = luaL_optint(L, 2, 0);
  lua_pop(L,1);
  int n = libwebsocket_service(user->context, timeout_ms);
  lua_pushinteger(user->L, n);
  return 1;
}

static const struct luaL_Reg module_methods [] = {
  {"context",context},
  {NULL,NULL}
};

static const struct luaL_Reg context_methods [] = {
  {"destroy",context_destroy},
  {"__gc",context_destroy},
#ifndef LWS_NO_FORK
  {"fork_service_loop",context_fork_service_loop},
#endif
  {"service",context_service},
  {"service_fd",context_service_fd},
  {"canonical_hostname",context_canonical_hostname},
  {"broadcast",context_broadcast},
  {"__tostring",context_tostring},
  {NULL,NULL}
};

static const struct luaL_Reg websocket_methods [] = {
  {"serve_http_file",websocket_serve_http_file},
  {"get_socket_fd",websocket_get_socket_fd},
  {"get_peer_addresses",websocket_get_peer_addresses},
  {"remaining_packet_payload",websocket_remaining_packet_payload},
  {"service",websocket_service},
  {"rx_flow_control",websocket_rx_flow_control},
  {"write",websocket_write},
  {"on_closed",websocket_on_closed},
  {"on_receive",websocket_on_receive},
  {"on_broadcast",websocket_on_broadcast},
  {"on_server_writeable",websocket_on_server_writeable},
  {"broadcast",websocket_broadcast},
  {"close",websocket_close},
  {"__tostring",websocket_tostring},
  {NULL,NULL}
};

struct constant {
  const char *name;
  int value;
};

struct constant constants [] = {
  {"SERVER_OPTIONS_DEFEAT_CLIENT_MASK",LWS_SERVER_OPTION_DEFEAT_CLIENT_MASK},
  {"SERVER_OPTION_REQUIRE_VALID_OPENSSL_CLIENT_CERT",LWS_SERVER_OPTION_REQUIRE_VALID_OPENSSL_CLIENT_CERT},
  {"WRITE_TEXT",LWS_WRITE_TEXT},
  {"WRITE_BINARY",LWS_WRITE_BINARY},
  {"WRITE_CONTINUATION",LWS_WRITE_CONTINUATION},
  {"WRITE_HTTP",LWS_WRITE_HTTP},
  {"WRITE_CLOSE",LWS_WRITE_CLOSE},
  {"WRITE_PING",LWS_WRITE_PING},
  {"WRITE_PONG",LWS_WRITE_PONG},
  {"WRITE_NO_FIN",LWS_WRITE_NO_FIN},
  {"WRITE_CLIENT_IGNORE_XOR_MASK",LWS_WRITE_CLIENT_IGNORE_XOR_MASK},
  {"POLLIN",POLLIN},
  {"POLLERR",POLLERR},
  {"POLLOUT",POLLOUT},
  {"POLLHUP",POLLHUP},
  {NULL,0}
};

static void register_constants(lua_State *L, struct constant *constants) {
  while(constants->name) {
    lua_pushinteger(L, constants->value);
    lua_setfield(L, -2, constants->name);
    ++constants;
  }
}

int luaopen_websockets(lua_State *L) {
  luaL_newmetatable(L, WS_CONTEXT_META);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, context_methods);
  luaL_newmetatable(L, WS_WEBSOCKET_META);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, websocket_methods);
  luaL_register(L, "websockets", module_methods);
  register_constants(L, constants);
  return 1;
}
