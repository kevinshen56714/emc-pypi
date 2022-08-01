#!/bin/bash
#
#  script:	script.sh
#  author:	Pieter J. in 't Veld
#  date:	February 8, 24, 2018.
#  purpose:	script size sampling of LAMMPS trajectories 
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20180930	Creation date
#

# variables

version="1.0";
type="script";
date="September 30, 2018";
author="Pieter J. in 't Veld";
script=$(basename "$0");
root=$(dirname "$0");

# functions

run() {
  echo "$@"; 
  $@;
}


first() {
  echo "$1";
}


calc() {
  perl -e 'print(eval($ARGV[0]));' $@;
}


flag() {
  if [ "$1" == "true" ]; then echo 1;
  elif [ "$1" == "false" ]; then echo 0;
  elif [ "$1" == "1" ]; then echo 1;
  else echo 0;
  fi;
}


boolean() {
  if [ "$1" == "1" ]; then echo true;
  else echo false;
  fi;
}


init() {
  archive="";
  dir=".";
  skip=0;
  end=-1;
  zero=1;
  start=0;
  replace=1;
  target="";
  cutoff=10.0;
  binsize=1;
  frequency=1;
  queue="default";
  walltime="24:00:00";

  while [ "$1" != "" ]; do
    case "$1" in
      -help) 		help;;
      -archive)		shift; archive="$1";;
      -binsize)		shift; binsize=$(calc "$1");;
      -cutoff)		shift; cutoff=$(calc "$1");;
      -dir)		shift; dir="$1";;
      -end)		shift; end=$(calc "$1");;
      -frequency)	shift; frequency=$(calc "$1");;
      -replace)		shift; replace=$(flag "$1");;
      -queue)		shift; queue="$1";;	
      -start)		shift; start=$(calc "$1");;
      -skip)		shift; start=$(calc "$1");;
      -target)		shift; target="$1";;
      -type)		shift; type="$1";;
      -walltime)	shift; walltime="$1";;
      -*)		shift;;
      *)		if [ "${project}" == "" ]; then project="$1"; fi;;
    esac
    shift;
  done;
  if [ "${project}" == "" ]; then help; fi;
  if [ "${type}" == "" ]; then error "type not set"; fi;
  if [ "${target}" != "" ]; then 
    if [ "${archive}" != "" ]; then archive="${target}/${archive}"; fi;
    target="${target}/${dir}/";
    if [ ! -e "${target}" ]; then 
      mkdir -p "${target}";
    fi;
  fi;
}


header() {
  local space=" ";

  if [ "${type}" == "" ]; then space=""; fi;
  echo "EMC ${type}${space}analysis script v${version}, ${date}";
  echo;
}


help() {
  header;
  echo "Usage:
  $script [-option [#]] project
";
  echo "Options:";
  echo "  -help		this message";
  echo "  -archive	set file to which to archive [${archive}]";
  echo "  -binsize	set binsize [${binsize}]";
  echo "  -cutoff	set calculation cut off [${cutoff}]";
  echo "  -dir		set work directory [${dir}]";
  echo "  -end		set end frame; -1 is end of file [${end}]";
  echo "  -frequency	set sampling frequency [${frequency}]";
  echo "  -replace	set replacement of exisiting results [$(boolean ${replace})]";
  echo "  -skip		set time step to start at [${start}]";
  echo "  -start	set time step to start at [${start}]";
  echo "  -target	set alternate output directory [${target}]";
  echo "  -type		set evaluation type [${type}]";
  echo "  -walltime	set submission walltime [${walltime}]";
  echo;
  exit -1;
}


error() {
  header;
  echo "Error: $1";
  echo;
  exit -1;
}


run_sh() {
  local output;

  echo "run.sh $@";
  while IFS= read -r; do output+=("$REPLY"); done < <(run.sh "$@");
  printf "%s\n" "${output[@]}";
  jobid=$(perl -e '
    $a = (split(" ", @ARGV[0]))[-1];
    $a =~ s/[<|>]//g; 
    print($a);' "${output[3]}");
  if [ "${jobid}" == "" ]; then jobid="-1"; fi;
}


submit() {
  echo;
  if [ ! -e $(first */${project}.dump) ]; then
    echo "# */${project}.dump does not exist -> skipping";
  else
    if [ -e "${type}_${project}.m" -a ${replace} == 0 ]; then
      echo "# ${type}_${project}.m exists -> skipping";
    else
      run_sh \
	-n 1 -queue ${queue} -walltime ${walltime} \
	-output "${target}${type}_${project}.out" \
	emc.sh \
	  -start=${start} -end=${end} -cutoff=${cutoff} -binsize=${binsize} \
	  -frequency=${frequency} -traject="*/${project}.dump" \
	  -input="build/${project}.emc.gz" -work="${target}" \
	  -output="${target}${type}_${project}" \
	  "${root}/sample/${type}.emc";
    fi;
    if [ "${archive}" != "" ]; then
      echo ${dir}/${type}_${project}.csv >>"${archive}";
      echo ${dir}/${type}_${project}.m >>"${archive}";
    fi;
  fi;
  echo;
}


# main

  init "$@";
  submit;

