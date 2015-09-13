#!/bin/bash
killall node 2>/dev/null
npm install ws
node echows.js ${LUAWS_WSTEST_PORT:=11000} &
pid=$!
echo "Waiting for wstest to start..."
sleep 5
busted -c spec/
bustedcode=$?
kill ${pid}
exit $bustedcode
