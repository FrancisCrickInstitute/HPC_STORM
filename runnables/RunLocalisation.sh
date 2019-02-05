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

esac
done

module load Fiji/1.51
module load Tigervnc/1.9.0
#module load X11/20160819-foss-2016b
#export DISPLAY=`vncserver 2>&1 | grep -oP '(?<=desktop is ).*'`
#echo "Display acquired: ${DISPLAY}"
#vncserver
DISPLAY=$(vncstart)
export DISPLAY=${DISPLAY}
echo "Display is: ${DISPLAY}"

source ${WORKING_DIRECTORY}/environmental_vars.sh

echo "copying file to local storage"
TMP_DIR=${TMPDIR}/${SLURM_JOB_ID}
mkdir
TMP_FILE="${TMP_DIR}/$(basename ${FILE})"
cp ${FILE} ${TMP_FILE}

echo "Running localisation script with parameters: ImageJ-linux64 -Dij1.plugin.dirs=${CUSTOM_PLUGINS_PATH}/.plugins --ij2 --allow-multiple --no-splash -port0 -macro ${SCRIPT} ${WORKING_DIRECTORY}:${TMP_FILE}:${STEPS}:${START}:${STOP}:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}"
ImageJ-linux64 --plugins ${CUSTOM_PLUGINS_PATH}/.plugins --ij2 --allow-multiple --no-splash -macro ${SCRIPT} ${WORKING_DIRECTORY}:${TMP_FILE}:${STEPS}:${START}:${STOP}:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}
#xvfb-run -d ImageJ-linux64 -Dij1.plugin.dirs=${CUSTOM_PLUGINS_PATH}/.plugins --ij2 --allow-multiple --no-splash -macro ${SCRIPT} ${WORKING_DIRECTORY}:${TMP_FILE}:${STEPS}:${START}:${STOP}:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}

echo "Finishing Localization time $(date)"

vncserver -kill ${DISPLAY}
rm -r ${TMP_DIR}

#export INDX=${PBS_ARRAY_INDEX:-1}
#export FRAMESTEP=`expr ${JPERNODE} \* ${NJOBS}`
#export PIDS
## run ThunderSTORM
## set > $WORK/loc_NodeScript$PBS_ARRAY_INDEX.log
#for i in `seq -s " " 1 ${JPERNODE}`
#do
#    (
#        echo "starting fiji, INDX = ${INDX}"
#        echo "sysconfcpus -n 48 fiji --ij2 -macro $HOME/Localisation/Loc_Macro.ijm ${WORK}:${FNAME}:${JOBNO}:${FRAMESTEP}:${INDX}:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}"
#        sysconfcpus -n 48 fiji --ij2 -macro $HOME/Localisation/Loc_Macro.ijm ${WORK}:${FNAME}:${JOBNO}:${FRAMESTEP}:${INDX}:${THREED}:${CAMERA:-Unknown}:${CALIB:-NULL}
#        echo "starting awk, INDX = ${INDX}, $(date)"
#        awk -v job_index=${INDX} -v job_no=${FRAMESTEP} 'BEGIN{FS=",";OFS=",";OFMT="%.2f"; getline }{$2=job_no*($2-1)+job_index; print $0}' ${TMPDIR}/tmp_${NAME}_slice_${INDX}.csv  > ${WORK}/${JOBNO}/tmp_${NAME}_${INDX}.csv
#        echo "done awk, INDX = ${INDX}, $(date)"
#    ) &
#    PIDS="${PIDS} $!"
#    INDX=`expr ${INDX} + ${NJOBS}`
#done
#
##echo "returned from Macro"
#
#trap "kill -15 $PIDS" 0 1 2 15
#echo "Started thunderstorm processes ${PIDS} $(date)"
#wait ${PIDS}
#echo "done thunderstorm processes ${PIDS} $(date)"
#
#if [ ${PBS_ARRAY_INDEX:-1} == 1 ]; then
#    head -1 ${TMPDIR}/tmp_${NAME}_slice_1.csv > ${WORK}/${JOBNO}/${NAME}.csv
#    cp ${TMPDIR}/tmp_${NAME}_slice_1-protocol.txt ${WORK}/${JOBNO}/${NAME}-protocol.txt
#fi
#
#echo "Finishing Localization time $(date)"

#vnc_stop
