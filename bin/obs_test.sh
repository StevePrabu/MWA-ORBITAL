#!/bin/bash

usage()
{
echo "test.sh [-o obsnum]
    -o  obsnum  : the obs id of the observation" 1>&2;
exit 1;
}

obsnum=

while getopts 'o:' OPTION
do
    case "$OPTION" in 
        o)
            obsnum=${OPTARG}
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
script="${MYBASE}/queue/test_${obsnum}.sh"
cat ${base}bin/test.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/test_${obsnum}.o%A"
error="${base}queue/logs/test_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J test_${obsnum} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted test job as ${jobid}"






