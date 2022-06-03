#!/bin/bash
#
#    script:	setup.sh
#    author:	Pieter J. in 't Veld
#    date:	March 18, 2015
#    purpose:	Generate EMC build and LAMMPS input scripts
#
#    notes:
#	- Create a simulation with a target number of 1000 particles
#	- Use OPLS-UA as force field
#	- Use mol fraction in number of molecule determination
#      	- Replace exisiting scripts
#	- Write output to project name 'solution'
#	- Creates build.emc for EMC and solution.in for LAMMPS
#
# usage with vmd after build: vmd -e solution.vmd
#

  emc_setup.pl \
    -ntotal=1000 -field=opls-ua \
    -replace solution $@;

  #emc_${HOST} build.emc 2>&1 | tee build.out

