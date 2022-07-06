#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=18
#SBATCH --mem=124GB
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
asvoJobID=ASVOJOBID

cd ${base}/processing/
mkdir ${obsnum}
cd ${obsnum}
rm -r ${obsnum}.ms

# ## copy over files from /asvo
# cp /astro/mwasci/asvo/${asvoJobID}/* .
# ## clear /asvo
# rm -r /astro/mwasci/asvo/${asvoJobID}

## run cotter and create ms
cotter -norfi -initflag 2 -timeres 2 -freqres 40 *gpubox* -allowmissing -flagdcchannels \
        -absmem 120 -edgewidth 80 -m ${obsnum}.metafits -o ${obsnum}.ms

## applysolutions if provided
if [[ -z ${calsol} ]]
then
    echo "calibration solution not provided. Skipping applying solution"
else
    applysolutions ${obsnum}.ms ${calsol}
fi



end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}

