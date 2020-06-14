# Running
 * docker-compose -f docker-compose.yml -f oscar-create.yml up: downloads a new data set and creates the necessary search files
 * docker-compose -f docker-compose.yml up: runs oscar-web
 * docker-compose -f docker-compose.yml -f oscar-clean.yml up: clean source/active directory of files

# Environment variables:
 * UPDATES=enabled|disabled: check for new updates every day
 * ARCHIVE=enabled|disabled: archive old data
 * CLEAN_ARCHIVE=enabled|disabled: clean archive
 * OSM_SOURCE_REMOTE_URL: url to the data.osm.pbf file
 * OSCAR_SOURCE_REMOTE_URL: url to the data.tar.bz2 file containing oscar search data

# Configuration
## Docker container
 * Edit the .env file to set appropriate paths

## oscar-create
 * Configuration files may access config files from the oscar repository using a relative path of "./name.of.config.file"

## oscar-web
 * A sample config file for oscar-web can be found in this repository

# Volumes
 * /source: contains source data (pbf-files)
 * /scratch/fast: fast block storage (preferably ssd)
 * /scratch/slow: slow block storage (can be on hdd)
 * /next: temporary folder where the next search files are created (can be slower fs)
 * /active: currently active search files (should be on a ssd)
 * /archive: historic search files (can be on slower)

 # Resource usage
In order to compute files for planet the following is necessary:
 * 256 GiB RAM
 * 6 TiB /scratch/slow
