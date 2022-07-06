#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH -p workq
#SBATCH --time=01:30:00
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
timestepOrg=TIMESTEP
ra=
dec=

while getopts 'r:d:' OPTION
do
    case "$OPTION" in
        r)
            ra=${OPTARG}
            ;;
        d)
            dec=${OPTARG}
            ;;
    esac
done

cd ${base}/processing/${obsnum}

## kinda have to add 1 due to reasons not yet known :(
timestep=$((timestepOrg+1))

i=$((timestep*1))
j=$((i+1))
channels=768 ## hard coded 
updatedCHANNELS=$(($channels-1)) ## cos indexes start from zero

## make tmp ms
cp -r ${obsnum}.ms ${obsnum}tmp${timestepOrg}.ms

## change phase centre
chgcentre ${obsnum}tmp${timestepOrg}.ms ${ra} ${dec}

## image
### spawn n number of jobs parallely
for f in `seq 0 ${updatedCHANNELS}`;
do
    f1=$((f*1))
    f2=$((f1+1))
    while [[ $(jobs | wc -l) -ge 20 ]]
    do
        wait -n $(jobs -p)
    done

    ## unique temporary dump folder for every channel and time-step
    mkdir temp_${g}_${f} 
    name=`printf %04d $f`

    wsclean -quiet -name ${obsnum}-2m-${i}-${name} -size 1400 1400\
                -temp-dir temp_${g}_${f} -abs-mem 5 -interval ${i} ${j}\
                -channel-range ${f1} ${f2} -weight natural -scale 5amin\
                -use-wgridder -no-dirty -theoretic-beam ${obsnum}tmp${timestepOrg}.ms &

done

### wait for all pids before continuing
b=0
for job in `jobs -p`
do
    if [ ${job} -eq ${monitorPID} ]; then
        continue
    fi
    pids[${b}]=${job}
    b=$((b+1))
done
for pid in ${pids[*]}; do
    wait ${pid}
done

rm -r temp_*

i=$((timestep-1))
j=$((i+1))

for f in `seq 0 ${updatedCHANNELS}`;
do
    f1=$((f*1))
    f2=$((f1+1))
    while [[ $(jobs | wc -l) -ge 20 ]]
    do
        wait -n $(jobs -p)
    done

    ## unique temporary dump folder for every channel and time-step
    mkdir temp_${g}_${f} 
    name=`printf %04d $f`

    wsclean -quiet -name ${obsnum}-2m-${i}-${name} -size 1400 1400\
                -temp-dir temp_${g}_${f} -abs-mem 5 -interval ${i} ${j}\
                -channel-range ${f1} ${f2} -weight natural -scale 5amin\
                -use-wgridder -no-dirty -theoretic-beam ${obsnum}tmp${timestepOrg}.ms &

done

### wait for all pids before continuing
b=0
for job in `jobs -p`
do
    if [ ${job} -eq ${monitorPID} ]; then
        continue
    fi
    pids[${b}]=${job}
    b=$((b+1))
done
for pid in ${pids[*]}; do
    wait ${pid}
done


# wsclean -quiet -name ${obsnum}-2m-${i} -size 1400 1400\
#         -abs-mem 120 -interval ${i} ${j} -channels-out ${channels}\
#         -weight natural -scale 5amin -use-wgridder -no-dirty ${obsnum}.ms

# i=$((timestep-1))
# j=$((i+1))
# wsclean -quiet -name ${obsnum}-2m-${i} -size 1400 1400\
#             -abs-mem 120 -interval ${i} ${j} -channels-out ${channels}\
#             -weight natural -scale 5amin -use-wgridder -no-dirty ${obsnum}.ms

rm -r temp_*
cp /home/sprabu/RFISeeker/RFISeeker .

python_rfi ./RFISeeker --obs ${obsnum} --freqChannels ${channels} --seedSigma 6\
        --floodfillSigma 1 --timeStep $((timestep-1)) --prefix meteor\
        --imgSize 1400 --streak head --ext image

## make cont image with new phase centre to eliminate varing farfield sources
wsclean -name img-${timestepOrg} -size 1400 1400 -scale 5amin -weight natural -niter 10000 -mgain 0.8 -auto-threshold 1.2 ${obsnum}tmp${timestepOrg}.ms

## delete tmp ms
rm -r ${obsnum}tmp${timestepOrg}.ms

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}