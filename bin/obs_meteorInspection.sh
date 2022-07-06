#!/bin/bash

################## Description ###################
# this job is intended to make fine channel dirty 
# images for a given time-step for perform spectral
# index weighted MFS for meteors.

usage()
{
    echo "obs_meteorInspection.sh [-o obsnum] [-t timestep] [-r new ra] [-d new dec]
    -o obsnum   : the observation id
    -r  new ra  : the new ra (format 00h00m00.0s)
    -d  new dec : the new dec (format 00d00m00.0s)
    -t timestep : the timestep to image" 1>&2;
exit 1;
}

obsnum=
timestep=
ra=
dec=

while getopts 'o:t:r:d:' OPTION
do
    case "$OPTION" in
        o)
            obsnum=${OPTARG}
            ;;
        t)
            timestep=${OPTARG}
            ;;
        r)
            ra=${OPTARG}
            ;;
        d)
            dec=${OPTARG}
            ;;
        ? | : | h)
            usage
            ;;
    esac
done

# if obsid id or tiemstep is empty, the print help
if [[ -z ${obsnum} ]]
then
    echo "obs id not provided."
    usage
fi

if [[ -z ${timestep} ]]
then
    echo "time-step not provided."
    usage
fi

## load configurations
source bin/config.txt

echo "the new ra " ${ra} " and dec " ${dec}

## run template 
script="${MYBASE}/queue/meteorInspection_${obsnum}.sh"
cat ${base}bin/meteorInspection.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:TIMESTEP:${timestep}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/meteorInspection_${obsnum}.o%A"
error="${base}queue/logs/meteorInspection_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J meteorInspection_${obsnum} -M ${MYCLUSTER} ${script} -r ${ra} -d ${dec}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted meteorInspection job as ${jobid}"