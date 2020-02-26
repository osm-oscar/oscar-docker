#!/bin/bash

set -x

PATH="${PATH}:/usr/local/bin"

if [ "$#" -ne 1 ]; then
    echo "usage: See readme"
fi

if [ "$1" = "create" ]; then
    /usr/local/bin/oscar-update
    exit 0
fi

if [ "$1" = "run" ]; then
    # Clean /tmp
    rm -rf /tmp/*

    service lighttpd restart

    # start cron job to trigger consecutive updates
    if [ "$UPDATES" = "enabled" ] || [ "$UPDATES" = "1" ]; then
      /etc/init.d/cron start
    fi

    # Run while handling docker stop's SIGTERM
    stop_handler() {
        kill -TERM "$child"
    }
    trap stop_handler SIGTERM

    sudo -u oscar -g oscar oscar-web -c /etc/oscar-web/oscar-web-config.js &
    child=$!
    wait "$child"

    service lighttpd stop

    exit 0
fi

if [ "$1" = "bash" ]; then
    echo "Entering bash"
    /bin/bash
    exit 0
fi

echo "invalid command"
exit 1
