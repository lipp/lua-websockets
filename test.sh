#!/bin/bash
wstest -m echoserver -w ws://localhost:8080 1>/dev/null &
pid=$!
sleep 1
busted spec/
bustedcode=$?
kill ${pid}
exit $bustedcode

