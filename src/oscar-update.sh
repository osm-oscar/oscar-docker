#!/bin/bash
SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`
BASE_PATH=${SCRIPTPATH}

source /etc/oscar-env.sh

CONFIG_DIR="/etc/oscar-create/oscar-create"

CREATION_DATE=$(date +%Y%m%d)

DATA_FILE_NAME="data.osm.pbf"
SOURCE_REMOTE_URL=

function download_data() {
    #Download new data

    if [ -d "${SOURCE_DIR}/next" ]; then
        rm "${SOURCE_DIR}/next/*" > /dev/null 2>&1
        rmdir "${SOURCE_DIR}/next" || exit 1
    fi

    mkdir "${SOURCE_DIR}/next" || exit 1

    curl -o "${SOURCE_DIR}/next/${DATA_FILE_NAME}.md5" "${SOURCE_REMOTE_URL}.md5"

    if [ ! -f "${SOURCE_DIR}/next/${DATA_FILE_NAME}.md5" ]; then
        echo "Failed to download checksum file"
        exit 1
    fi

    HAVE_NEW_DATA=0

    if [ -f "${SOURCE_DIR}/${DATA_FILE_NAME}.md5" ]; then

        echo "Current checksum: $(egrep -o '[[:alnum:]]*\ ' ${SOURCE_DIR}/${DATA_FILE_NAME}.md5)"
        echo "New checksum: $(egrep -o '[[:alnum:]]*\ ' ${SOURCE_DIR}/next/${DATA_FILE_NAME}.md5)"

        cmp -s "${SOURCE_DIR}/${DATA_FILE_NAME}.md5" "${SOURCE_DIR}/next/${DATA_FILE_NAME}.md5"
        if [ $? -eq 1 ]; then
            HAVE_NEW_DATA=1
        fi
    else
        HAVE_NEW_DATA=1
    fi

    if [ $HAVE_NEW_DATA -eq 1 ]; then
        echo "Downloading new data file"
        curl -o "${SOURCE_DIR}/next/${DATA_FILE_NAME}" "${SOURCE_REMOTE_URL}" || exit 1
        mv "${SOURCE_DIR}/next/${DATA_FILE_NAME}" "${SOURCE_DIR}/" || exit 1
        mv "${SOURCE_DIR}/next/${DATA_FILE_NAME}.md5" "${SOURCE_DIR}/" || exit 1
        echo "Download successful"
    else
        rm "${SOURCE_DIR}/next/${DATA_FILE_NAME}.md5" || exit 1
        echo "No new data file found."
        exit 0
    fi
}

function check_dir_perm() {
    if [ ! -d "${1}" ]; then
        echo "Invalid ${2} directory: ${1}"
        return 1
    fi
    if [ ! -r "${1}" ]; then
        echo "Unable to read from ${2} directory: ${1}"
        return 1
    fi
    if [ ! -w "${1}" ]; then
        echo "Unable to write to ${2} directory: ${1}"
        return 1
    fi
    if [ ! -x "${1}" ]; then
        echo "Unable to enter ${2} directory: ${1}"
        return 1
    fi
}

check_dir_perm "${SOURCE_DIR}" "source" || exit 1
check_dir_perm "${NEXT_DIR}" "next" || exit 1
check_dir_perm "${ACTIVE_DIR}" "active" || exit 1
check_dir_perm "${ARCHIVE_DIR}" "archive" || exit 1
check_dir_perm "${SCRATCH_SLOW_DIR}" "scratch-slow" || exit 1
check_dir_perm "${SCRATCH_FAST_DIR}" "scratch-slow" || exit 1

if [ -n "$OSCAR_SOURCE_REMOTE_URL" ]; then
    DATA_FILE_NAME="data.tar.bz2"
    SOURCE_REMOTE_URL="${OSCAR_SOURCE_REMOTE_URL}"
    download_data
    tar -xjf ${SOURCE_DIR}/${DATA_FILE_NAME} -C "${NEXT_DIR}" || exit 1
    CREATION_DATE=$(ls -1 "${NEXT_DIR}" | sort -n | tail -n 1)
    if [ ! -d "${NEXT_DIR}/${CREATION_DATE}" ] || [ ! -f "${NEXT_DIR}/${CREATION_DATE}/kvstore" ]; then
        echo "Unpacking failed"
        rm -r ${NEXT_DIR}/*
        exit 1
    fi
else
    #Check if an update is still in progress
    pgrep oscar-create > /dev/null && echo "Oscar update is still in progress!" && exit 0

    if [ -z "${OSM_SOURCE_REMOTE_URL}" ]; then
        echo "Source url is not set. Using default of Liechtenstein from Geofabrik"
        SOURCE_REMOTE_URL="http://download.geofabrik.de/europe/liechtenstein-latest.osm.pbf"
    else
        SOURCE_REMOTE_URL="${OSM_SOURCE_REMOTE_URL}"
    fi

    echo "Downloading source files"
    download_data

    #Compute new oscar structures

    echo "Computing new oscar files"

    oscar-create -c ${CONFIG_DIR}/oscar-docker.json -i ${SOURCE_DIR}/data.osm.pbf -o ${NEXT_DIR}/${CREATION_DATE} || exit 1
fi

#New data files should now be in ${NEXT_DIR}/${CREATION_DATE}

if [ "${CLEAN_ARCHIVE}" = "enabled" ]; then
    echo "Claening archive"
    rm -r ${ARCHIVE_DIR}/* > /dev/null 2>&1
fi

echo "Removing old active oscar files"
#remove currently active version
rm -r ${ACTIVE_DIR}/* > /dev/null 2>&1

echo "Moving new active oscar files into active directory"

mv "${NEXT_DIR}/${CREATION_DATE}" "${ACTIVE_DIR}"
chmod -R o=rX "${ACTIVE_DIR}/${CREATION_DATE}"
rm "${ACTIVE_DIR}/latest" > /dev/null 2>&1
ln -s "${ACTIVE_DIR}/${CREATION_DATE}" "${ACTIVE_DIR}/latest"

#Restart oscar-web if it is running
if [ -f "/run/oscar-web/daemon.pid" ]; then
    ps -p $(cat /run/oscar-web/daemon.pid) > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Restarting oscar-web"
        kill -s SIGUSR1 $(cat /run/oscar-web/daemon.pid)
    else
        echo "oscar-web is not running."
    fi
else
    echo "oscar-web is not running"
fi

if [ "${ARCHIVE}" = "enabled" ]; then
    echo "Creating archives"
    for i in $(ls -1 "${ACTIVE_DIR}"); do
        if [ -d "${ACTIVE_DIR}/${i}" ] && [ ! -h "${ACTIVE_DIR}/${i}" ]; then
            echo "Creating archive ${i}.tar.bz2 from ${ACTIVE_DIR}/${i}"
            tar -c -j -f "${ARCHIVE_DIR}/${i}.tar.bz2" -C "${ACTIVE_DIR}" "${i}"
            echo "Creating checksum"
            md5sum "${ARCHIVE_DIR}/${i}.tar.bz2" > "${ARCHIVE_DIR}/${i}.tar.bz2.md5"
        fi
    done
fi

echo "Finished update at $(date)"
exit 0