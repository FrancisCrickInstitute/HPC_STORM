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

    -c=*)
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

trap cleanup 0 1 2 15 EXIT

#module load Fiji/1.51
module load fiji/custom-ImageJ-1.51a
module load Tigervnc/1.9.0
#module load X11/20160819-foss-2016b
#export DISPLAY=`vncserver 2>&1 | grep -oP '(?<=desktop is ).*'`
#echo "Display acquired: ${DISPLAY}"
#vncserver
DISPLAY=$(vncstart)
export DISPLAY=${DISPLAY}
echo "Display is: ${DISPLAY}"

source ${WORKING_DIRECTORY}/${CAMERA}

# Create our node local setip
echo "copying file to local storage"
TMP_DIR=${TMPDIR}/${SLURM_JOB_ID}
mkdir ${TMP_DIR}
TMP_FILE="${TMP_DIR}/$(basename ${FILE})"
cp ${FILE} ${TMP_FILE}
chmod -R 777 ${TMP_DIR}

# Create our output locations

echo "Running localisation script with parameters: ImageJ-linux64 --plugins ${CUSTOM_PLUGINS_PATH} --ij2 --allow-multiple --no-splash -macro ${SCRIPT} ${OUTPUT}:${TMP_FILE}:${STEPS}:${START}:${STOP}:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}"
ImageJ-linux64 --plugins ${CUSTOM_PLUGINS_PATH} --ij2 --allow-multiple --no-splash -macro ${SCRIPT} ${OUTPUT}:${TMP_FILE}:${STEPS}:${START}:${STOP}:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}

echo "Finishing Localization time $(date)"

#vncserver -kill ${DISPLAY}
#rm -r ${TMP_DIR}
