#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "libwebsockets.h"
#include <string.h>
#include <assert.h>
#include <stdio.h>

static void stackDump (const char* bla, lua_State *L) {
      int i;
      int top = lua_gettop(L);
      printf("%s ",bla);
      for (i = 1; i <= top; i++) {  /* repeat for each level */
        int t = lua_type(L, i);
        switch (t) {
    
          case LUA_TSTRING:  /* strings */
            printf("`%s'", lua_tostring(L, i));
            break;
    
          case LUA_TBOOLEAN:  /* booleans */
            printf(lua_toboolean(L, i) ? "true" : "false");
            break;
    
          case LUA_TNUMBER:  /* numbers */
            printf("%g", lua_tonumber(L, i));
            break;
    
          default:  /* other values */
            printf("%s %s", lua_typename(L, t), lua_tostring(L,t));
            break;
    
        }
        printf("  ");  /* put a separator */
      }
      printf("\n");  /* end the listing */
    }

#define WS_CONTEXT_META "luaws.con"
#define WS_WEBSOCKET_META "luaws.ws"
#define MAX_PROTOCOLS 4
#define MAX_EXTENSIONS 4

struct luaws_websocket {
  lua_State *L;
  struct libwebsocket_context *context;
  struct libwebsocket *wsi;
  int http_function_ref;
  int closed_function_ref;
  int receive_function_ref;
  int broadcast_function_ref;
  int server_writeable_function_ref;
  int ref;
};

struct luaws_context_link {
  void *userdata;
  int protocol_index;
};

struct luaws_context {
  lua_State *L;
  int add_fd_function_refs[MAX_PROTOCOLS];
  int del_fd_function_refs[MAX_PROTOCOLS];
  int set_mode_function_refs[MAX_PROTOCOLS];
  int clear_mode_function_refs[MAX_PROTOCOLS];
  int established_function_refs[MAX_PROTOCOLS];
  struct libwebsocket_context *context;
  int destroyed;
  int protocol_count;
  char protocol_names[MAX_PROTOCOLS][100];
  struct libwebsocket_protocols protocols[MAX_PROTOCOLS];
  struct libwebsocket_extension extensions[MAX_EXTENSIONS];
  struct luaws_context_link links[MAX_PROTOCOLS];
};

static struct luaws_context *luaws_context_create(lua_State *L) {
  int i;
  struct luaws_context *user = lua_newuserdata(L, sizeof(struct luaws_context));;
  memset(user, 0, sizeof(struct luaws_context));
  user->L = L;
  for(i = 0; i < MAX_PROTOCOLS; ++i) {
    user->add_fd_function_refs[i] = LUA_REFNIL;
    user->del_fd_function_refs[i] = LUA_REFNIL;
    user->established_function_refs[i] = LUA_REFNIL;
  }
  luaL_getmetatable(L, WS_CONTEXT_META);
  lua_setmetatable(L, -2);
  return user;
}

static struct luaws_websocket *luaws_websocket_create(lua_State *L,struct libwebsocket_context *context, struct libwebsocket* wsi) {
  struct luaws_websocket *user = lua_newuserdata(L, sizeof(struct luaws_websocket));;
  memset(user, 0, sizeof(struct luaws_websocket));
  user->wsi = wsi;
  user->L = L;
  user->context = context;
  luaL_getmetatable(L, WS_WEBSOCKET_META);
  lua_setmetatable(L, -2);  
  user->ref = luaL_ref(L, LUA_REGISTRYINDEX);
  user->http_function_ref = LUA_REFNIL;
  user->closed_function_ref = LUA_REFNIL;
  user->receive_function_ref = LUA_REFNIL;
  user->broadcast_function_ref = LUA_REFNIL;
  user->server_writeable_function_ref = LUA_REFNIL;
  return user;
}

static void luaws_websocket_delete(struct luaws_websocket *user) {
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->ref);
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->http_function_ref);
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->closed_function_ref);
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->receive_function_ref);
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->broadcast_function_ref);
  luaL_unref(user->L, LUA_REGISTRYINDEX, user->server_writeable_function_ref);
}

