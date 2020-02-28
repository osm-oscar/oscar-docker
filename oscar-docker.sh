#!/bin/bash
docker run \
	-v oscar-source:/source \
	-v oscar-scratch-fast:/scratch/fast \
	-v oscar-scratch-slow:/scratch/slow \
	-v oscar-next:/next \
	-v oscar-active:/active \
	-v oscar-archive:/archive \
	-e 'SOURCE_REMOTE_URL=http://download.geofabrik.de/europe/andorra-latest.osm.pbf' \
	-e 'UPDATES=enabled' \
	-p "14080:80" \
	oscar \
	$@
