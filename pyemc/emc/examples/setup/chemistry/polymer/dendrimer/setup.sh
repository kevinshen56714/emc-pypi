#!/bin/bash
#
#    script:	setup.sh
#    author:	Pieter J. in 't Veld
#    date:	May 19, 2015
#    purpose:	Generate EMC build and LAMMPS input scripts
#
#    notes:
#	- Create a simulation with a target number of 5000 particles
#	- Use OPLS-UA as force field
#	- Use mass fraction in number of molecule determination
#	- Add mass profile and mean square displacement calculations to LAMMPS
#	  input script
#      	- Replace exisiting scripts
#	- Write output to project name 'polymer'
#	- Generate a two-phase simulation with salt and water in the first
#	  phase
#	- Creates build.emc for EMC and polymer.in for LAMMPS
#
# usage with vmd after build: vmd -e charmm.vmd
#

  emc_setup.pl \
    -ntotal=5000 -density=3 -field=dpd/general \
    -replace polymer

