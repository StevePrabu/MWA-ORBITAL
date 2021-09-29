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
norad=NORAD

cd ${base}/processing/${obsnum}

## determine number of time-steps
cp ${myPath}/getTimeStepsFromMS.py ${base}/processing/${obsnum}
PyLEO ./getTimeStepsFromMS.py --ms ${obsnum}.ms

source tmp.txt

echo "timeSteps found" ${TIMESTEPS} " and integration time " ${INTTIME}
updatedTIMESTEPS=$(($TIMESTEPS-1)) ## cos indexes start from zero

## extract angular position measurements of the pass
cp ${myPath}/extractAngularMeasurements.py ${base}/processing/${obsnum}
myPython3 ./extractAngularMeasurements.py --obs ${obsnum} --norad ${norad} --beamFile ${base}/models/beam.fits --user ${spaceTrackUser} --passwd ${spaceTrackPassword} --debug True

## create initial guess for orbit determination
cp ${myPath}/createConfig.py ${base}/processing/${obsnum}
myPython3 ./createConfig.py --noradid ${norad} --wcsFile 6Sigma1FloodfillSigmaRFIBinaryMap-t0000.fits --debug True --user ${spaceTrackUser} --passwd ${spaceTrackPassword}

## perform orbit determination
cp ${myPath}/orbitFit.py ${base}/processing/${obsnum}
myPython3 ./orbitFit.py --obs ${obsnum} --norad ${norad} --config auto_created_config${norad}.yaml --wcsFile 6Sigma1FloodfillSigmaRFIBinaryMap-t0000.fits --debug True


end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
