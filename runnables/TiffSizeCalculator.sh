#!/usr/bin/env bash

for i in "$@"
do
case ${i} in

    -f=*)
    FILES="${i#*=}"
    shift
    ;;

    -t=*)
    TARGET="${i#*=}"
    shift
    ;;

    -w=*)
    WORKING="${i#*=}"
    shift
    ;;

esac
done

ml LibTIFF/4.0.4-foss-2016b

# No images
count = 0

# Identify the tiff stack size
OLD_IFS=${IFS}
IFS=","
for file in ${FILES}; do
    count+=$(tiffinfo ${file} | grep Frame | sed 's/^.*"Frame":// ; s/,".*$//' | sort -rn | head -n 1)
done
export IFS=${OLD_IFS}

echo ${count} > ${TARGET}

# Make the output directories for our files
mkdir ${WORKING}