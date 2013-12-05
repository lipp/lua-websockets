#!/bin/bash
killall wstest 2>/dev/null
wstest -m echoserver -w ws://localhost:${LUAWS_WSTEST_PORT:=8081}  &
pid=$!
echo "Waiting for wstest to start..."
sleep 10
busted spec/
bustedcode=$?
kill ${pid}
exit $bustedcode

