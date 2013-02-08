#!/bin/bash
node echo-ws.js 1>/dev/null &
pid=$!
sleep 1
busted spec/
bustedcode=$?
kill ${pid}
exit $bustedcode