static int luaws_callback(struct libwebsocket_context * context,
			struct libwebsocket *wsi,
			 enum libwebsocket_callback_reasons reason, void *dyn_user,
			void *in, size_t len, void *user) {
  struct luaws_context_link* link = user;
  struct luaws_context* luaws_user = link->userdata;
  lua_State* L = luaws_user->L;
  printf("context:%p wsi:%p reason:%d session:%p in:%p size:%d user:%p\n", context, wsi, reason, dyn_user, in, len, user);
  if(reason == LWS_CALLBACK_ESTABLISHED) {
    struct luaws_websocket * ws = luaws_websocket_create(L, context, wsi);
    *(struct luaws_websocket **)dyn_user = ws;
    /* push Lua established callback function on stack */
    lua_rawgeti(L, LUA_REGISTRYINDEX, luaws_user->established_function_refs[link->protocol_index]);  
    if(!lua_isfunction(L, -1)) {
      return 0;
    }
    /* first arguments is websocket (userdata) */
    lua_rawgeti(L, LUA_REGISTRYINDEX, ws->ref);
    lua_call(L, 1, 0);
    return 0;
  }
  else if(reason == LWS_CALLBACK_CLOSED) {
    struct luaws_websocket * ws = *(struct luaws_websocket **)dyn_user;
    lua_rawgeti(L, LUA_REGISTRYINDEX, ws->closed_function_ref);  
    if(lua_isfunction(L, -1)) {
      lua_rawgeti(L, LUA_REGISTRYINDEX, ws->ref);  
      lua_call(L, 1, 0);
    }
    luaws_websocket_delete(ws);
    return 0;
  }
  else if(reason == LWS_CALLBACK_HTTP || reason == LWS_CALLBACK_RECEIVE) {
    struct luaws_websocket * ws = *(struct luaws_websocket **)dyn_user;
    int argc;
    if(reason == LWS_CALLBACK_RECEIVE) {
      lua_rawgeti(L, LUA_REGISTRYINDEX, ws->receive_function_ref);  
    }
    else {
      lua_rawgeti(L, LUA_REGISTRYINDEX, ws->http_function_ref);  
    }
    if(!lua_isfunction(L, -1)) {
      return 0;
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, ws->ref);  
    /* push data */
    if(len > 0 && in != NULL) {
      lua_pushlstring(L,in,len);
      argc = 2;
    }
    else {
      argc = 1;
    }
    lua_call(L, argc, 0);
    return 0;
  }
  else if(reason == LWS_CALLBACK_ADD_POLL_FD || reason == LWS_CALLBACK_DEL_POLL_FD) {
    if(reason == LWS_CALLBACK_ADD_POLL_FD) {
      lua_rawgeti(L, LUA_REGISTRYINDEX, luaws_user->add_fd_function_refs[link->protocol_index]);  
    }
    else {
      lua_rawgeti(L, LUA_REGISTRYINDEX, luaws_user->del_fd_function_refs[link->protocol_index]);  
    }
    if(!lua_isfunction(L, -1)) {
      return 0;
    }
    /* push fd */
    lua_pushnumber(L,(int)(dyn_user));
    lua_call(L, 1, 0);
    return 0;
  }
  else if(reason == LWS_CALLBACK_SET_MODE_POLL_FD || reason == LWS_CALLBACK_SET_MODE_POLL_FD) {
    if(reason == LWS_CALLBACK_SET_MODE_POLL_FD) {
      lua_rawgeti(L, LUA_REGISTRYINDEX, luaws_user->set_mode_function_refs[link->protocol_index]);  
    }
    else {
      lua_rawgeti(L, LUA_REGISTRYINDEX, luaws_user->clear_mode_function_refs[link->protocol_index]);  
    }
    if(!lua_isfunction(L, -1)) {
      return 0;
    }
    /* push fd */
    lua_pushnumber(L,(int)(dyn_user));
    /* push modification POLLIN or POLLOUT */
    lua_pushnumber(L,len);
    lua_call(L, 2, 0);
    return 0;
  }
  return 0;
}

