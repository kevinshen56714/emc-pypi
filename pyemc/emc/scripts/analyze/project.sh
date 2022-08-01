#!/bin/bash
#
#  script:	project.sh
#  author:	Pieter J. in 't Veld
#  date:	February 7, 24, October 8, 2018.
#  purpose:	Conversion of LAMMPS average output into CSV format on project
#		basis, used for e.g. system-wide 
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20180207	Creation date
#    20180224	Refined execution through optional replacement
#    20181008	Added -target to allow for alternate output directory
#

# variables

version="1.2.1";
date="October 8, 2018";
author="Pieter J. in 't Veld";
script=$(basename "$0");


# defaults

archive="";
dir=".";
replace=1;
skip=0;
type="template";
window=1;


# functions

run() {
  echo "$@"; $@;
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
  target="";

  while [ "$1" != "" ]; do
    case "$1" in
      -help) 		help;;
      -archive)		shift; archive="$1";;
      -dir)		shift; dir="$1";;
      -replace)		shift; replace=$(flag "$1");;
      -skip)		shift; skip=$(calc "$1");;
      -target)		shift; target="$1";;
      -type)		shift; type=$1;;
      -window)		shift; window=$(calc "$1");;
      -*)		shift;;
      *)		if [ "${project}" == "" ]; then project="$1"; fi;;
    esac
    shift;
  done;
  if [ "${project}" == "" ]; then help; fi;
  if [ "${target}" != "" ]; then 
    if [ "${archive}" != "" ]; then archive="${target}/${archive}"; fi;
    target="${target}/${dir}/";
    if [ ! -e "${target}" ]; then 
      mkdir -p "${target}";
    fi;
  fi;
}


help() {
  echo "EMC $type tensor analysis script v${version}, ${date}
";
  echo "Usage:
  $script [-option [#]] project
";
  echo "Options:";
  echo "  -help		this message";
  echo "  -archive	set file to which to archive [${archive}]";
  echo "  -dir		set work directory [${dir}]";
  echo "  -replace	set replacement of exisiting results [$(boolean ${replace})]";
  echo "  -skip		set number to skip [${skip}]";
  echo "  -target	set alternate output directory [${target}]";
  echo "  -type		set evaluation type [${type}]";
  echo "  -window	set averaging window [${window}]";
  echo;
  exit;
}


submit() {
  local file name;

  echo;
  if [ ! -e $(first */${project}.${type}) ]; then
    echo "# */${project}.${type} does not exist -> skipping";
  else
    if [ -e "${target}${type}_${project}.csv" -a ${replace} = 0 ]; then
      echo "# ${type}_${project}.csv exists -> skipping";
    else
      run average.pl \
	-out="${target}${type}_${project}.csv" -skip=${skip} -window=${window} \
	*/${project}.${type};
    fi;
    if [ "${archive}" != "" ]; then
      echo ${dir}/${type}_${project}.csv >>"${archive}";
    fi;
  fi;
  echo;
}


# main

  init "$@";
  submit;

