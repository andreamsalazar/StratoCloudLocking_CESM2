# This file is for user convenience only and is not used by the model
# Changes to this file will be ignored and overwritten
# Changes to the environment should be made in env_mach_specific.xml
# Run ./case.setup --reset to regenerate this file
source $LMOD_ROOT/lmod/init/sh
module load cesmdev/1.0 ncarenv/23.06
module purge 
module load craype intel/2023.0.0 mkl ncarcompilers/1.0.0 cmake cray-mpich/8.1.25 netcdf-mpi/4.9.2 parallel-netcdf/1.12.3
export OMP_STACKSIZE=64M
export FI_CXI_RX_MATCH_MODE=hybrid
export MPICH_MPIIO_HINTS=*:romio_cb_read=enable:romio_cb_write=enable:striping_factor=2