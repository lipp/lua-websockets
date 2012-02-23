#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "libwebsockets.h"

static const char* ws_meta = "ws.meta";

struct lws_userdata {
  lua_State *L;
  int tableref;
  struct libwebsocket_context *ws_context;
  int destroyed;
};

static struct lws_userdata *lws_create_userdata(lua_State *L) {
  struct lws_userdata *user = lua_newuserdata(L, sizeof(struct lws_userdata));;
  user->L = L;
  user->tableref = 0;
  user->ws_context = NULL;
  user->destroyed = 0;
  return user;
}

static void lws_delete_userdata(lua_State *L, struct lws_userdata *lws_user) {
  lua_unref(L, lws_user->tableref);
  lws_user->tableref = LUA_REFNIL;
  
}

static const int max_protocols = 4;
static const int max_extensions = 4;

static int lws_context(lua_State *L) {
  int port = 0;
  const char* interf = NULL;
  struct libwebsocket_protocols protocols[max_protocols];  
  struct libwebsocket_extension extensions[max_extensions];
  const char* ssl_cert_filepath = NULL;
  const char* ssl_private_key_filepath = NULL;
  int gid = -1;
  int uid = -1;
  unsigned int options = 0;
  struct lws_userdata *user = NULL;
  memset(protocols,0,sizeof(struct libwebsocket_protocols)*max_protocols);
  memset(extensions,0,sizeof(struct libwebsocket_extension)*max_extensions);
  if( lua_type(L, 1) == LUA_TTABLE ) {
    
  }  
  user = lws_create_userdata(L);  
  user->ws_context = libwebsocket_create_context(port, interf, protocols, extensions, ssl_cert_filepath, ssl_private_key_filepath, gid, uid, options);
  luaL_getmetatable(L, ws_meta);
  lua_setmetatable(L, -2);
  return 1;
}

static int lws_destroy(lua_State *L) {  
  struct lws_userdata *user = (struct lws_userdata *)luaL_checkudata(L, 1, ws_meta);
  if( !user->destroyed ) {
    libwebsocket_context_destroy(user->ws_context);
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
  luaL_newmetatable(L, ws_meta);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, lws_context_methods);
  luaL_register(L, "websockets", lws_module_methods);
  return 1;
}
