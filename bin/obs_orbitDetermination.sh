#!/bin/bash

#################### Description ######################
# this job is intended to autonomously obtain the angular positions of 
# satellite pass and perfrom orbit determination


usage()
{
echo "obs_orbitDetermination.sh [-o obsnum] [-n norad] [-d dependancy] [-s skip ext]
    -o obsnum       : the obsid
    -n norad        : the norad id
    -s skip ext     : skips running extractAngularMeasurements.py (default False)
    -d dependancy   : dependant job id" 1>&2;
exit 1;
}


obsnum=
dep=
norad=
skip=false

while getopts 'o:d:n:s:' OPTION
do
    case "$OPTION" in
        o)
            obsnum=${OPTARG}
            ;;
        d)
            dep=${OPTARG}
            ;;
        n)
            norad=${OPTARG}
            ;;
        s)
            skip=true
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

# if norad id is empty, the print help
if [[ -z ${norad} ]]
then
    echo "norad id not provided."
    usage
fi

if [[ ! -z ${dep} ]]
then
    depend="--dependency=afterok:${dep}"
fi

## load configurations
source bin/config.txt

## run template script
script="${MYBASE}/queue/orbitDetermination_${obsnum}.sh"
cat ${base}bin/orbitDetermination.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:NORAD:${norad}:g" \
                                -e "s:SKIP:${skip}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/getSatPass_${obsnum}.o%A"
error="${base}queue/logs/getSatPass_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J orbitDetermination_${obsnum}_${norad} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted orbitDetermination job as ${jobid}"

