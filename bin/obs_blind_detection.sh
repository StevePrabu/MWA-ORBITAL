#!/bin/bash

#################### Description ######################
# this job is intended to autonomously perform blind detections
# Bellow are the steps involved
# 1) run satSearch to find all detections
# 2) extract angular position measurements for all objects detected


usage()
{
echo "obs_blind_detection.sh [-o obsnum] [-d dependancy]
    -o obsnum       : the obsid
    -d dependancy   : dependant job id" 1>&2;
exit 1;
}


obsnum=
dep=

while getopts 'o:d:' OPTION
do
    case "$OPTION" in
        o)
            obsnum=${OPTARG}
            ;;
        d)
            dep=${OPTARG}
            ;;
        ? | : | h)
            usage
            ;;
    esac
done

# if obsid id is empty, the print help
if [[ -z ${obsnum} ]]
then
    echo "obs id not provided."
    usage
fi

if [[ ! -z ${dep} ]]
then
    depend="--dependency=afterok:${dep}"
fi

## load configurations
source bin/config.txt

## run template script
script="${MYBASE}/queue/blind_detection_${obsnum}.sh"
cat ${base}bin/blind_detection.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/blind_detection_${obsnum}.o%A"
error="${base}queue/logs/blind_detection_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J blind_detection_${obsnum} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted blind_detection job as ${jobid}"

