##!/bin/bash
# ------------------------------------------------------------------
# Author: andreasalazar@g.harvard.edu
# Title: test_create_new_build.sh
# Description: creates a CESM2 case, configures it, and builds it
# ------------------------------------------------------------------
USAGE="Usage: $0 CASE"
OPTIONS="res [default:f09_f09_mg17], compset [default:F2000climo] in that order"
NOTES=""
# --- Options processing -------------------------------------------
if [ $# == 0 ] ; then
    echo $USAGE
    echo $OPTIONS
    echo $NOTES
    exit 1;
fi
CASE=$1
# Accept arguments with defaults:
# RES=${2:-"f09_g17"} # https://csegweb.cgd.ucar.edu/exp2-public/cgi-bin/expListPublic.cgi
# COMPSET=${3:-"BCO2x4cmip6"} # https://csegweb.cgd.ucar.edu/exp2-public/cgi-bin/expListPublic.cgi
# RESTART_FILE=${4:-"b.e21.BCO2x4cmip6.f09_g17.CMIP6-abrupt4xCO2.001"}
# echo RES:$RES
# echo COMPSET:$COMPSET

RES=${2:-"f19_g17"} #
COMPSET=${3:-"1850_CAM60_CLM50%BGC-CROP_CICE_POP2_MOSART_CISM2%NOEVOLVE_WW3"} 
RESTART_FILE=${4:-"b.e21.B1850.f19_g17.8xCO2_PaleoCalibr.002"}
echo RES:$RES
echo COMPSET:$COMPSET

export COMPILER="intel"

# Set directories
# illustration of directories: http://www.cesm.ucar.edu/events/tutorials/2016/practical1-bertini.pdf p.48
SCRIPTDIR=$PWD
CESMROOT=/glade/work/asalazar/derecho_cesm2
cd $CESMROOT/cime/scripts/
CASEROOT="${HOME}/cesm2/cesm_caseroot/${CASE}"
#SOURCEMODS="${HOME}/cesm2/cloud_locking_raw"
OUTPUT="/glade/derecho/scratch/asalazar/${CASE}" # best to use scratch
RUNDIR="${OUTPUT}/run"
RESTDIR="/glade/derecho/scratch/asalazar/b.e21.B1850.f19_g17.8xCO2_PaleoCalibr.002/rest/1101-01-01-00000"
SOURCEMODDIR="~/cesm2/derecho_cloud_locking_strato/SourceMods"
echo $CASEROOT

# Account (e.g. uhar0009)
export PROJECT=$PBS_ACCOUNT

# Create case
./create_newcase --case ${CASEROOT} --res ${RES} --compset ${COMPSET} --project ${PROJECT} --compiler intel --run-unsupported|| exit -1

cd $CASEROOT
./case.setup --clean

# Move custom modifications (user_nl_*, source mods) to CASEROOT
cp -a $SCRIPTDIR/$0 $CASEROOT # make a copy in the caseroot
cp -a $SCRIPTDIR/user_nl_* $CASEROOT
#cp -a $SCRIPTDIR/user_nl_clm $CASEROOT
# cp -a $SCRIPTDIR/user_nl_cpl $CASEROOT
#./preview_namelist # to check consistency of user_nl_* files
# Copy source modifications


# Modify tasks/cores: env_mach_pes.xml

# cam
./xmlchange NTASKS_ATM=-8
./xmlchange NTHRDS_ATM=1
./xmlchange ROOTPE_ATM=0
# cpl
./xmlchange NTASKS_CPL=-8
./xmlchange NTHRDS_CPL=1
./xmlchange ROOTPE_CPL=0
#cism
./xmlchange NTASKS_GLC=64
./xmlchange NTHRDS_GLC=1
./xmlchange ROOTPE_GLC=0
# cice
./xmlchange NTASKS_ICE=192
./xmlchange NTHRDS_ICE=1
./xmlchange ROOTPE_ICE=64
# clm
./xmlchange NTASKS_LND=768
./xmlchange NTHRDS_LND=1
./xmlchange ROOTPE_LND=256
# pop
./xmlchange NTASKS_OCN=256
./xmlchange NTHRDS_OCN=1
./xmlchange ROOTPE_OCN=-8
# mosart
./xmlchange NTASKS_ROF=64
./xmlchange NTHRDS_ROF=1
./xmlchange ROOTPE_ROF=0

# wav
./xmlchange NTASKS_WAV=64
./xmlchange NTHRDS_WAV=1
./xmlchange ROOTPE_WAV=0

./xmlchange JOB_WALLCLOCK=12:00:00
# Set up case run scripts
./case.setup
# ln -sT $OUTPUT scratch # not sure what this does...link?
# ./preview_run # more info on how case will be run
cp -a $SCRIPTDIR/SourceMods/src.cam/* $CASEROOT/SourceMods/src.cam
cp -a $SCRIPTDIR/SourceMods/src.cice/* $CASEROOT/SourceMods/src.cice
# Modify build: env_build.xml
./xmlchange EXEROOT=$OUTPUT/bld
#./xmlchange DEBUG=TRUE

# Set number of CAM levels
#   this is not recommended
#     these are set as compset variables and should not gen be modified for supported/verified compsets
#   also need to provide new initial  condition files at the new vertical resolution
#./xmlchange -file env_build.xml -id CAM_CONFIG_OPTS -val "-nlev 56"

# Build executables
#qcmd -- ./case.build --clean
qcmd -- ./case.build 
echo 

# Modify run: env_run.xml

# storage:
./xmlchange --id RUN_TYPE --val hybrid
./xmlchange --id RUN_REFDIR --val $RESTDIR
./xmlchange --id RUN_REFCASE --val $RESTART_FILE
./xmlchange --id RUN_REFDATE --val 1101-01-01
./xmlchange --id RUN_STARTDATE --val 0001-01-01

./xmlchange RUNDIR=$RUNDIR
./xmlchange DOUT_S=TRUE # Reorganizes the files into nice folders
./xmlchange DOUT_S_ROOT=$OUTPUT

# ./xmlchange --id POSTRUN_SCRIPT_BATCH --val "TRUE" # Cloud locking
#./xmlchange --id POSTRUN_SCRIPT --val "adjustCloudData" # Cloud locking
# duration of run:
./xmlchange STOP_OPTION=nyears
./xmlchange STOP_N=10
./xmlchange GET_REFCASE=TRUE # otherwise it will check input data from svn
./xmlchange RESUBMIT=20 # total times submitted = RESUBMIT+1

# continuation or new run?
./xmlchange CONTINUE_RUN=FALSE

# debug?
# ./xmlchange INFO_DBUG=3

# Set CO2 concentration
#   alternative ways to change CO2:
#     set co2vmr variable or forcings in user_nl_cam
#     pick a different compset
#./xmlchange -file env_run.xml -id CCSM_CO2_PPMV -val 560

# Change internal timestep
# if ATM_NCPL is set and run fails with 'ERROR: Bad namelist settings for FV subcycling':
#   then also modify NSPLIT, NSPLTRAC, NSPLTVRM in user_nl_cam
#./xmlchange -file env_run.xml -id ATM_NCPL -val 96 # coupling times per day; ATM_NCPL/24 = number of timesteps per hour

# List any changes made to namelist files or source code
grep -Ev '^\s*$|^\s*!' user_nl_*
\ls -l SourceMods/*/*

# if resubmit, add a couple lines to the PBS script on top
# sed -i '/RESUBMIT > 0/i cd $CASEROOT' case.run

# Instructions to submit the job upon build
printf "To submit job, issue:\n"
printf "cd ${CASEROOT}\n"
printf "./case.submit\n"

# printf "To extend the run after completion, issue:\n"
# printf "./xmlchange CONTINUE_RUN=TRUE\n"
# printf "similarly, may want to modify STOP_N, RESUBMIT"
# printf "then re-submit with ./case.submit as before"

