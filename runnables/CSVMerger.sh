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

    -c=*)
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

esac
done

# Create our node local setip
echo "copying file to local storage"
TMP_DIR=${TMPDIR}/${SLURM_JOB_ID}
mkdir ${TMP_DIR}
NAME=$(basename ${FILE})
TMP_FILE="${TMP_DIR}/${NAME}"
cp ${FILE} ${TMP_FILE}

echo "merging all the localisation log files"
export LOGFILE=${WORKING_DIRECTORY}/temp_localisation.log
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
module load bio/Fiji/Custom-ThunderSTORM
module load Tigervnc/1.9.0
DISPLAY=$(vncstart)
export DISPLAY=${DISPLAY}
echo "Display is: ${DISPLAY}"

echo "running TSTORM_loc_post_macro!"

# run ThunderSTORM
source ${OUTPUT}/environmental_vars.sh
ImageJ-linux64 --plugins ${CUSTOM_PLUGINS_PATH} --ij2 --allow-multiple --no-splash -macro ${SCRIPT} ${WORKING_DIRECTORY}:${TMP_FILE}:${OUTPUT}/${WORKING_DIRECTORY}/merged_sorted.csv:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}:${TYPE}:${LATERAL}

# Copy raw csv file back to Work directory
cp ${TMP_DIR}/merged_sorted.csv ${WORKING_DIRECTORY}/merged_sorted.csv

echo "stopping vnc!"
vncserver -kill ${DISPLAY}
rm -r ${TMP_DIR}

NAME="${NAME%.*}"
LOC_AFTER=`wc -l ${WORKING_DIRECTORY}/${NAME}.csv | awk '{print $1-1}'`
echo "${LOC_AFTER} localisations found after filtering" >> ${LOGFILE}

exit

