#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=6:00:00
#SBATCH --ntasks=20
#SBATCH --mem=124GB
#SBATCH --tmp=450GB
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
radius=SEARCHRADIUS
phaseCorrection=PHASECORRECTION

datadir=${base}/processing/${obsnum}

cd ${datadir}
mkdir ${norad}

## copy files to nvme disk
cp -r ${datadir}/${obsnum}.ms /nvmetmp

cd /nvmetmp

## run track.py
cp ${myPath}/track.py /nvmetmp
myPython ./track.py --obs ${obsnum} --metafits ${datadir}/${obsnum}.metafits --searchRadius ${radius} --noradid ${norad} --user ${spaceTrackUser} --passwd ${spaceTrackPassword} --debug True

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

    ## make near-field correction (if arg true)
    if [ ${phaseCorrection} = "false" ];
    then
      echo "skipping near-field phase correction"
    else
      cp /astro/mwasci/sprabu/satellites/git/LEOVision/LEOVision /nvmetmp
      PyLEO ./LEOVision --ms ${obsnum}.ms --tle ${norad}${obsnum}.txt --headTime ${col5} --debug True --t ${col1}
    fi
    
    mkdir Head
    wsclean -name ${obsnum}-2m-${col1}h -size 200 200 -scale 5amin -interval ${ah} ${bh} -channels-out 768 -weight natural -abs-mem 40 -temp-dir Head -quiet -maxuvw-m ${col4} -use-wgridder ${obsnum}.ms &

    PID1=$!

    mkdir Tail
    wsclean -name ${obsnum}-2m-${col1}t -size 200 200 -scale 5amin -interval ${at} ${bt} -channels-out 768 -weight natural -abs-mem 40 -temp-dir Tail -quiet -maxuvw-m ${col4} -use-wgridder ${obsnum}.ms & 

    PID2=$!



    wait ${PID1}    
    wait ${PID2}
    
    rm -r Head
    rm -r Tail
   
done < ${obsnum}-${norad}.csv

## get min max timestep values
max=${tarray[0]}
min=${tarray[0]}

for i in "${tarray[@]}"; do
  (( i > max )) && max=$i
  (( i < min )) && min=$i
done

## make cube
cp ${myPath}/makeCube.py /nvmetmp
myPython3 ./makeCube.py --obs ${obsnum} --noradid ${norad} --channels 768 --user ${spaceTrackUser} --passwd ${spaceTrackPassword}

### copy data over back to /astro
cp *.npy ${datadir}/${norad}
cp *.csv ${datadir}/${norad}
cp *.png ${datadir}/${norad}
cp *.txt ${datadir}/${norad}


end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
