#!/bin/bash

  if [ "${HOST}" == "" ]; then 
    if [ $(uname) == Darwin ]; then EMC="emc_macos";
    elif [ $(uname) == Linux ]; then EMC="emc_linux";
    else EMC="emc_win32.exe"; fi;
  else
    EMC="emc_${HOST}";
  fi;

  if [ "${EMC_ROOT}" != "" ]; then
    "${EMC_ROOT}/scripts/emc_setup.pl" fullerene.esh;
    if [ -e build.emc ]; then
      rm -f record_*;
      "${EMC_ROOT}/bin/${EMC}" build 2>&1 | tee build.out;
    fi;
  else
    ./fullerene.esh;
    if [ -e build.emc ]; then
      rm -f record_*;
      ${EMC} build 2>&1 | tee build.out;
    fi;
  fi;

  if [ -e "$(ls record_*.pdb | head -1)" ]; then
    ./cat.sh record;
  fi;

  echo; echo "view with 'vmd -e record.vmd'"; echo;

