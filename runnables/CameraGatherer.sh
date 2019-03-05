#!/usr/bin/env bash

for i in "$@"
do
case ${i} in

    -f=*)
    FILE="${i#*=}"
    shift
    ;;

    -c=*)
    CAMERA_RAW="${i#*=}"
    shift
    ;;

    -w=*)
    WORKING_DIRECTORY="${i#*=}"
    shift
    ;;

    -o=*)
    OUT="${i#*=}"
    shift
    ;;

esac
done

ml LibTIFF/4.0.4-foss-2016b

# We should use the user provided as cannon
if [[ -z "$CAMERA_RAW" ]]; then
    # Use tiffinfo to assess our detector
    CAMERAstring=$(tiffinfo -0 ${FILE} 2> /dev/null | grep Detector |  sed 's/^.*Detector ID="// ; s/".*$//' | tr " " "_")
    echo "Camera String: ${CAMERAstring}"
    case ${CAMERAstring} in
        *Prime95B*) CAMERA="Prime95B" ;;
        *Andor_iXon_Ultra*) CAMERA="Andor_iXon_Ultra" ;;
        *pco_camera*) CAMERA="pco_camera" ;;
        *Andor_sCMOS_Camera*) CAMERA="Andor_sCMOS_Camera" ;;
        *Grasshopper3_GS3-U3-23S6M*) CAMERA="Grasshopper3_GS3-U3-23S6M" ;;
        *) CAMERA="Unknown" ;;
    esac
else
    CAMERA=${CAMERA_RAW}
fi

# Store the camera variable
echo "export CAMERA=${CAMERA}" > ${WORKING_DIRECTORY}/${OUT}
