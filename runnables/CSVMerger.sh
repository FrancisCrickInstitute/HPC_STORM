#!/usr/bin/env bash
set -e

echo "Start Localization time $(date) with Job ID: ${SLURM_JOB_ID}"

for i in "$@"
do
case ${i} in

    -f=*)
    FILE="${i#*=}"
    shift
    ;;

    -custom=*)
    CUSTOM_PLUGINS_PATH="${i#*=}"
    shift
    ;;

    -target_folder=*)
    WORKING_DIRECTORY="${i#*=}"
    shift
    ;;

    -threed=*)
    THREED="${i#*=}"
    shift
    ;;

    -calibration=*)
    CALIB="${i#*=}"
    shift
    ;;

    -type=*)
    TYPE="${i#*=}"
    shift
    ;;

    -lateral=*)
    LATERAL="${i#*=}"
    shift
    ;;

    -s=*)
    SCRIPT="${i#*=}"
    shift
    ;;

    -output=*)
    OUTPUT="${i#*=}"
    shift
    ;;

    -scale=*)
    SCALE_BAR="${i#*=}"
    shift
    ;;

    -camera=*)
    CAMERA="${i#*=}"
    shift
    ;;

esac
done

cleanup() {
    if [[ ! -z "$DISPLAY" ]]; then
        echo "stopping vnc!"
        vncserver -kill ${DISPLAY}
    fi

    if [[ ! -z "$TMP_DIR" ]]; then
        rm -r ${TMP_DIR}
    fi

    if [[ ! -z "$WORKING_DIRECTORY" ]]; then
        rm ${WORKING_DIRECTORY}/conf*txt
        rm ${WORKING_DIRECTORY}/slice*.csv
    fi
}

trap cleanup 0 1 2 3 6 15 EXIT

# Create our node local setip
echo "copying file to local storage"
TMP_DIR=${TMPDIR}/${SLURM_JOB_ID}
mkdir ${TMP_DIR}
NAME=$(basename ${FILE})
NAME="${NAME%%.*}"

echo "merging all the localisation log files"
export LOGFILE=${WORKING_DIRECTORY}/localisation.log
cat ${WORKING_DIRECTORY}/*.log  > ${LOGFILE}
rm  ${WORKING_DIRECTORY}/*.log

echo "Start Merging time $(date)" >> ${LOGFILE}
head -1 ${WORKING_DIRECTORY}/slice_1.csv > ${TMP_DIR}/merged.csv
tail -n +2 -q ${WORKING_DIRECTORY}/slice_*.csv >> ${TMP_DIR}/merged.csv
sort -t ',' -k2n,2 -k1n,1 ${TMP_DIR}/merged.csv > ${TMP_DIR}/merged_sorted.csv

LOC_BEFORE=`wc -l ${TMP_DIR}/merged_sorted.csv | awk '{print $1-1}'`
echo "${LOC_BEFORE} localisations found after merge" >> ${LOGFILE}

echo "Start Postprocess time $(date)" >> ${LOGFILE}

##load application module
module load fiji/custom-ImageJ-1.51a
module load Tigervnc/1.9.0
DISPLAY=$(vncstart)
export DISPLAY=${DISPLAY}
echo "Display is: ${DISPLAY}"

echo "running TSTORM_loc_post_macro!"

# run ThunderSTORM
source ${WORKING_DIRECTORY}/${CAMERA}
ImageJ-linux64 --plugins ${CUSTOM_PLUGINS_PATH} --ij2 --allow-multiple --no-splash -macro ${SCRIPT} ${WORKING_DIRECTORY}:${NAME}:${TMP_DIR}/merged_sorted.csv:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}:${TYPE}:${LATERAL}:${SCALE_BAR}

# Copy raw csv file back to Work directory
cp ${TMP_DIR}/merged_sorted.csv ${WORKING_DIRECTORY}/pre-post-processed.csv

LOC_AFTER=`wc -l ${WORKING_DIRECTORY}/${NAME}.csv | awk '{print $1-1}'`
echo "${LOC_AFTER} localisations found after filtering" >> ${LOGFILE}

rm ${WORKING_DIRECTORY}/${CAMERA}

#echo "stopping vnc!"
#vncserver -kill ${DISPLAY}
#rm -r ${TMP_DIR}
#rm ${WORKING_DIRECTORY}/conf*txt
#rm ${WORKING_DIRECTORY}/slice*.csv

exit

