#!/usr/bin/env sh
mkdir min
mkdir min/src
mkdir min/src/websocket
for i in `find src -name "*.lua"`
do
  echo "minifying" $i
  luamin -f {$i} > min/$i
done
