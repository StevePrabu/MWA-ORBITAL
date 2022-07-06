#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=6:00:00
#SBATCH --ntasks=12
#SBATCH --mem=60GB
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

cd ${base}/processing/${obsnum}

wsclean -name ${obsnum} -size 1400 1400 -abs-mem 55 -weight natural -scale 5amin -niter 10000 -mgain 0.8\
    -auto-threshold 1.5 ${obsnum}.ms

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
