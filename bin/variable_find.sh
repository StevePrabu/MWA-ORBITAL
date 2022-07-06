#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=14:00:00
#SBATCH --ntasks=18
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
myPath=MYPATH

## start monitoring resource usage
cd /nvmetmp

## copy files to nvme disk
cp -r ${base}/processing/${obsnum}/${obsnum}.ms /nvmetmp

## delete previous pngs and cubes
rm ${base}/processing/${obsnum}/*.png
rm ${base}/processing/${obsnum}/*.npy

## determine number of time-steps
cd /nvmetmp
cp ${myPath}/getTimeStepsFromMS.py /nvmetmp
PyLEO ./getTimeStepsFromMS.py --ms ${obsnum}.ms

source tmp.txt

echo "timeSteps found" ${TIMESTEPS} " and integration time " ${INTTIME}
updatedTIMESTEPS=$(($TIMESTEPS-1)) ## cos indexes start from zero
channels=768 ## hard coded 
updatedCHANNELS=$(($channels-1)) ## cos indexes start from zero

cp /home/sprabu/RFISeeker/VariableFinder /nvmetmp

wsclean -quiet -name img -size 1400 1400 -scale 5amin -weight uniform \
            -use-wgridder -no-dirty ${obsnum}.ms

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
            -weight uniform -scale 5amin -use-wgridder -theoretic-beam -no-dirty ${obsnum}.ms

    ## check if failed??
    if [ $? -eq 0 ];
    then
        echo "wsclean -channels-out ran sucessfully"
    else
        exit 0
        echo "wsclean -chanels-out failed"
        echo "re-imaging one fine channel at time (slow!)"

        ### spawn n number of jobs parallely
        for f in `seq 0 ${updatedCHANNELS}`;
        do
            f1=$((f*1))
            f2=$((f1+1))
        
            while [[ $(jobs | wc -l) -ge 18 ]]
            do
                wait -n $(jobs -p)
            done
        
            ## unique temporary dump folder for every channel and time-step
            mkdir temp_${g}_${f} 
            name=`printf %04d $f`
        
            wsclean -quiet -name ${obsnum}-2m-${i}-${name} -size 1400 1400\
                        -temp-dir temp_${g}_${f} -abs-mem 5 -interval ${i} ${j}\
                        -channel-range ${f1} ${f2} -weight uniform -scale 5amin\
                        -use-wgridder -no-dirty -theoretic-beam ${obsnum}.ms &
        
        done
        
        ## wait for all pids before continuing
        b=0
        for job in `jobs -p`
        do
            if [ ${job} -eq ${monitorPID} ]; then
                continue
            fi
            pids[${b}]=${job}
            b=$((b+1))
        done
        for pid in ${pids[*]}; do
            wait ${pid}
        done

    fi
    
    endt=`date +%s`
    runtimet=$((endt-startt))
    echo "the imaging run time ${runtimet}"

    ## break out to next iteration if this is the first time-step
    if [ ${g} -eq 0 ]; then
        echo "this is the first time-step. continuing to next iteration.."
        continue
    fi
    
    startt=`date +%s`
    ## run VariableFinder in parallel (for positive and negative source extraction)
    python_rfi ./VariableFinder --obs ${obsnum} --freqChannels 768 --timeStep $((g-1)) \
                --floodfillSigma 3 --seedSigma 6 --imgSize 1400 --streak head \
                --enable True --ext image --verbose True --horizonMaskAngle 10 \
                --dirtyImg img-image.fits --freqCutOff 86 --prefix 6Sigma1Floodfill &
    
    PID1=$!

    python_rfi ./VariableFinder --obs ${obsnum} --freqChannels 768 --timeStep $((g-1)) \
                --floodfillSigma 3 --seedSigma 6 --imgSize 1400 --streak tail \
                --ext image --verbose True --horizonMaskAngle 10 \
                --dirtyImg img-image.fits --freqCutOff 86 --prefix 6Sigma1Floodfill &

    PID2=$!

    wait ${PID1}    
    wait ${PID2}

    endt=`date +%s`
    runtimet=$((endt-startt))
    echo "the VariableFind run time ${runtimet}"

    ## clear files before proceeding to next time-step
    rm -r temp_*
    prevIndex=$((${g}-1))
    rm ${obsnum}-2m-${prevIndex}-*.fits

done


## copy files back to 
cp *6Sigma1Floodfill*.fits ${base}/processing/${obsnum}/
cp *.png ${base}/processing/${obsnum}/
cp *.txt ${base}/processing/${obsnum}/
cp *.npy ${base}/processing/${obsnum}/

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}


