#!/bin/bash

#################### Description ######################
# this job is intended to autonomously extract angular
# pass information for a given norad id. Bellow are 
# the steps involved
# 1) image at every fine channel and time-step (on nvme disk)
# 2) run RFISeeker to extract positive and negative contours
# 3) generate primary beam
# 4) extract measurements and position uncertainities


usage()
{
echo "obs_orbit_extraction.sh [-o obsnum] [-d dependancy] [-n norad id]
    -o obsnum       : the obsid
    -d dependancy   : dependant job id
    -n  norad id    : the norad id to extract measurements" 1>&2;
exit 1;
}


obsnum=
dep=
norad=

while getopts 'o:d:n:' OPTION
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
        ? | : | h)
            usage
            ;;
    esac
done

# if obsid or norad id is empty, the print help
if [[ -z ${obsnum} ]]
then
    echo "obs id not provided."
    usage
fi

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
script="${MYBASE}/queue/orbit_extraction_${obsnum}.sh"
cat ${base}bin/orbit_extraction.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:MYPATH:${MYPATH}:g" \
                                -e "s:NORAD:${norad}:g"> ${script}
output="${base}queue/logs/orbit_extraction_${obsnum}.o%A"
error="${base}queue/logs/orbit_extraction_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J orbit_extraction_${obsnum}_${norad} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted orbit_extraction job as ${jobid}"

