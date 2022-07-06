#!/bin/bash

#################### Description ######################
# this job is intended to autonomously extract light curve

usage()
{
echo "obs_lightcurve.sh [-o obsnum] [-n norad] [-c tlecatalog] [-d dependancy] 
    -o obsnum       : the obsid
    -n norad        : the norad id
    -c tlecatalog   : the input tle catalog
    -d dependancy   : dependant job id" 1>&2;
exit 1;
}


obsnum=
dep=
norad=
tlecatalog=

while getopts 'o:d:n:c:' OPTION
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
        c)
            tlecatalog=${OPTARG}
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
script="${MYBASE}/queue/lightcurve_${obsnum}.sh"
cat ${base}bin/lightcurve.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${MYBASE}:g" \
                                -e "s:NORAD:${norad}:g" \
                                -e "s:TLECATALOG:${tlecatalog}:g" \
                                -e "s:MYPATH:${MYPATH}:g"> ${script}

output="${base}queue/logs/lightcurve_${obsnum}${norad}.o%A"
error="${base}queue/logs/lightcurve_${obsnum}${norad}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} ${depend} -J extract_lightcurve_${obsnum}_${norad} -M ${MYCLUSTER} ${script}"
jobid=($(${sub}))
jobid=${jobid[3]}

# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid}/"`
output=`echo ${output} | sed "s/%A/${jobid}/"`

echo "Submitted lightcurve job as ${jobid}"

