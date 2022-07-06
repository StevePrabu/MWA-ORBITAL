#!/bin/bash
usage()
{
echo "obs_image.sh [-o obsnum]
    -o  obsnum  : the observation id" 1>&2;
exit 1;
}

obsnum=
account="mwasci"
machine="garrawarla"

while getopts "o:" OPTION
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

# pring for help if obsid not given
if [[ -z ${obsnum} ]]
then
    usage
fi

## load configurations
source bin/config.txt

## run template script
script="${MYBASE}/queue/image_${obsnum}.sh"
cat ${base}bin/image.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/image_${obsnum}.o%A"
error="${base}queue/logs/image_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J image_${obsnum} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted image job as ${jobid}"

