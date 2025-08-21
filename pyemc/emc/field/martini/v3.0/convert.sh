#!/bin/bash

  cd src;
  files=$(ls *.itp);
  files=(martini.itp ions.itp solvents.itp phospholipids.itp sugars_v2.itp small_molecules_v2);
  #files=(solvents.itp);
  cd ..;
#  for file in ${files[@]}; do
#    emc_gromacs.pl -compress=1 -output=$(basename $file .itp) $file;
#  done;
 
  emc_gromacs.pl -compress=1 -output=martini -message_trace=1 ${files[@]}
