#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=12:00:00
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

## do loop and process one-timestep at a time



}
