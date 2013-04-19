#!/bin/bash
killall wstest 2>/dev/null
wstest -m echoserver -w ws://localhost:${LUAWS_WSTEST_PORT:=8081}  &
pid=$!
sleep 3
rm luacov.* 2>/dev/null
busted -c spec/
bustedcode=$?
egrep "\s+src/" luacov.report.out
kill ${pid}
exit $bustedcode

