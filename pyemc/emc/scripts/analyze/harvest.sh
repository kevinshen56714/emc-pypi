#!/bin/bash
#
#  script:	harvest.sh
#  author:	Pieter J. in 't Veld
#  date:	February 7, 24, October 8, 2018, January 9, 2022.
#  purpose:	Harvesting of EMC interaction profiles; to be used on copy
#		level
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20180207	Creation date
#    20180224	Refined execution through optional replacement
#    20181008	Added -target to allow for alternate output directory
#    20220109	Creation of harvesting script
#

# variables

version="1.0";
date="January 9, 2022";
author="Pieter J. in 't Veld";
script=$(basename "$0");


# defaults

archive="";
dir=".";
nfilter=10;
replace=1;
skip=0;
type="m";
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

  commands=();
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
      -*)		command="$1"; shift; commands+=($command="$1");;
      *)		if [ "${project}" == "" ]; then project="$1"; fi;;
    esac
    shift;
  done;
  type="m";
  if [ "${project}" == "" ]; then help; fi;
  if [ "${target}" != "" ]; then 
    if [ "${archive}" != "" ]; then archive="${target}/${archive}"; fi;
    target="${target}/${dir}/";
    if [ ! -e "${target}" ]; then 
      mkdir -p "${target}";
    fi;
  fi;
  commands+=($project.${type});
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
  echo "  -nfilter	set band pass filter width [${nfilter}]";
  echo "  -replace	set replacement of exisiting results [$(boolean ${replace})]";
  #echo "  -skip		set number to skip [${skip}]";
  echo "  -target	set alternate output directory [${target}]";
  #echo "  -type		set evaluation type [${type}]";
  #echo "  -window	set averaging window [${window}]";
  echo;
  exit;
}


submit() {
  local file;
  local name;
  local error=0;

  echo;
  if [ ! -e $(first */*/${project}.${type}) ]; then
    if [ ! -e $(first */*/${project}.${type}.gz) ]; then
      echo "# */*/${project}.${type} does not exist -> skipping";
      error=1;
    fi;
  fi;
  if [ "${error}" == "0" ]; then
    if [ -e "${target}${project}.prm.gz" -a ${replace} = 0 ]; then
      echo "#  ${project}.prm exists -> skipping";
    else
      run emc_combine.pl -harvest \
	-output="${target}${project}.prm.gz" ${commands[@]}
    fi;
    if [ "${archive}" != "" ]; then
      echo ${dir}/${project}.prm.gz >>"${archive}";
    fi;
  fi;
  echo;
}


# main

  init "$@";
  submit;

