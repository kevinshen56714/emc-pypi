#!/bin/bash
#
#  script:	run_restart.sh
#  author:	Pieter J. in 't Veld
#  date:	April 11, 2018
#  purpose:	Restart crashed LAMMPS jobs
#

# settings

version=0.1;
date="April 11, 2018";
script=$(basename "$0");
queue=default;
walltime=24:00:00;

# functions
  
help() {
  echo "LAMMPS restart script v$version ($date)";
  echo;
  echo "Usage:";
  echo "  $script -n nprocs [-option value] project";
  echo;
  echo "Options:"
  echo -e "  -help\t\tthis message";
  echo -e "  -n\t\tset number of processors";
  echo -e "  -walltime\tset total wall time [$walltime]";
  echo;
  exit -1;
}


error() {
  echo "ERROR: $1";
  echo;
  exit -1;
}


init() {
  local error;

  n="";
  project="";
  while [ "$1" != "" ]; do
    case "$1" in 
      -n)		shift; n=$1;;
      -walltime)	shift; walltime=$1;;
      -queue)		shift; queue=$1;;
      -help)		help;;
      *)		if [ "${project}" == "" ]; then project="$1"; fi;;
    esac;
    shift;
  done;
  if [ "${n}" == "" ]; then error "n not set"; fi;
  if [ "${project}" == "" ]; then error "project not set"; fi;
}


candidates() {
  for file in $(find * -name ${project}.out); do
    if [ "$(grep ERROR "${file}")" == "" ]; then continue; fi;
    echo $(basename $file ${project}.out);
  done;
}


# main

  init $@;
  candidates;

