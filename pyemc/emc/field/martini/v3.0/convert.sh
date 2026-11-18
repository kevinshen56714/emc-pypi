#!/bin/bash
#
#  script:	convert.sh
#  author:	Pieter J. in 't Veld
#  date:	November 15, 2025
#  purpose:	Testing and conversion of MARTINI v3.0 force field files
#

# functions

small_molecules() {
  #trials=DMBZQ;
  #trials=ACPH,2NITL;
  #trials=2NIMX,DMBZQ,MESI,MXYLE,OXYLE;
  trials=ANIL,BRA,BZIM,BZTA,FURA,INDA,PBEN,PCYM,PYRI,PYRR;
  trials=BZIM,BZTA;

  files=(small_molecules_v2);
}

solvents() {
  files=(solvents);
}

sugars() {
  files=(sugars_v2);
}

all() {
  files=(martini ions solvents phospholipids sugars_v2 small_molecules_v2);
}

# main

{
  small_molecules;
  #solvents
  #sugars;
  #all;
  
#  for file in ${files[@]}; do
#    emc_gromacs.pl -compress=1 -output=$(basename $file .itp) $file;
#  done;

  if [ "${trials}" == "" ]; then
    emc_gromacs.pl \
      -compress=1 -message_trace=1 -output=martini \
      $@ ${files[@]}
  else
    emc_gromacs.pl \
      -compress=1 -message_trace=1 -output=trials -trials=$trials \
      $@ ${files[@]}
  fi;
}

