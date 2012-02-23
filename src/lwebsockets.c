#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "libwebsockets.h"
#include <string.h>
#include <assert.h>

#define WS_META "ws.meta"
#define MAX_PROTOCOLS 4
#define MAX_EXTENSIONS 4

struct lws_userdata {
  lua_State *L;
  int tableref;
  struct libwebsocket_context *ws_context;
  int destroyed;
  char protocol_names[MAX_PROTOCOLS][100];
  struct libwebsocket_protocols protocols[MAX_PROTOCOLS];
  struct libwebsocket_extension extensions[MAX_EXTENSIONS];
};

static struct lws_userdata *lws_create_userdata(lua_State *L) {
  struct lws_userdata *user = lua_newuserdata(L, sizeof(struct lws_userdata));;
  user->L = L;
  user->tableref = 0;
  user->ws_context = NULL;
  user->destroyed = 0;
  memset(user->protocols,0,sizeof(struct libwebsocket_protocols)*MAX_PROTOCOLS);
  memset(user->extensions,0,sizeof(struct libwebsocket_extension)*MAX_EXTENSIONS);
  return user;
}

static void lws_delete_userdata(lua_State *L, struct lws_userdata *lws_user) {
  lua_unref(L, lws_user->tableref);
  lws_user->tableref = LUA_REFNIL;
}

static int lws_callback(struct libwebsocket_context * context,
			struct libwebsocket *wsi,
			 enum libwebsocket_callback_reasons reason, void *user,
			 void *in, size_t len) {
  
  printf("CALLBACK %d %p %p %p\n",reason,user,libwebsockets_get_protocol(wsi),context);
  //  lua_getfield(
}


static int lws_context(lua_State *L) {
  int port = 0;
  const char* interf = NULL;
  const char* ssl_cert_filepath = NULL;
  const char* ssl_private_key_filepath = NULL;
  int gid = -1;
  int uid = -1;
  unsigned int options = 0;
  struct lws_userdata *user = lws_create_userdata(L);

  luaL_getmetatable(L, WS_META);
  lua_setmetatable(L, -2);

  int n_protocols = 0;
  if( lua_type(L, 1) == LUA_TTABLE ) {
    lua_getfield(L, 1, "port");
    port = luaL_optint(L, -1, 0);    
    lua_pop(L, 1);

    lua_getfield(L, 1, "interf");
    interf = luaL_optstring(L, -1, NULL);    
    lua_pop(L, 1);

    lua_getfield(L, 1, "protocols");    
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushvalue(L, 1);
    assert(lua_setfenv(L, -3) == 1);

    lua_pushnil(L);
    while(n_protocols < MAX_PROTOCOLS && lua_next(L, -2) != 0) {      
      printf("%d %s\n",n_protocols,luaL_checkstring(L,-2));
      strcpy(user->protocol_names[n_protocols],luaL_checkstring(L,-2));
      user->protocols[n_protocols].name = user->protocol_names[n_protocols];
      user->protocols[n_protocols].callback = lws_callback;
      user->protocols[n_protocols].per_session_data_size = 0;
      ++n_protocols;
      lua_pop(L, 1);
    }
    lua_pop(L, 1);
  }  

  user->ws_context = libwebsocket_create_context(port, interf, user->protocols, user->extensions, ssl_cert_filepath, ssl_private_key_filepath, gid, uid, options);

  return 1;
}

static int lws_destroy(lua_State *L) {  
  struct lws_userdata *user = (struct lws_userdata *)luaL_checkudata(L, 1, WS_META);
  if(!user->destroyed) {
    if(user->ws_context != NULL) {
      libwebsocket_context_destroy(user->ws_context);
    }
    luaL_argcheck(L, user, 1, "websocket context expected");
    lws_delete_userdata(L, user);
    user->destroyed = 1;
  }
  return 0;
}

static const struct luaL_Reg lws_module_methods [] = {
  {"context",lws_context},
  {NULL,NULL}
};

static const struct luaL_Reg lws_context_methods [] = {
  {"destroy",lws_destroy},
  {"__gc",lws_destroy},
  {NULL,NULL}
};

int luaopen_websockets(lua_State *L) {
  luaL_newmetatable(L, WS_META);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, lws_context_methods);
  luaL_register(L, "websockets", lws_module_methods);
  return 1;
}