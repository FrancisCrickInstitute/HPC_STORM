#!/usr/bin/env bash
set -eE

echo "Start Localization time $(date) with Job ID: ${SLURM_JOB_ID}"
echo "Parameters: $@"

for i in "$@"
do
case ${i} in

    -f=*)
    FILE="${i#*=}"
    shift
    ;;

    -all_linked_files=*)
    FILES="${i#*=}"
    shift
    ;;

    -custom=*)
    CUSTOM_PLUGINS_PATH="${i#*=}"
    shift
    ;;

    -w=*)
    WORKING_DIRECTORY="${i#*=}"
    shift
    ;;

    -step=*)
    STEPS="${i#*=}"
    shift
    ;;

    -start=*)
    START="${i#*=}"
    shift
    ;;

    -end=*)
    STOP="${i#*=}"
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

    -s=*)
    SCRIPT="${i#*=}"
    shift
    ;;

    -target_folder=*)
    OUTPUT="${i#*=}"
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
        echo "Killing VNC"
        vncserver -kill ${DISPLAY}
    fi

    if [[ ! -z "$TMP_DIR" ]]; then
        rm -r ${TMP_DIR}
    fi
}

trap cleanup 0 1 2 3 6 15 EXIT

module load fiji/custom-ImageJ-1.51a
module load Tigervnc/1.9.0

# Handle our VNC displays
DISPLAY=$(vncstart)
export DISPLAY=${DISPLAY}
echo "Display is: ${DISPLAY}"

# Handle our camera
source ${WORKING_DIRECTORY}/${CAMERA}
echo "Camera is ${CAMERA}"

# Create our temporary directory
echo "copying file to local storage"
TMP_DIR=${TMPDIR}/${SLURM_JOB_ID}
mkdir ${TMP_DIR}
TMP_FILE="${TMP_DIR}/$(basename ${FILE})"

# Copy all files that this worker is likely to access
OLD_IFS=${IFS}
IFS=","
for file in ${FILES}; do
    cp ${file} ${TMP_DIR}/.
done
export IFS=${OLD_IFS}

# Fix all the permissions
chmod -R 777 ${TMP_DIR}

# Run the analysis
echo "Running localisation script with parameters: ImageJ-linux64 --plugins ${CUSTOM_PLUGINS_PATH} --ij2 --allow-multiple --no-splash -macro ${SCRIPT} ${OUTPUT}:${TMP_FILE}:${STEPS}:${START}:${STOP}:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}"
ImageJ-linux64 --plugins ${CUSTOM_PLUGINS_PATH} --ij2 --allow-multiple --no-splash -macro ${SCRIPT} ${OUTPUT}:${TMP_FILE}:${STEPS}:${START}:${STOP}:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}

echo "Finishing Localization time $(date)"

#vncserver -kill ${DISPLAY}
#rm -r ${TMP_DIR}
