#!/bin/sh
node echo-ws.js 2>/dev/null &
sleep 1
busted spec/

