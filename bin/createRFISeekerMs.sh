#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=14:00:00
#SBATCH --ntasks=20
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

cd ${base}/processing/
mkdir ${obsnum}
cd ${obsnum}

## delete ms/uvfits if already exists
if [ -d ${obsnum}.ms ];
then
    rm -r ${obsnum}.ms
fi

if [ -f ${obsnum}.uvfits ];
then
    rm ${obsnum}.uvfits
fi

rm ${obsnum}*-*.fits

## create uvfits files
birli --no-geometric-delay --no-cable-delay -u ${obsnum}.uvfits -m ${obsnum}.metafits ${obsnum}*.fits

## create ms
cp /astro/mwasci/sprabu/path/PawseyPathFiles/uvfits2ms.py .
myCASA --norc -c uvfits2ms.py --uvfits ${obsnum}.uvfits --obs ${obsnum}

## delete intermediate ms and uvfits
rm -r ${obsnum}native_res.ms
rm ${obsnum}.uvfits

## apply solution
applysolutions ${obsnum}.ms ${calsol}

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}