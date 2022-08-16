#!/bin/bash

#################### Description ######################
# this job is intended to autonomously perfrom shift-stack 
# search for the object of interest


usage()
{
echo "obs_shiftstack.sh [-o obsnum] [-n norad] [-s search radius] [-p phase correction] [-d dependancy] [-i integration time]
    -o obsnum       : the obsid
    -n norad        : the norad id
    -i int time     : the integration time in ms
    -s search radius: the shift-stack search radius measured from pointing centre (default=18 deg)
    -p phase corec  : apply near-field phase correction using LEOVision (default=False)
    -d dependancy   : dependant job id" 1>&2;
exit 1;
}


obsnum=
dep=
norad=
inttime=
searchRadius=18
phaseCorrection=false

while getopts 'o:d:n:s:p:i:' OPTION
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
            searchRadius=${OPTARG}
            ;;
        p)
            phaseCorrection=true
            ;;
        i)
            inttime=${OPTARG}
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


# if inttime is empty, the print help
if [[ -z ${inttime} ]]
then
    echo "integration time not provided."
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
script="${MYBASE}/queue/shiftstack_${obsnum}.sh"
cat ${base}bin/shiftstack.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:NORAD:${norad}:g" \
                                -e "s:PHASECORRECTION:${phaseCorrection}:g" \
                                -e "s:SEARCHRADIUS:${searchRadius}:g" \
                                -e "s:INTTIME:${inttime}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/shiftstack_${obsnum}${norad}.o%A"
error="${base}queue/logs/shiftstack_${obsnum}${norad}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J shiftstack_${obsnum}_${norad} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted shiftstack job as ${jobid}"

