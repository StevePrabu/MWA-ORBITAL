#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=8
#SBATCH --mem=16GB
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

for ((i=10; i<20; i++));
do
    a=${i}
    b=$((a+1))
    wsclean -name ${obsnum}-${a} -interval ${a} ${b} -channels-out 768 -no-dirty -weight natural -size 200 200 -scale 5amin ${obsnum}.ms

done


end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}