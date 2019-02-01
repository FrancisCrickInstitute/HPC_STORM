#!/usr/bin/env bash

for i in "$@"
do
case ${i} in

    -f=*)
    FILE="${i#*=}"
    shift
    ;;

    -t=*)
    TARGET="${i#*=}"
    shift
    ;;

esac
done

ml LibTIFF/4.0.4-foss-2016b
tiffinfo ${FILE} | grep Frame | sed 's/^.*"Frame":// ; s/,".*$//' | sort -rn | head -n 1 > ${TARGET}