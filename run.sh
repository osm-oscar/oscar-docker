#!/bin/bash
set -x

PATH="${PATH}:/usr/local/bin"

if [ "$#" -ne 1 ]; then
    echo "usage: See readme"
fi

source /etc/oscar-env.sh

function setup_dir() {
    if [ ! -d "${1}" ]; then
        mkdir -p "${1}" || return 1
    fi
    chown -R oscar:oscar "${1}" || return 1
    chmod -R u=rwx,g=rx,o= "${1}" || return 1
    return 0
}

setup_dir "${SOURCE_DIR}" || exit 1
setup_dir "${NEXT_DIR}" || exit 1
setup_dir "${SOURCE_DIR}" || exit 1
setup_dir "${ACTIVE_DIR}" || exit 1
setup_dir "${ARCHIVE_DIR}" || exit 1
setup_dir "${SCRATCH_SLOW_DIR}" || exit 1
setup_dir "${SCRATCH_FAST_DIR}" || exit 1


# Clean temp
rm -rf /tmp/*
rm -rf ${SCRATCH_SLOW_DIR}/*
rm -rf ${SCRATCH_FAST_DIR}/*

if [ "$1" = "clean" ]; then
    echo "Removing source data and latest oscar-web data"
    rm "${SOURCE_DIR}/data.osm.pbf"
    rm "${SOURCE_DIR}/data.osm.pbf.md5"
    if [ -e "${ACTIVE_DIR}/latest" ]; then
        rm -r $(readlink -f ${ACTIVE_DIR}/latest)
        rm "${ACTIVE_DIR}/latest"
    fi
    exit 0
fi

if [ "$1" = "create" ]; then
    /usr/local/bin/oscar-update
    exit 0
fi

if [ "$1" = "serve" ]; then

    if [ ! -d "/run/oscar-web" ]; then
        mkdir "/run/oscar-web" || exit 1
    fi

    if [ ! -e "/run/oscar-web/oscar.sock" ]; then
        mkfifo "/run/oscar-web/oscar.sock" || exit 1
    fi

    chown -R oscar:oscar "/run/oscar-web" || exit 1
    chmod u+rwx,g+rwx,o= "/run/oscar-web/oscar.sock" || exit 1

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
