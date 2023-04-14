#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=24:00:00
#SBATCH --ntasks=36
#SBATCH --mem=345GB
#SBATCH --tmp=864GB
#SBATCH --nodes=1
#SBATCH --mail-type FAIL,TIME_LIMIT
#SBATCH --mail-user sirmcmissile47@gmail.com


start=`date +%s`

module load singularity
shopt -s expand_aliases
source /astro/mwasci/sprabu/aliases

set -x
{

obsnum=OBSNUM
base=BASE
myPath=MYPATH

## Step 0) copy data over to /nvme
cp -r ${base}/processing/${obsnum}/${obsnum}.ms /nvmetmp
cp ${base}/processing/${obsnum}/${obsnum}.metafits /nvmetmp
cp ${base}/processing/${obsnum}/detections-t*.csv /nvmetmp
cp ${base}/processing/${obsnum}/detections-t*.fits /nvmetmp
cp /astro/mwasci/sprabu/D0043_tools/ranging.py /nvmetmp
rm ${base}/processing/${obsnum}/event-t-*.png
cd /nvmetmp

## Step 1) determine the number of time-steps in ms
cd /nvmetmp
cp ${myPath}/getTimeStepsFromMS.py /nvmetmp
PyLEO ./getTimeStepsFromMS.py --ms ${obsnum}.ms

source tmp.txt

echo "timeSteps found" ${TIMESTEPS} " and integration time " ${INTTIME}
updatedTIMESTEPS=$(($TIMESTEPS-1)) ## cos indexes start from zero
channels=768 ## hard coded 
updatedCHANNELS=$(($channels-1)) ## cos indexes start from zero

## Step 2) iterate over time-steps and create images
for ((g=0;g<=${updatedTIMESTEPS};g++));
do
    echo "working on timeStep " ${g}

    while [[ $(jobs | wc -l) -ge 30 ]]
    do
        wait -n $(jobs -p)
    done
    printf -v za '%04d' "$g"
    myPython3 ranging.py --ms ${obsnum}.ms --metafits ${obsnum}.metafits\
     --catalogue detections-t${za}.csv --timeStep ${g} &


done

i=0
for job in `jobs -p`
do
        pids[${i}]=${job}
        i=$((i+1))
done
for pid in ${pids[*]}; do
        wait ${pid}
done

# copy back the images
cp *.png ${base}/processing/${obsnum}

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
