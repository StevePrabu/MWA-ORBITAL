#!/bin/bash

#################### Description ######################
# this job is intended to autonomously perfrom shift-stack 
# search for the object of interest


usage()
{
echo "obs_shiftstack.sh [-o obsnum] [-n norad]
    -o obsnum       : the obsid
    -n norad        : the norad id" 1>&2;
exit 1;
}


obsnum=
norad=

while getopts 'o:n:' OPTION
do
    case "$OPTION" in
        o)
            obsnum=${OPTARG}
            ;;
        n)
            norad=${OPTARG}
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
script="${MYBASE}/queue/pyshiftstack_${obsnum}.sh"
cat ${base}bin/pyshiftstack.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:NORAD:${norad}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/pyshiftstack_${obsnum}${norad}.o%A"
error="${base}queue/logs/pyshiftstack_${obsnum}${norad}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J pyshiftstack_${obsnum}_${norad} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted pyshiftstack job as ${jobid}"

