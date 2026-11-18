#!/bin/bash

  host=$(echo $$HOSTNAME | sed -e 's/\..*$$//');

  emc.pl \
    -field=charmm -density=1,0.8,0.8 -ntotal=5000 \
    -mass -profile -lammps -emc  \
    surfactant water + sds + oil
  
  emc_${host} build.emc 2>&1 | tee build.out

