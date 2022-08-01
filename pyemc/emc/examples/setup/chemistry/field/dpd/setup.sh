#!/bin/bash
#
#    script:	setup.sh
#    author:	Pieter J. in 't Veld
#    date:	March 18, 2015
#    purpose:	Generate EMC build and LAMMPS input scripts
#
#    notes:
#	- Create a simulation with a target number of 1000 particles
#	- Use DPD as force field
#	- Use mass fraction in number of molecule determination
#      	- Replace exisiting scripts
#	- Add mass profiles to LAMMPS script
#	- Set build directory to current in LAMMPS script
#	- Use type WAT8 as reference
#	- Write output to project name 'dpd'
#	- First phase contains nylon, second (interphase) branch, and
#	  third water
#	- Creates build.emc for EMC and dpd.in for LAMMPS
#
# usage with vmd after build: vmd -e dpd.vmd
#

  emc_setup.pl \
    -field=dpd -mass -replace  \
    -profile -build_dir=. -rtype=WAT8 dpd nylon + branch + water

