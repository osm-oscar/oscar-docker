#!/bin/bash

/usr/local/bin/oscar-update >> /var/log/oscar-web/update/$(date +%Y%m%d).log 2>&1