#!/bin/bash

  cd src;
  files=$(ls *.itp);
  files=(martini.itp ions.itp solvents.itp phospholipids.itp sugars.itp);
  cd ..;
#  for file in ${files[@]}; do
#    emc_gromacs.pl -compress=1 -output=$(basename $file .itp) $file;
#  done;

  emc_gromacs.pl -compress=1 -output=martini ${files[@]}
