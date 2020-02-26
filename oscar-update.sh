#!/bin/bash
SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`
BASE_PATH=${SCRIPTPATH}

SOURCE_DIR="/source"
CONFIG_DIR="/etc/oscar-create/oscar-create"
NEXT_DIR="/next"
ACTIVE_DIR="/active"
ARCHIVE_DIR="/archive"

CREATION_DATE=$(date +%Y%m%d)

#Check if an update is still in progress
pgrep oscar-create > /dev/null && echo "Oscar update is still in progress!" && exit 0

cd "/" || exit 1

if [ -z "${SOURCE_REMOTE_URL}" ]; then
    echo "Source url is not set. Using default of Liechtenstein from Geofabrik"
    SOURCE_REMOTE_URL="http://download.geofabrik.de/europe/liechtenstein-latest.osm.pbf"
fi


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
check_dir_perm "${CONFIG_DIR}" "config" || exit 1
check_dir_perm "${NEXT_DIR}" "next" || exit 1
check_dir_perm "${ACTIVE_DIR}" "active" || exit 1
check_dir_perm "${ARCHIVE_DIR}" "archive" || exit 1


#Download new data

if [ -d "${SOURCE_DIR}/next" ]; then
    rm "${SOURCE_DIR}/next/*"
    rmdir "${SOURCE_DIR}/next" || exit 1
fi

mkdir "${SOURCE_DIR}/next" || exit 1

wget "${SOURCE_REMOTE_URL}.md5" -O "${SOURCE_DIR}/next/data.osm.pbf.md5"

if [ ! -f "${SOURCE_DIR}/next/data.osm.pbf.md5" ]; then
	echo "Failed to download checksum file"
	exit 1
fi

HAVE_NEW_DATA=0

if [ -f "${SOURCE_DIR}/data.osm.pbf.md5" ]; then

    echo "Current checksum: $(egrep -o '[[:alnum:]]*\ ' ${SOURCE_DIR}/data.osm.pbf.md5)"
    echo "New checksum: $(egrep -o '[[:alnum:]]*\ ' ${SOURCE_DIR}/next/data.osm.pbf.md5)"

    cmp -s "${SOURCE_DIR}/data.osm.pbf.md5" "${SOURCE_DIR}/next/data.osm.pbf.md5"
    if [ $? -eq 1 ]; then
        HAVE_NEW_DATA=1
    fi
else
    HAVE_NEW_DATA=1
fi

if [ $HAVE_NEW_DATA -eq 1 ]; then
	echo "Downloading new data file"
	wget "${SOURCE_REMOTE_URL}" -O "${SOURCE_DIR}/next/data.osm.pbf" || exit 1
	mv "${SOURCE_DIR}/next/data.osm.pbf" "${SOURCE_DIR}/" || exit 1
	mv "${SOURCE_DIR}/next/data.osm.pbf.md5" "${SOURCE_DIR}/" || exit 1
	echo "Download successful"
else
	rm "${SOURCE_DIR}/next/data.osm.pbf.md5" || exit 1
	echo "No new data file found."
	exit 0
fi

#Compute new oscar structures

echo "Computing new oscar files"

mkdir $

oscar-create -c ${CONFIG_DIR}/oscar-docker.json -i ${SOURCE_DIR}/data.osm.pbf -o ${NEXT_DIR}/${CREATION_DATE}

if [ $? -eq 0 ]; then
    if [ "${CLEAN_ARCHIVE}" = "enabled" ]; then
        rm -r ${ARCHIVE_DIR}/*
    fi
    if [ "${ARCHIVE}" = "enabled" ]; then
        mv ${ACTIVE_DIR}/* "${ARCHIVE_DIR}/"
    fi
	mv "${NEXT_DIR}/${CREATION_DATE}" "${ACTIVE_DIR}"
	chmod -R o=rX "${ACTIVE_DIR}/${CREATION_DATE}"
	rm /oscar-search-files 2>&1> /dev/null
	ln -s ${ACTIVE_DIR}/${CREATION_DATE} /oscar-search-files

    #service restart oscar

	echo "Finished update at $(date)"
    exit 0
else
	echo "Failed update at $(date)"
	exit 1
fi