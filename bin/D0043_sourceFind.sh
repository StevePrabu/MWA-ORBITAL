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
rm ${base}/processing/${obsnum}/detections*.fits
rm ${base}/processing/${obsnum}/detections*.csv
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
    startt=`date +%s`
    
    i=$((g*1))
    j=$((i+1))

    ### spawn 4 wsclean jobs at a time
    #while [[ $(jobs | wc -l) -ge 4 ]]
    #do
    #    wait -n $(jobs -p)
    #done

    time wsclean -quiet -name ${obsnum}-2m-${i} -size 750 750\
     -scale 6amin -weight natural -abs-mem 80 -interval ${i} ${j}\
     -channels-out ${channels} -no-dirty -maxuvw-m 500 ${obsnum}.ms

    ## check if failed??
    if [ $? -eq 0 ];
    then
        echo "wsclean -channels-out ran sucessfully"
    else
        exit 0
    fi

    #### copy all images back to /astro
    #cp *image.fits ${base}/processing/${obsnum}/

    ## run source Find
    cp /astro/mwasci/sprabu/D0043_tools/freqDiffMap.plk /nvmetmp
    cp /astro/mwasci/sprabu/D0043_tools/sourceFind.py /nvmetmp
    myPython3 sourceFind.py --timeStep ${i} --freqDiffConfig freqDiffMap.plk --imgSize 750 --seedSigma 6 --floodfillSigma 3 --obs ${obsnum}
    cp detections*.fits ${base}/processing/${obsnum}/
    cp detections*.csv ${base}/processing/${obsnum}/


    rm *.fits

done

# ## wait for all wsclean jobs to terminate
# i=0
# for job in `jobs -p`
# do
#     pids[${i}]=${job}
#     i=$((i+1))
# done
# for pid in ${pids[*]}; do
#     wait ${pid}
# done

### copy all images back to /astro
cp *image.fits ${base}/processing/${obsnum}/


end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
