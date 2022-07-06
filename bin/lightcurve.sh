#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=23:00:00
#SBATCH --ntasks=18
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
myPath=MYPATH
norad=NORAD
tlecatalog=TLECATALOG

datadir=${base}/processing/${obsnum}

cd ${datadir}
mkdir ${norad}

## copy files to nvme disk
cp -r ${datadir}/${obsnum}.ms /nvmetmp

cd /nvmetmp

## run track.py
cp ${myPath}/light_curve_track.py /nvmetmp
myPython ./light_curve_track.py --obs ${obsnum} --metafits ${datadir}/${obsnum}.metafits\
  --noradid ${norad} --inputTLEcatalog ${tlecatalog} --integration 0.5

### make images along phase
tarray=
while IFS=, read -r col1 col2 col3 col4 col5 col6
do
    ah=$((col1))
    bh=$((ah+1))
    bt=$((col1))
    at=$((bt-1))
    tarray=(${tarray[@]} ${col1})
    echo ${tarray}
    echo ${tarray[@]}
    chgcentre ${obsnum}.ms ${col2} ${col3}
        
    wsclean -name ${obsnum}-2m-${col1} -size 200 200 -scale 5amin \
        -interval ${ah} ${bh} -channels-out 768 -weight natural \
        -maxuvw-m ${col4} -use-wgridder -theoretic-beam -no-dirty -abs-mem 120 ${obsnum}.ms

done < lightCurve${obsnum}-${norad}.csv

## make freq diff map
cp ${myPath}/generateFreqDiffMapping.py /nvmetmp
myPython3 ./generateFreqDiffMapping.py --ms ${obsnum}.ms

## extract light curve
cp ${myPath}/lightcurve.py /nvmetmp
myPython3 lightcurve.py --timeStepFile lightCurve${obsnum}-${norad}.csv \
        --obs ${obsnum} --noChannels 768  --noradid ${norad} \
        --tleCatalog ${tlecatalog}

### copy data over back to /astro
cp *.npy ${datadir}/${norad}
cp *.csv ${datadir}/${norad}
cp *.png ${datadir}/${norad}
cp *.plk ${datadir}/${norad}
cp *.txt ${datadir}/${norad}


end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
