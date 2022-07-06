#!/bin/bash

############### Description #####################
# this job is supposed to create measurement sets
# of the new mwax spacefest 2021 observations
# Below are the steps involved
# 1) create uvfits using birli
# 2) use casa to convert uvfits to ms
# 3) perform channel averaging to donwsample from
# 10kHz to 40kHz fine channel resolution
# 4) delete uvfits

usage()
{
echo "obsuvfits2ms.sh [-o obsnum] [-c calsol]
    -o  obsnum  : the obs id of the observation
    -c calsol   : the calibration solution" 1>&2;
exit 1;
}

obsnum=
calsol=

while getopts 'o:c:' OPTION
do
    case "$OPTION" in 
        o)
            obsnum=${OPTARG}
            ;;
        c)
            calsol=${OPTARG}
            ;;
        ? | : | h)
            usage
            ;;
    esac
done

## pring for help if obsid of asvojobid is not provided
if [[ -z ${obsnum} ]]
then
    echo "obs id not provided."
    usage
fi


## load configurations
source bin/config.txt

## run template script
script="${MYBASE}/queue/uvfits2ms_${obsnum}.sh"
cat ${base}bin/uvfits2ms.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:CALSOL:${calsol}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/uvfits2ms_${obsnum}.o%A"
error="${base}queue/logs/uvfits2ms_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J uvfits2ms_${obsnum} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted uvfits2ms job as ${jobid}"






