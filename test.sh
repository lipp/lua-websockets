#!/bin/sh
node echo-ws.js 1>/dev/null &
sleep 1
busted spec/

