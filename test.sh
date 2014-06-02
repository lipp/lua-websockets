#!/bin/bash
killall wstest 2>/dev/null
wstest -m echoserver -w ws://localhost:${LUAWS_WSTEST_PORT:=11000}  &
pid=$!
echo "Waiting for wstest to start..."
sleep 10
busted spec/
bustedcode=$?
kill ${pid}
exit $bustedcode

