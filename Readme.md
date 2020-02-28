# Running
 * docker run create: downloads a new data set and creates the necessary search files
 * docker run serve: runs oscar-web
 * docker run clean: clean source/active directory of files

# Environment variables:
 * UPDATES=enabled|disabled: check for new updates every day
 * ARCHIVE=enabled|disabled: archive old data
 * CLEAN_ARCHIVE=enabled|disabled: clean archive
 * SOURCE_REMOTE_URL: url to the data file

# Configuration
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
