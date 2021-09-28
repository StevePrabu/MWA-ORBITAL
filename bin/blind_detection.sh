#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=4:00:00
#SBATCH --ntasks=2
#SBATCH --mem=10GB
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
cd ${base}/processing/${obsnum}
cp ${myPath}/monitor.py .
myPython3 ./monitor.py --name blind_detection_usage --sleepTime 1 &
monitorPID=$!


## determine number of time-steps
cp ${myPath}/getTimeStepsFromMS.py ${base}/processing/${obsnum}
PyLEO ./getTimeStepsFromMS.py --ms ${obsnum}.ms

source tmp.txt

echo "timeSteps found" ${TIMESTEPS} " and integration time " ${INTTIME}
updatedTIMESTEPS=$(($TIMESTEPS-1)) ## cos indexes start from zero

## run sat search
cp ${myPath}/satSearch.py ${base}/processing/${obsnum}

myPython3 ./satSearch.py --t1 0 --t2 ${updatedTIMESTEPS} --user ${spaceTrackUser} --passwd ${spaceTrackPassword} --debug True

## kill monitor
kill -p ${monitorPID}

## copy files back to 
cp *RFI*.fits ${base}/processing/${obsnum}/
cp *.csv ${base}/processing/${obsnum}/
cp *.txt ${base}/processing/${obsnum}/

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
