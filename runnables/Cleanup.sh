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
    NAME="${i#*=}"
    shift
    ;;

esac
done

mv ${INPUT} ${OUTPUT}/.
FOLDER="${OUTPUT}/${NAME}"
mv ${FOLDER}/slice_1-protocol.txt ${FOLDER}/pre-post-process-protocol.txt
mv ${FOLDER}/${NAME}-protocol.txt ${FOLDER}/post-process-protocol.txt
