#!/bin/bash
SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`
BASE_PATH=${SCRIPTPATH}

source /etc/oscar-env.sh

CONFIG_DIR="/etc/oscar-create/"

CREATION_DATE=$(date +%Y%m%d)

DATA_FILE_NAME="data.osm.pbf"
SOURCE_REMOTE_URL=


#Temporary files
OUR_SCRATCH_FAST_DIR=${SCRATCH_FAST_DIR}/oscar-update/${CREATION_DATE}
OUR_SCRATCH_SLOW_DIR=${SCRATCH_SLOW_DIR}/oscar-update/${CREATION_DATE}
GRAPH_FILE=${OUR_SCRATCH_SLOW_DIR}/data.fmitext.graph
CH_GRAPH_FILE=${OUR_SCRATCH_SLOW_DIR}/data.fmitext.chgraph

function download_data() {
    #Download new data

    if [ -d "${SOURCE_DIR}/next" ]; then
        rm -r "${SOURCE_DIR}/next" || exit 1
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
        if [ $OSCAR_UPDATE_FORCE ]; then
            echo "Forcing creation using old files!"
        else
            exit 0
        fi
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

function clean_temp() {
    rm -r ${OUR_SCRATCH_SLOW_DIR} ${OUR_SCRATCH_FAST_DIR} > /dev/null 2>&1
}

function clean_failed() {
    clean_temp
    rm -r ${NEXT_DIR}/${CREATION_DATE} > /dev/null 2>&1
}

function die() {
    echo ${1}
    clean_failed
    exit 1
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
    if [ ! -d "${NEXT_DIR}/${CREATION_DATE}}" ] || [ ! -f "${NEXT_DIR}/${CREATION_DATE}/kvstore" ]; then
        echo "Unpacking failed"
        rm -r ${NEXT_DIR}/*
        exit 1
    fi
else
    #Check if an update is still in progress
    pgrep oscar-create > /dev/null && echo "Oscar update is still in progress!" && exit 0

    if [ -z "${OSM_SOURCE_REMOTE_URL}" ]; then
        echo "Source url is not set."
        echo "You may set Liechtenstein as a sample remote url:"
        echo "OSM_SOURCE_REMOTE_URL=http://download.geofabrik.de/europe/liechtenstein-latest.osm.pbf"
        exit 1
    else
        SOURCE_REMOTE_URL="${OSM_SOURCE_REMOTE_URL}"
    fi

    echo "Downloading source files"
    download_data

    #Compute new oscar structures

    echo "Computing new oscar files"
    if [ "${USE_DEBUGGER}" = "enabled" ]; then
        echo "Starting debugger: "
        cgdb -- -ex run --args /usr/local/bin/oscar-create -c ${CONFIG_DIR}/settings.json -i ${SOURCE_DIR}/data.osm.pbf -o ${NEXT_DIR}/${CREATION_DATE}
        exit 0
    else
        oscar-create -c ${CONFIG_DIR}/settings.json -i ${SOURCE_DIR}/data.osm.pbf -o ${NEXT_DIR}/${CREATION_DATE} || die "Failed to create oscar search files"
    fi

    mkdir -p ${OUR_SCRATCH_FAST_DIR} || die "Could not create fast scratch dir"
    mkdir -p ${OUR_SCRATCH_SLOW_DIR} || die "Could not create slow scratch dir"

    #Compute graph
    echo "Extracting connected components"
    mkdir -p ${GRAPH_FILE} || die "Could not create directory for connected components"
    graph-creator -g fmimaxspeedtext -t time -hs auto -ccs 1024 -c /etc/graph-creator/configs/car.cfg -o ${GRAPH_FILE}/ ${SOURCE_DIR}/data.osm.pbf || die "Failed to compute graph"

    #Compute ch graph
    echo "Computing contraction hierarchy using ${CH_CONSTRUCTOR_NUM_THREADS} threads"
    mkdir -p ${CH_GRAPH_FILE} || die "Could not create directory for ch graphs"
    for i in $(ls -1 ${GRAPH_FILE}); do
        echo "Computing contraction hierarchy for connected component $i" 
        ch-constructor -i ${GRAPH_FILE}/$i -f FMI -o ${CH_GRAPH_FILE}/$i.ch -g FMI_CH -t ${CH_CONSTRUCTOR_NUM_THREADS} || die "Failed to compute contraction hierarchy"
    done

    #Compute path-finder data
    echo "Computing path-finder data using ${PATH_FINDER_NUM_THREADS} threads"
    mkdir ${NEXT_DIR}/${CREATION_DATE}/routing || die "Could not create directory for path-finder data"
    for i in $(ls -1S ${CH_GRAPH_FILE} | tac); do
        echo "Computing path-finder data for connected component $i"
        OMP_THREAD_LIMIT=${PATH_FINDER_NUM_THREADS} OMP_NUM_THREADS=${PATH_FINDER_NUM_THREADS} path-finder-create -f ${CH_GRAPH_FILE}/$i -o ${NEXT_DIR}/${CREATION_DATE}/routing/$i -l 10 -s ${NEXT_DIR}/${CREATION_DATE} -t ${PATH_FINDER_NUM_THREADS} || die "Computing path finder data failed"
    done

    #Make sure that data is only loaded using mmap
    find ${NEXT_DIR}/${CREATION_DATE}/routing -type f -name 'config.json' -exec sed -i 's/"mmap": false/"mmap": true/' {} \;

    clean_temp
fi

#New data files should now be in ${NEXT_DIR}/${CREATION_DATE}

if [ "${CLEAN_ARCHIVE}" = "enabled" ]; then
    echo "Cleaning archive"
    rm -r ${ARCHIVE_DIR}/* > /dev/null 2>&1
fi

echo "Removing old active oscar files"

pushd ${ACTIVE_DIR}
OLD_ACTIVE_VERSIONS=$(ls -1 ./)
popd

echo "Moving new active oscar files into active directory"

mv "${NEXT_DIR}/${CREATION_DATE}" "${ACTIVE_DIR}" || die "Failed to move result to destination."
chmod -R o=rX "${ACTIVE_DIR}/${CREATION_DATE}"
rm "${ACTIVE_DIR}/latest" > /dev/null 2>&1
ln -s "${ACTIVE_DIR}/${CREATION_DATE}" "${ACTIVE_DIR}/latest"

#remove currently active version
pushd ${ACTIVE_DIR}
rm -r $OLD_ACTIVE_VERSIONS > /dev/null 2>&1
popd

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
            rm ${ARCHIVE_DIR}/latest.tar.bz2 ${ARCHIVE_DIR}/latest.tar.bz2.md5sum > /dev/null 2>&1
            chmod o+rx ${ARCHIVE_DIR}/${i}.tar.bz2 ${ARCHIVE_DIR}/${i}.tar.bz2.md5
            cd ${ARCHIVE_DIR}
            ln -s ${i}.tar.bz2 latest.tar.bz2
            ln -s ${i}.tar.bz2.md5 latest.tar.bz2.md5sum
        fi
    done
fi

echo "Finished update at $(date)"
exit 0