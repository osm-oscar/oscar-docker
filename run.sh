#!/bin/bash

set -x

PATH="${PATH}:/usr/local/bin"

if [ "$#" -ne 1 ]; then
    echo "usage: See readme"
fi

if [ "$1" = "clean" ]; then
    echo "Removing source data and latest oscar-web data"
    rm "/source/data.osm.pbf"
    rm "/source/data.osm.pbf.md5"
    if [ -e "/active/latest" ]; then
        rm -r $(readlink -f /active/latest)
        rm "/active/latest"
    fi
    exit 0
fi

if [ "$1" = "create" ]; then
    if [ ! -d "/scratch/fast" ]; then
        mkdir "/scratch/fast" || exit 1
    fi

    if [ ! -d "/scratch/slow" ]; then
        mkdir "/scratch/slow" || exit 1
    fi
    /usr/local/bin/oscar-update
    exit 0
fi

if [ "$1" = "serve" ]; then
    # Clean /tmp
    rm -rf /tmp/*

    if [ ! -d "/run/oscar-web" ]; then
        mkdir "/run/oscar-web"
    fi

    if [ ! -e "/run/oscar-web/oscar.sock" ]; then
        mkfifo "/run/oscar-web/oscar.sock"
    fi

    chown -R oscar:oscar "/run/oscar-web"
    chmod u+rwx,g+rwx,o= "/run/oscar-web/oscar.sock"

    service lighttpd restart

    # start cron job to trigger consecutive updates
    if [ "$UPDATES" = "enabled" ] || [ "$UPDATES" = "1" ]; then
        echo "Enabling cron for updates"
        /etc/init.d/cron start
    fi

    # Run while handling docker stop's SIGTERM
    stop_handler() {
        kill -TERM "$child"
    }
    trap stop_handler SIGTERM

    sudo -u oscar -g oscar oscar-web-daemon &
    child=$!
    wait "$child"

    service lighttpd stop

    exit 0
fi

echo "invalid command"
exit 1
