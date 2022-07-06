#!/bin/bash

usage()
{
    echo "obs_cotter.sh [-o obsnum] [-c cal sol] [-j asvojobid]
    -o  obsnum      : the observation id
    -j  asvojobid   : the asvo job id
    -c cal sol      : the calibration solution" 1>&2;
exit 1;
}

obsnum=
calsol=
asvoJobID=

while getopts 'o:c:j:' OPTION
do
    case "$OPTION" in
        o)
            obsnum=${OPTARG}
            ;;
        c)
            calsol=${OPTARG}
            ;;
        j)
            asvoJobID=${OPTARG}   
            ;;
        ? | : | h)
            usage
            ;;
    esac
done


# if obsid or link is empty then just pring help
if [[ -z ${obsnum} ]]
then
    usage
fi


## load configurations
source bin/config.txt

## run template script
script="${MYBASE}/queue/cotter_${obsnum}.sh"
cat ${base}bin/cotter.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:CALSOL:${calsol}:g" \
                                -e "s:ASVOJOBID:${asvoJobID}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/cotter_${obsnum}.o%A"
error="${base}queue/logs/cotter_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} -J cotter_${obsnum} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted cotter job as ${jobid}"


