#!/bin/bash

##### description ###############
# this jobs is to convert input raw fits
# to first uvfits (using birli) then forllowed
# by using casa to create ms. It will also apply
# the calibration solution

usage()
{
echo "sf21_createRFISeekerMs.sh [-o obsnum] -[-c cal sol]
    -o obsnum   : the obs id of the observation
    -c cal sol  : the calibration solution" 1>&2;
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


## pring for help if obsid or cal solution not provided
if [[ -z ${obsnum} ]]
then
    echo "obs id not provided."
    usage
fi

if [[ -z ${calsol} ]]
then
    echo "cal sol not provided."
    usage
fi

## load configurations
source bin/config.txt

## run template script
script="${MYBASE}/queue/createRFISeekerMs_${obsnum}.sh"
cat ${base}bin/createRFISeekerMs.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:CALSOL:${calsol}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/createRFISeekerMs_${obsnum}.o%A"
error="${base}queue/logs/createRFISeekerMs_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J createRFISeekerMs_${obsnum} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted createRFISeekerMs job as ${jobid}"