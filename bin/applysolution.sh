#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=12
#SBATCH --mem=20GB
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
calibration=CALIBRATIONSOL

cd ${base}/processing/${obsnum}
applysolutions ${obsnum}.ms ${calibration}

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
