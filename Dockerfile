FROM ubuntu:14.04
# install autobahn tests suite (python)
RUN apt-get update -y && apt-get install build-essential libssl-dev python -y
# install lua
ENV LUAROCKS_VERSION=2.0.13
ENV LUAROCKS_BASE=luarocks-$LUAROCKS_VERSION
ENV LUA luajit
ENV LUA_DEV libluajit-5.1-dev 
ENV LUA_VER 5.1
ENV LUA_SFX jit
ENV LUA_INCDIR /usr/include/luajit-2.0

#    - LUA=lua5.1 LUA_DEV=liblua5.1-dev LUA_VER=5.1 LUA_SFX=5.1 LUA_INCDIR=/usr/include/lua5.1
#   - LUA=lua5.2 LUA_DEV=liblua5.2-dev LUA_VER=5.2 LUA_SFX=5.2 LUA_INCDIR=/usr/include/lua5.2
#   - LUA=luajit LUA_DEV=libluajit-5.1-dev LUA_VER=5.1 LUA_SFX=jit LUA_INCDIR=/usr/include/luajit-2.0
RUN apt-get install ${LUA} ${LUA_DEV} wget libev-dev git-core unzip -y
RUN lua${LUA_SFX} -v
WORKDIR /
RUN wget --quiet https://github.com/keplerproject/luarocks/archive/v$LUAROCKS_VERSION.tar.gz -O $LUAROCKS_BASE.tar.gz
RUN wget --quiet https://nodejs.org/dist/v4.4.1/node-v4.4.1-linux-x64.tar.gz
RUN tar xf node-v4.4.1-linux-x64.tar.gz
ENV PATH /node-v4.4.1-linux-x64/bin:$PATH
RUN node --version
RUN npm install -g ws
RUN tar zxpf $LUAROCKS_BASE.tar.gz
RUN cd $LUAROCKS_BASE && ./configure --lua-version=$LUA_VER --lua-suffix=$LUA_SFX --with-lua-include="$LUA_INCDIR" && make install && cd ..
RUN luarocks --version
RUN git clone http://github.com/brimworks/lua-ev && cd lua-ev && luarocks make LIBEV_LIBDIR=/usr/lib/x86_64-linux-gnu/ rockspec/lua-ev-scm-1.rockspec && cd ..
RUN luarocks install LuaCov
RUN luarocks install lua_cliargs 2.3-3
RUN luarocks install busted 1.10.0-1
ADD . /lua-websockets
WORKDIR /lua-websockets
RUN luarocks make rockspecs/lua-websockets-scm-1.rockspec 
RUN ./test.sh

