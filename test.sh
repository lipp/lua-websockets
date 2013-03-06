#!/bin/bash
killall wstest 2>/dev/null
wstest -m echoserver -w ws://localhost:${LUAWS_WSTEST_PORT:=8081}  &
pid=$!
sleep 1
busted spec/
bustedcode=$?
kill ${pid}
exit $bustedcode

