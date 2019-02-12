#!/usr/bin/env bash
set -e

echo "Start Localization time $(date) with Job ID: ${SLURM_JOB_ID}"

for i in "$@"
do
case ${i} in

    -s=*)
    INPUT="${i#*=}"
    shift
    ;;

    -o=*)
    OUTPUT="${i#*=}"
    shift
    ;;

    -f=*)
    FOLDER="${i#*=}"
    shift
    ;;

esac
done

mv ${INPUT} ${OUTPUT}/.
mv ${OUTPUT}/slice_1-protocol.txt ${OUTPUT}/localisation-protocol.txt
