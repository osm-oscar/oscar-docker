#!/bin/bash
set -x

PATH="${PATH}:/usr/local/bin"

if [ "$#" -ne 1 ]; then
    echo "usage: See readme"
fi

#Make env vars permanent
echo "#Global OSCAR options" > /etc/oscar-options.sh
echo "OSM_SOURCE_REMOTE_URL=${OSM_SOURCE_REMOTE_URL}" >> /etc/oscar-options.sh
echo "OSCAR_SOURCE_REMOTE_URL=${OSCAR_SOURCE_REMOTE_URL}" >> /etc/oscar-options.sh
echo "UPDATES=${UPDATES}" >> /etc/oscar-options.sh
echo "ARCHIVE=${ARCHIVE}" >> /etc/oscar-options.sh
echo "CLEAN_ARCHIVE=${CLEAN_ARCHIVE}" >> /etc/oscar-options.sh

source /etc/oscar-env.sh

function setup_dir() {
    if [ ! -d "${1}" ]; then
        mkdir -p "${1}" || return 1
    fi
    chown -R oscar:oscar "${1}" || return 1
    chmod -R u=rwx,g=rx,o= "${1}" || return 1
    return 0
}

function setup_dir_worldreadable() {
    setup_dir $@ || return 1
    chmod -R u=rwX,g=rX,o=rX "${1}" || return 1
    return 0
}

setup_dir "${SOURCE_DIR}" || exit 1
setup_dir "${NEXT_DIR}" || exit 1
setup_dir "${SOURCE_DIR}" || exit 1
setup_dir "${ACTIVE_DIR}" || exit 1
setup_dir "${SCRATCH_SLOW_DIR}" || exit 1
setup_dir "${SCRATCH_FAST_DIR}" || exit 1
setup_dir "${OSCAR_LOG_DIR}" || exit 1
setup_dir "${OSCAR_UPDATE_LOG_DIR}" || exit 1
setup_dir_worldreadable "${ARCHIVE_DIR}" || exit 1


# Clean temp
rm -rf /tmp/* > /dev/null 2>&1
rm -rf ${SCRATCH_SLOW_DIR}/* > /dev/null 2>&1
rm -rf ${SCRATCH_FAST_DIR}/* > /dev/null 2>&1

if [ "$1" = "clean" ]; then
    echo "Removing source data and latest oscar-web data"
    rm "${SOURCE_DIR}/data.osm.pbf" > /dev/null 2>&1
    rm "${SOURCE_DIR}/data.osm.pbf.md5" > /dev/null 2>&1
    if [ -e "${ACTIVE_DIR}/latest" ]; then
        rm -r $(readlink -f ${ACTIVE_DIR}/latest) > /dev/null 2>&1
        rm "${ACTIVE_DIR}/latest" > /dev/null 2>&1
    fi
    exit 0
fi

if [ "$1" = "create" ]; then
    sudo -u oscar -g oscar sh -c 'OSCAR_UPDATE_FORCE=true /usr/local/bin/oscar-update'
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

if [ "$1" = "bash" ]; then
    /bin/bash -i
    exit $?
fi

echo "invalid command"
exit 1
