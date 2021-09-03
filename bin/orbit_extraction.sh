#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=24:00:00
#SBATCH --ntasks=20
#SBATCH --mem=124GB
#SBATCH --tmp=440GB
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
norad=NORAD
myPath=MYPATH

## copy files to nvme disk
cp -r ${base}/processing/${obsnum}/${obsnum}.ms /nvmetmp
cp ${base}/processing/${obsnum}/${obsnum}.metafits /nvmetmp

## determine number of time-steps
cd /nvmetmp
cp ${myPath}/getTimeStepsFromMS.py /nvmetmp
PyLEO ./getTimeStepsFromMS.py --ms ${obsnum}.ms

source tmp.txt

echo "timeSteps found" ${TIMESTEPS} " and integration time " ${INTTIME}
updatedTIMESTEPS=$(($TIMESTEPS-1)) ## cos indexes start from zero
channels=768 ## hard coded 
updatedCHANNELS=$(($channels-1))

cp /home/sprabu/RFISeeker/RFISeeker /nvmetmp

## loop and process one-timestep at a time
for ((g=0;g<=${updatedTIMESTEPS};g++));
do
    echo "working on timeStep " ${g}
    startt=`date +%s`

    ## make images required for this time-step at every fine channel
    ## first try make with wsclean -channels out 
    ## it if fails, image one channel at a time (slower, hence is not default!)
    
    i=$((g*1))
    j=$((i+1))

    wsclean -quiet -name ${obsnum}-2m-${i} -size 1400 1400\
            -abs-mem 120 -interval ${i} ${j} -channels-out ${channels}\
            -weight natural -scale 5amin -use-wgridder -no-dirty ${obsnum}.ms
    ## check if failed??
    if [ $? -eq 0 ];
    then
        echo "wsclean -channels out run sucessfully"
    else
        echo "wsclean -chanels out failed"
        echo "reimaing one fine channel at time"

        ## spawn n number of jobs parallely
        for f in `seq 0 ${updatedCHANNELS}`;
        do
            f1=$((f*1))
            f2=$((f1+1))

            while [[ $(jobs | wc -l) -ge 20 ]]
            do
                wait -n $(jobs -p)
            done

            ## unique temporary dump folder for every channel and time-step
            mkdir temp_${g}_${f} 
            name=`printf %04d $f`

            wsclean -quiet -name ${obsnum}-2m-${i}-${name} -size 1400 1400\
                        -temp-dir temp_${g}_${f} -abs-mem 5 -interval ${i} ${j}\
                        -channel-range ${f1} ${f2} -weight natural -scale 5amin\
                        -use-wgridder -no-dirty ${obsnum}.ms &

        done

        ## wait for all pids before continuing
        b=0
        for job in `jobs -p`
        do
            pids[${b}]=${job}
            b=$((b+1))
        done
        for pid in ${pids[*]}; do
            wait ${pid}
        done

    
    endt=`date +%s`
    runtimet=$((endt-startt))
    echo "the imaging run time ${runtimet}"

    ## break out to next iteration if this is the first time-step
    if [ ${g} -eq 0 ]; then
        echo "this is the first time-step. continuing to next iteration.."
        continue
    fi
    
    startt=`date +%s`
    ## run RFISeeker in parallel (for positive and negative source extraction)
    python_rfi ./RFISeeker --obs ${obsnum} --freqChannels ${channels} --seedSigma 6\
                --floodfillSigma 3 --timeStep $((g-1)) --prefix 6Sigma3Floodfill\
                --imgSize 1400 --streak head --ext image &
    PID1=$!

    python_rfi ./RFISeeker --obs ${obsnum} --freqChannels ${channels} --seedSigma 6\
                --floodfillSigma 3 --timeStep $((g-1)) --prefix 6Sigma3Floodfill\
                --imgSize 1400 --streak Tail --ext image &
    PID2=$!

    wait ${PID1}    
    wait ${PID2}

    endt=`date +%s`
    runtimet=$((endt-startt))
    echo "the RFISeeker run time ${runtimet}"

    ## clear files before proceeding to next time-step
    rm -r temp_*
    prevIndex=$((${g}-1))
    rm ${obsnum}-2m-${prevIndex}-*.fits

done

## copy files back to 
cp *RFI*.fits ${base}/processing/${obsnum}/

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
