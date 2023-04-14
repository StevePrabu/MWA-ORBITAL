#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --nodes=1
#SBATCH --time=12:00:00
#SBATCH --ntasks=36
#SBATCH --mem=345GB
#SBATCH --tmp=864GB
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

datadir=${base}/processing/${obsnum}

cd ${datadir}
rm -r ${norad}
mkdir ${norad}


## copy files to nvme disk
cp -r ${datadir}/${obsnum}.ms /nvmetmp
cp ${datadir}/${obsnum}.metafits /nvmetmp

cd /nvmetmp

## run track.py
cp ${myPath}/track.py /nvmetmp
cp /astro/mwasci/sprabu/satellites/MWA-ORBITAL/tles/${norad}${obsnum}.txt /nvmetmp
myPython3 ./track.py --obs ${obsnum} --metafits ${datadir}/${obsnum}.metafits --searchRadius 18 --noradid ${norad} \
  --user ${spaceTrackUser} --passwd ${spaceTrackPassword} --debug True \
  --integration 0.25

## split ms to just the required timesteps. Having a smaller ms drastically reduces the runtime of the job
cp ${myPath}/splitMS.py /nvmetmp
myCASA --nologfile --nogui --agg --norc -c splitMS.py --config ${obsnum}-${norad}.csv \
      --inputMS ${obsnum}.ms --outputMS ${obsnum}split.ms

## replace the large ms with the smller split ms
rm -r ${obsnum}.ms
mv ${obsnum}split.ms ${obsnum}.ms

## delete old config, and make new config for new ms
rm ${obsnum}-${norad}.csv
myPython3 ./track.py --obs ${obsnum} --metafits ${datadir}/${obsnum}.metafits --searchRadius 18 --noradid ${norad} \
  --user ${spaceTrackUser} --passwd ${spaceTrackPassword} --debug True \
  --integration 0.25

## run pyshiftstack
cp ${myPath}/pyShiftStack.py /nvmetmp
myPython3 ./pyShiftStack.py --ms ${obsnum}.ms --config ${obsnum}-${norad}.csv --metafits ${obsnum}.metafits --cores 30

## generate freq dif mapping
cp ${myPath}/FMinWA.txt /nvmetmp
cp ${myPath}/generateFreqDiffMapping.py /nvmetmp
myPython3 ./generateFreqDiffMapping.py --ms ${obsnum}.ms --path2transmitters /nvmetmp/FMinWA.txt 

## make stacked image cube
cp ${myPath}/makeFreqCube.py /nvmetmp
myPython3 ./makeFreqCube.py --obs ${obsnum} --noradid ${norad} --user ${spaceTrackUser} --passwd ${spaceTrackPassword} --freqDiffMap freqDiffMap.plk

### copy data over back to /astro
cp *.npy ${datadir}/${norad}
cp *.csv ${datadir}/${norad}
cp *.png ${datadir}/${norad}
cp *.txt ${datadir}/${norad}
#cp *.fits ${datadir}/${norad}

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
