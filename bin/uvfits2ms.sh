#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=20:00:00
#SBATCH --ntasks=36
#SBATCH --mem=248GB
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
calsol=CALSOL

cd ${base}/processing/${obsnum}

## uvfits 2 ms
#birli -m ${obsnum}.metafits --max-memory 235 --avg-freq-res 40 --avg-time-res 0.25 --no-rfi -M ${obsnum}.ms ${obsnum}_*.fits

## applysolution
applysolutions ${obsnum}.ms ${calsol}

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}

