#!/bin/bash
#
#  script:	emc_error.sh
#  author:	Pieter J. in 't Veld
#  date:	July 10, 2019
#  purpose:	Clean directory by removing all project.esh related files
#
#  notes:
#    20190710	Creation date
#

clean() {
  local file;
  local script;
  local project;

  for script in "$@"; do
    if [ ! -e "${script}" ]; then continue; fi;
    project=$(basename ${script} .esh);
    for trial in ${project}.*; do
      if [ "${trial}" == "${project}.esh" ]; then continue; fi;
      rm ${trial};
    done;
  done;
  rm -f build.*;
}

# main

  if [ "$1" == "" ]; then
    clean *.esh;
  else
    clean "$@";
  fi;

