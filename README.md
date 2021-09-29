# MWA-ORBITAL
The MWA lOw eaRth orBIT spAce surveiLlance (ORBITAL) pipeline

The git repo is intended to contain the final working version of the MWA non-coherent SSA pipeline.


It is an improved, commented, "well maintained", final? version of the MWA-SDA pipeline and is derived from my old MWA SDA pipelines made for the blind survey study, space fest 2020, orbit determination study and the shift-stack search. (If you want to look at the previous versions of this pipeline, check out https://github.com/StevePrabu/Space-Fest, https://github.com/StevePrabu/MWA-calibration, https://github.com/StevePrabu/DUG-MWA-SSA-Pipeline, https://github.com/StevePrabu/MWASSA-Pipeline)

## Obs_source_find.sh

job creates fine channel images for every time-step and searches for transient events using RFISeeker. 


## Obs_blind_detection.sh

job cross matches the events found by RFISeeeker (in previous step) with satellite tracks within the FOV


## Obs_orbitDetermination.sh

job extracts angular pass measuremetns of the satellite and performs orbit determination.


## Obs_shiftstack.sh

Job does a shif-stacking search for the object of interest