static int luaws_context(lua_State *L) {
  int port = 0;
  const char* interf = NULL;
  const char* ssl_cert_filepath = NULL;
  const char* ssl_private_key_filepath = NULL;
  int gid = -1;
  int uid = -1;
  unsigned int options = 0;
  struct luaws_context *user = luaws_context_create(L);
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

    /* push protocols table on top */
    lua_getfield(L, 1, "protocols");    
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushvalue(L, 1);   
    lua_setfenv(L, -3);

    /* nil is top (-1) for starting lua_next with 'start' key */
    lua_pushnil(L);
    /* lua_next pushes key at -2 and value at -1 (top)  */
    while(user->protocol_count < MAX_PROTOCOLS && lua_next(L, -2) != 0) {
      /* read name */
      const int n = user->protocol_count;
      lua_getfield(L, -1, "name");
      strcpy(user->protocol_names[n],luaL_checkstring(L, -1));
      user->protocols[n].name = user->protocol_names[n];
      lua_pop(L, 1);

      /* push add_fd and store ref */
      lua_getfield(L, -1, "on_add_fd");
      user->add_fd_function_refs[n] = luaL_ref(L, LUA_REGISTRYINDEX);

      /* push remove_fd and store ref */
      lua_getfield(L, -1, "on_del_fd");
      user->del_fd_function_refs[n] = luaL_ref(L, LUA_REGISTRYINDEX);

      /* push established and store ref */
      lua_getfield(L, -1, "on_connected");
      user->established_function_refs[n] = luaL_ref(L, LUA_REGISTRYINDEX);

      user->protocols[n].callback = luaws_callback;
      /* the session user pointer will be initialized in the callback with reason LWS_ESTABLISHED */
      user->protocols[n].per_session_data_size = sizeof(struct luaws_websocket *); // will hold a luaL_ref to the websocket table

      ++user->protocol_count;
      user->links[n].userdata = user;
      user->links[n].protocol_index = n;
      user->protocols[n].user = &user->links[n];

      /* pop protocol table entry */
      lua_pop(L, 1);
    }
    /* pop protocols table on top */
    lua_pop(L, 1);
  
  user->context = libwebsocket_create_context(port, interf, user->protocols, user->extensions, ssl_cert_filepath, ssl_private_key_filepath, gid, uid, options);
  if(user->context == NULL) {
    luaL_error(L, "websocket could not create context");
  }
  return 1;
}

static struct luaws_context * checked_context(lua_State *L) {
  struct luaws_context *user = (struct luaws_context *)luaL_checkudata(L, 1, WS_CONTEXT_META);  
  if(user->destroyed) {
    luaL_error(user->L, "websocket context destroyed");
  }  
  return user;
}

static int luaws_context_canonical_hostname(lua_State *L) {
  struct luaws_context *user = checked_context(L);
  lua_pushstring(L, libwebsocket_canonical_hostname(user->context));
  return 1;
}

static int luaws_context_destroy(lua_State *L) {  
  int n;
  struct luaws_context *user = checked_context(L);
  if(!user->destroyed) {
    if(user->context != NULL) {
      libwebsocket_context_destroy(user->context);
    }
    luaL_argcheck(L, user, 1, "websocket context expected");
    n = 0;
    while(user->add_fd_function_refs[n]) {
      luaL_unref(L, LUA_REGISTRYINDEX, user->add_fd_function_refs[n]);
      ++n;
    }
    n = 0;
    while(user->del_fd_function_refs[n]) {
      luaL_unref(L, LUA_REGISTRYINDEX, user->del_fd_function_refs[n]);
      ++n;
    }
    n = 0;
    while(user->established_function_refs[n]) {
      luaL_unref(L, LUA_REGISTRYINDEX, user->established_function_refs[n]);
      ++n;
    }
    user->destroyed = 1;
  }
  return 0;
}

static struct luaws_websocket * checked_websocket(lua_State *L) {  
  struct luaws_websocket *user = (struct luaws_websocket *)luaL_checkudata(L, 1, WS_WEBSOCKET_META);  
  return user;
}

static int luaws_context_fork_service_loop(lua_State *L) {
  struct luaws_context *user = checked_context(L);  
  int n = libwebsockets_fork_service_loop(user->context);
  lua_pushinteger(user->L, n);
  return 1;
}

static int luaws_context_tostring(lua_State *L) {  
  struct luaws_context *user = checked_context(L);
  lua_pushfstring(L, "context %p", user);
  return 1;
}

static int luaws_websocket_tostring(lua_State *L) {  
  struct luaws_websocket *user = checked_websocket(L);
  lua_pushfstring(L, "websocket %p", user);
  return 1;
}

static int luaws_websocket_write(lua_State *L) {
  struct luaws_websocket *user = checked_websocket(L);
  size_t len;
  const char *data = lua_tolstring(L, 2, &len);
  const int padded_len = LWS_SEND_BUFFER_PRE_PADDING + len + LWS_SEND_BUFFER_POST_PADDING; 
  char padded[padded_len];
  int protocol = luaL_checkint(L, 3);
  int n;
  memcpy(padded + LWS_SEND_BUFFER_PRE_PADDING, data, len);
  n = libwebsocket_write(user->wsi, padded + LWS_SEND_BUFFER_PRE_PADDING, len, protocol);
  lua_pushinteger(L, n);
  return 1;
}

