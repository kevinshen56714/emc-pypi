#!/bin/bash

# determine architecture

  if [ "${HOST}" == "" ]; then
    if [ "$(uname)" == "Darwin" ]; then HOST=macos;
    elif [ "$(uname)" == "Linux" ]; then HOST=linux; fi;
  fi;

  if [ "${HOST}" == "" ]; then
    echo "cannot determine architecture -> exiting";
    echo; exit;
  fi;

# create build script

  emc.pl \
    -ntotal=1000 -field=trappe -replace \
    -temperature=300 -density=0.7 \
    example;
  
# build input structure

  emc_${HOST} build.emc 2>&1 | tee build.out

# sample 

  emc_${HOST} sample.emc 2>&1 | tee sample.out

