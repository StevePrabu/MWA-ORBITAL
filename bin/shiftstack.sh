#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --nodes=1
#SBATCH --time=24:00:00
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
radius=SEARCHRADIUS
phaseCorrection=PHASECORRECTION
inttime=INTTIME

outChannels=768


datadir=${base}/processing/${obsnum}

cd ${datadir}
rm -r ${norad}
mkdir ${norad}

## check if ms has read lock
cp ${myPath}/checkReadLock.py /nvmetmp
myPython3 ./nvmetmp/checkReadLock.py --file ${datadir}/${obsnum}.ms

## copy files to nvme disk
cp -r ${datadir}/${obsnum}.ms /nvmetmp

cd /nvmetmp

## run track.py
cp ${myPath}/track.py /nvmetmp
cp /astro/mwasci/sprabu/satellites/MWA-ORBITAL/tles/${norad}${obsnum}.txt /nvmetmp
myPython3 ./track.py --obs ${obsnum} --metafits ${datadir}/${obsnum}.metafits --searchRadius ${radius} --noradid ${norad} \
  --user ${spaceTrackUser} --passwd ${spaceTrackPassword} --debug True \
  --integration ${inttime}

## split ms to just the required timesteps. Having a smaller ms drastically reduces the runtime of the job
cp ${myPath}/splitMS.py /nvmetmp
myCASA --nologfile --nogui --agg --norc -c splitMS.py --config ${obsnum}-${norad}.csv \
      --inputMS ${obsnum}.ms --outputMS ${obsnum}split.ms

## replace the large ms with the smller split ms
rm -r ${obsnum}.ms
mv ${obsnum}split.ms ${obsnum}.ms

## delete old config, and make new config for new ms
rm ${obsnum}-${norad}.csv
myPython3 ./track.py --obs ${obsnum} --metafits ${datadir}/${obsnum}.metafits --searchRadius ${radius} --noradid ${norad} \
  --user ${spaceTrackUser} --passwd ${spaceTrackPassword} --debug True \
  --integration ${inttime}

### phase track the predicted trajectory, and make images
tarray=
while IFS=, read -r col1 col2 col3 col4 col5 col6
do
    ah=$((col1))
    bh=$((ah+1))
    bt=$((col1))
    at=$((bt-1))
    tarray=(${tarray[@]} ${col1})
   
    start_chg=`date +%s`
    chgcentre ${obsnum}.ms ${col2} ${col3}
    end_chg=`date +%s`
    runtime=$((end_chg-start_chg))
    echo "the chgcentre run time ${runtime}"
    
    ## make near-field phase correction (if arg true)
    if [ ${phaseCorrection} = "false" ];
    then
      echo "skipping near-field phase correction"
      maxuvw="-maxuvw-m ${col4}"
    else
      cp /astro/mwasci/sprabu/satellites/git/LEOVision/LEOVision /nvmetmp
      start_leo=`date +%s`
      PyLEO ./LEOVision --ms ${obsnum}.ms --tle ${norad}${obsnum}.txt --headTime ${col5} --debug True --t ${col1}
      maxuvw=""
      end_leo=`date +%s`
      runtime=$((end_leo-start_leo))
      echo "the LEOVision run time ${runtime}"
    
    fi
    
    mkdir Head
    start_wsclean=`date +%s`
    wsclean -name ${obsnum}-2m-${col1}h -size 200 200 -scale 2amin -interval ${ah} ${bh} -channels-out ${outChannels} -weight natural -abs-mem 40 -temp-dir Head -quiet ${maxuvw} -use-wgridder ${obsnum}.ms &
    PID1=$!

    mkdir Tail
    wsclean -name ${obsnum}-2m-${col1}t -size 200 200 -scale 2amin -interval ${at} ${bt} -channels-out ${outChannels} -weight natural -abs-mem 40 -temp-dir Tail -quiet ${maxuvw} -use-wgridder ${obsnum}.ms & 
    PID2=$!

    wait ${PID1}    
    wait ${PID2}

    rm *image.fits

    end_wsclean=`date +%s`
    runtime=$((end_wsclean-start_wsclean))
    echo "the WSClean run time ${runtime}"
    

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

## make stacked image cube
cp ${myPath}/makeCube.py /nvmetmp
myPython3 ./makeCube.py --obs ${obsnum} --noradid ${norad} --channels ${outChannels} --user ${spaceTrackUser} --passwd ${spaceTrackPassword}

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
