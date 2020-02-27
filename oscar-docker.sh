#!/bin/bash
docker run \
	-v oscar-source:/source \
	-v oscar-scratch:/scratch \
	-v oscar-next:/next \
	-v oscar-active:/active \
	-v oscar-archive:/archive \
	-p "14080:80" \
	oscar \
	$@
