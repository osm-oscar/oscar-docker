#!/bin/bash

#	-e 'OSM_SOURCE_REMOTE_URL=http://download.geofabrik.de/europe/andorra-latest.osm.pbf' \
#	-e 'OSCAR_SOURCE_REMOTE_URL=file:///archive/oscar/20200307.tar.bz2' \
docker run \
	-v oscar-source:/source \
	-v oscar-scratch-fast:/scratch/fast \
	-v oscar-scratch-slow:/scratch/slow \
	-v oscar-next:/next \
	-v oscar-active:/active \
	-v oscar-archive:/archive \
	-e 'UPDATES=enabled' \
	-e 'ARCHIVE=enabled' \
	-e 'CLEAN_ARCHIVE=enabled' \
	-e 'OSCAR_SOURCE_REMOTE_URL=file:///archive/oscar/20200306.tar.bz2' \
	-p "14080:80" \
	--rm \
	oscar \
	$@