static int luaws_websocket_broadcast(lua_State *L) {
  struct luaws_websocket *user = checked_websocket(L);
  size_t len;
  const char *protocol_name = luaL_checkstring(L, 2);
  const char *data = lua_tolstring(L, 3, &len);
  const int padded_len = LWS_SEND_BUFFER_PRE_PADDING + len + LWS_SEND_BUFFER_POST_PADDING; 
  char padded[padded_len];
  int n;
  int i;
  struct libwebsocket_protocols *protocol = NULL;
  /* for(i = 0; i < user->context->protocol_count; ++i) { */
  /*   if(strcmp(user->context->protocol_names[i],protocol_name) == 0) { */
  /*     protocol = &user->context->protocols[i]; */
  /*   } */
  /* } */
  if(protocol == NULL) {
    luaL_error(L, "websocket unknown protocol");
  }
  memcpy(padded + LWS_SEND_BUFFER_PRE_PADDING, data, len);
  n = libwebsocket_broadcast(user->wsi, padded + LWS_SEND_BUFFER_PRE_PADDING, len);
  lua_pushinteger(L, n);
  return 1;
}

static int luaws_websocket_serve_http_file(lua_State *L) {  
  struct luaws_websocket *user = checked_websocket(L);
  const char * filename = luaL_checkstring(L, 2);
  const char * content_type = luaL_checkstring(L, 3);
  lua_pushinteger(L, libwebsockets_serve_http_file(user->wsi, filename, content_type));
  return 1;
}

static int luaws_websocket_on_closed(lua_State *L) {
  struct luaws_websocket *user = checked_websocket(L);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  user->closed_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return 0;
}

static int luaws_websocket_on_receive(lua_State *L) {
  struct luaws_websocket *user = checked_websocket(L);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  user->receive_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return 0;
}

static int luaws_websocket_on_broadcast(lua_State *L) {
  struct luaws_websocket *user = checked_websocket(L);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  user->broadcast_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return 0;
}

static int luaws_websocket_on_http(lua_State *L) {
  struct luaws_websocket *user = checked_websocket(L);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  user->http_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return 0;
}

static int luaws_websocket_on_server_writeable(lua_State *L) {
  struct luaws_websocket *user = checked_websocket(L);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  user->server_writeable_function_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return 0;
}

static int luaws_websocket_get_socket_fd(lua_State *L) {  
  struct luaws_websocket *user = checked_websocket(L);
  lua_pushinteger(L, libwebsocket_get_socket_fd(user->wsi));
  return 1;
}

static int luaws_websocket_rx_flow_control(lua_State *L) {  
  struct luaws_websocket *user = checked_websocket(L);
  int enable = luaL_checkint(L, 2);
  int n = libwebsocket_rx_flow_control(user->wsi, enable);
  lua_pushinteger(L, n);
  return 1;
}

static int luaws_websocket_set_timeout(lua_State *L) {  
  struct luaws_websocket *user = checked_websocket(L);
  int reason = luaL_checkint(L, 2);
  int secs = luaL_checkint(L, 3);
  int n = libwebsocket_set_timeout(user->wsi, reason, secs);
  lua_pushinteger(L, n);
  return 1;
}

static int luaws_context_service(lua_State *L) {
  struct luaws_context *user = checked_context(L);
  int timeout_ms = luaL_optint(L, 2, 0);
  lua_pop(L,1);
  int n = libwebsocket_service(user->context, timeout_ms);
  lua_pushinteger(user->L, n);
  return 1;
}

static const struct luaL_Reg luaws_module_methods [] = {
  {"context",luaws_context},
  {NULL,NULL}
};

static const struct luaL_Reg luaws_context_methods [] = {
  {"destroy",luaws_context_destroy},
  {"__gc",luaws_context_destroy},
  {"fork_service_loop",luaws_context_fork_service_loop},
  {"service",luaws_context_service},
  {"canonical_hostname",luaws_context_canonical_hostname},
  {NULL,NULL}
};

static const struct luaL_Reg luaws_websocket_methods [] = {
  {"serve_http_file",luaws_websocket_serve_http_file},
  {"get_socket_fd",luaws_websocket_get_socket_fd},
  {"rx_flow_control",luaws_websocket_rx_flow_control},
  {"set_timeout",luaws_websocket_set_timeout},
  {"write",luaws_websocket_write},
  {"on_closed",luaws_websocket_on_closed},
  {"on_receive",luaws_websocket_on_receive},
  {"on_broadcast",luaws_websocket_on_broadcast},
  {"on_server_writeable",luaws_websocket_on_server_writeable},
  {"on_http",luaws_websocket_on_http},
  {"__tostring",luaws_websocket_tostring},
  {NULL,NULL}
};

