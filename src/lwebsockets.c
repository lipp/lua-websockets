#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "libwebsockets.h"
#include <string.h>
#include <assert.h>

#define WS_META "ws."
#define MAX_PROTOCOLS 4
#define MAX_EXTENSIONS 4

struct lws_link {
  void *userdata;
  int protocol_index;
};

struct lws_userdata {
  lua_State *L;
  int protocol_function_refs[MAX_PROTOCOLS];
  struct libwebsocket_context *ws_context;
  int destroyed;
  int protocol_count;
  char protocol_names[MAX_PROTOCOLS][100];
  struct libwebsocket_protocols protocols[MAX_PROTOCOLS];
  struct libwebsocket_extension extensions[MAX_EXTENSIONS];
  struct lws_link links[MAX_PROTOCOLS];
};

static struct lws_userdata *lws_create_userdata(lua_State *L) {
  struct lws_userdata *user = lua_newuserdata(L, sizeof(struct lws_userdata));;
  memset(user, 0, sizeof(struct lws_userdata));
  user->L = L;
  return user;
}

static int lws_callback(struct libwebsocket_context * context,
			struct libwebsocket *wsi,
			 enum libwebsocket_callback_reasons reason, void *session,
			void *in, size_t len, void *user) {
  struct lws_link* link = user;
  struct lws_userdata* lws_user = link->userdata;
  lua_State* L = lws_user->L;
  int argc = 2;
  int res;
  if(reason == LWS_CALLBACK_ADD_POLL_FD) {
    
  }
  lua_rawgeti(L, LUA_REGISTRYINDEX, lws_user->protocol_function_refs[link->protocol_index]);
  //  lua_rawgeti(lws_user->L, LUA_REGISTRYINDEX, lws_user->protocol_function_refs[link->protocol_index]);
  lua_pushstring(L,"ws");
  lua_pushnumber(L,reason);
  switch(reason) {
  case LWS_CALLBACK_SET_MODE_POLL_FD:
  case LWS_CALLBACK_CLEAR_MODE_POLL_FD:
    lua_pushnumber(L,(int)(session));
    ++argc;
    lua_pushnumber(L,len);
    ++argc;
    break;
  case LWS_CALLBACK_ADD_POLL_FD:    
  case LWS_CALLBACK_DEL_POLL_FD:
    lua_pushnumber(L,(int)(session));
    ++argc;
    break;
  case LWS_CALLBACK_RECEIVE:
  case LWS_CALLBACK_CLIENT_RECEIVE:
  case LWS_CALLBACK_HTTP:
    if(len > 0 && in != NULL) {
      lua_pushlstring(L,in,len);
      ++argc;    
    }
    break;
  }
  lua_call(lws_user->L,argc,1);  
  res = luaL_optint(L,-1,1);
  lua_pop(L,1);
  return res;
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
  int index = 0;

  luaL_getmetatable(L, WS_META);
  lua_setmetatable(L, -2);

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
    //    user->tableref = luaL_ref(L, 1);

    lua_pushnil(L);
    while(user->protocol_count < MAX_PROTOCOLS && lua_next(L, -2) != 0) {  
      int n = user->protocol_count;
      strcpy(user->protocol_names[n],luaL_checkstring(L,-2));
      user->protocols[n].name = user->protocol_names[n];
      user->protocols[n].callback = lws_callback;
      user->protocols[n].per_session_data_size = 0;
      lua_pushvalue(L, -1);
      user->protocol_function_refs[n] = luaL_ref(L, LUA_REGISTRYINDEX);
      lua_remove(L, 1);
      ++user->protocol_count;
      lua_pop(L, 1);
      user->links[n].userdata = user;
      user->links[n].protocol_index = n;
      user->protocols[n].user = &user->links[n];
    }
    lua_pop(L, 1);
  }  
  user->ws_context = libwebsocket_create_context(port, interf, user->protocols, user->extensions, ssl_cert_filepath, ssl_private_key_filepath, gid, uid, options);
  return 1;
}

static int lws_destroy(lua_State *L) {  
  int n = 0;
  struct lws_userdata *user = (struct lws_userdata *)luaL_checkudata(L, 1, WS_META);
  if(!user->destroyed) {
    if(user->ws_context != NULL) {
      libwebsocket_context_destroy(user->ws_context);
    }
    luaL_argcheck(L, user, 1, "websocket context expected");
    while(user->protocol_function_refs[n]) {
      luaL_unref(L, LUA_REGISTRYINDEX, user->protocol_function_refs[n]);
      ++n;
    }
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
