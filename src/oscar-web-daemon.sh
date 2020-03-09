#!/bin/bash

echo "$$" > /run/oscar-web/daemon.pid

OSCAR_WEB_PID=
RUNNING=false

stop_handler() {
    kill -TERM $OSCAR_WEB_PID
    RUNNING=false
}

restart_handler() {
    if [ -n "$OSCAR_WEB_PID" ]; then
        echo "Stopping oscar-web with pid=$OSCAR_WEB_PID"
        kill -s KILL $OSCAR_WEB_PID > /dev/null 2>&1
        wait $OSCAR_WEB_PID
    fi

    umask u=rwx,g=rwx,o=
    oscar-web -c /etc/oscar-web/oscar-web-config.js &

    OSCAR_WEB_PID=$!

    ps -p $OSCAR_WEB_PID > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "Could not start oscar-web"
        RUNNING=false
    else
        echo "Started oscar-web with pid=$OSCAR_WEB_PID"
        RUNNING=true
    fi
}

trap stop_handler SIGTERM
trap restart_handler SIGUSR1

restart_handler

while $RUNNING
do
    echo "Waiting for oscar-web with pid=$OSCAR_WEB_PID"
    wait $OSCAR_WEB_PID
    sleep 1
    ps -p $OSCAR_WEB_PID > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "oscar-web seems to have died. Exiting container"
        RUNNING=false
    fi
done