struct luaws_constant {
  const char *name;
  int value;
};

struct luaws_constant luaws_constants [] = {
  {"CALLBACK_ESTABLISHED",LWS_CALLBACK_ESTABLISHED},
  {"SERVER_OPTIONS_DEFEAT_CLIENT_MASK",LWS_SERVER_OPTION_DEFEAT_CLIENT_MASK},
  {"SERVER_OPTION_REQUIRE_VALID_OPENSSL_CLIENT_CERT",LWS_SERVER_OPTION_REQUIRE_VALID_OPENSSL_CLIENT_CERT},
  {"CALLBACK_ESTABLISHED",LWS_CALLBACK_ESTABLISHED},
  {"CALLBACK_CLIENT_ESTABLISHED",LWS_CALLBACK_CLIENT_ESTABLISHED},
  {"CALLBACK_CLOSED",LWS_CALLBACK_CLOSED},
  {"CALLBACK_RECEIVE",LWS_CALLBACK_RECEIVE},
  {"CALLBACK_CLIENT_RECEIVE",LWS_CALLBACK_CLIENT_RECEIVE},
  {"CALLBACK_CLIENT_RECEIVE_PONG",LWS_CALLBACK_CLIENT_RECEIVE_PONG},
  {"CALLBACK_CLIENT_WRITEABLE",LWS_CALLBACK_CLIENT_WRITEABLE},
  {"CALLBACK_SERVER_WRITEABLE",LWS_CALLBACK_SERVER_WRITEABLE},
  {"CALLBACK_HTTP",LWS_CALLBACK_HTTP},
  {"CALLBACK_BROADCAST",LWS_CALLBACK_BROADCAST},
  {"CALLBACK_FILTER_NETWORK_CONNECTION",LWS_CALLBACK_FILTER_NETWORK_CONNECTION},
  {"CALLBACK_FILTER_PROTOCOL_CONNECTION",LWS_CALLBACK_FILTER_PROTOCOL_CONNECTION},
  {"CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS",LWS_CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS},
  {"CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS",LWS_CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS},
  {"CALLBACK_OPENSSL_PERFORM_CLIENT_CERT_VERIFICATION",LWS_CALLBACK_OPENSSL_PERFORM_CLIENT_CERT_VERIFICATION},
  {"CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER",LWS_CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER},
  {"CALLBACK_CONFIRM_EXTENSION_OKAY",LWS_CALLBACK_CONFIRM_EXTENSION_OKAY},
  {"CALLBACK_CLIENT_CONFIRM_EXTENSION_SUPPORTED",LWS_CALLBACK_CLIENT_CONFIRM_EXTENSION_SUPPORTED},
  {"CALLBACK_ADD_POLL_FD",LWS_CALLBACK_ADD_POLL_FD},
  {"CALLBACK_DEL_POLL_FD",LWS_CALLBACK_DEL_POLL_FD},
  {"CALLBACK_SET_MODE_POLL_FD",LWS_CALLBACK_SET_MODE_POLL_FD},
  {"CALLBACK_CLEAR_MODE_POLL_FD",LWS_CALLBACK_CLEAR_MODE_POLL_FD},
  {"WRITE_TEXT",LWS_WRITE_TEXT},
  {"WRITE_BINARY",LWS_WRITE_BINARY},
  {"WRITE_CONTINUATION",LWS_WRITE_CONTINUATION},
  {"WRITE_HTTP",LWS_WRITE_HTTP},
  {"WRITE_CLOSE",LWS_WRITE_CLOSE},
  {"WRITE_PING",LWS_WRITE_PING},
  {"WRITE_PONG",LWS_WRITE_PONG},
  {"WRITE_NO_FIN",LWS_WRITE_NO_FIN},
  {"WRITE_CLIENT_IGNORE_XOR_MASK",LWS_WRITE_CLIENT_IGNORE_XOR_MASK},
  {NULL,0}
};

static void luaws_register_constants(lua_State *L, struct luaws_constant *constants) {
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
  luaL_register(L, NULL, luaws_context_methods);
  luaL_newmetatable(L, WS_WEBSOCKET_META);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, luaws_websocket_methods);
  luaL_register(L, "websockets", luaws_module_methods);
  luaws_register_constants(L, luaws_constants);
  return 1;
}
