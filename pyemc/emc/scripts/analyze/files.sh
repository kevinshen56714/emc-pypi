#!/bin/bash
#
#  script:	files.sh
#  author:	Pieter J. in 't Veld
#  date:	February 7, 24, July 7, October 8, December 15, 2018.
#  purpose:	Conversion of LAMMPS profiles into CSV format on individual
#		file basis (per cluster or type), used for e.g. density and
#		pressure profiles
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20180207	Creation date
#    20180224	Refined execution through optional replacement
#    20180707	Adapted directory choice of files
#    20181008	Added -target to allow for alternate output directory
#    20181215	Added -null to control null vector inclusion
#

# variables

version="1.2.2";
date="December 15, 2018";
author="Pieter J. in 't Veld";
script=$(basename "$0");


# defaults

archive="";
dir=".";
null=1;
replace=1;
skip=0;
type="template";
window=1;


# functions

run() {
  echo "$@"; "$@";
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
      -null)		shift; null=$(flag "$1");;
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
  echo "EMC $type profile analysis script v${version}, ${date}
";
  echo "Usage:
  $script [-option [#]] project
";
  echo "Options:";
  echo "  -help		this message";
  echo "  -archive	set file to which to archive [${archive}]";
  echo "  -dir		set work directory [${dir}]";
  echo "  -null		include null vector in average [$(boolean ${null})]";
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
  file=$(first */*.${type});
  if [ ! -e ${file} ]; then
    echo "# */*.${type} does not exist -> skipping";
  else
    for file in $(dirname ${file})/*.${type}; do
      name=$(basename ${file} .${type});
      if [ -e "${target}${type}_${name}.csv" -a ${replace} == 0 ]; then
	echo "# ${type}_${name}.csv exists -> skipping";
      else
	run average.pl \
	  -null=${null} -skip=${skip} -window=${window} \
	  -out="${target}${type}_${name}.csv" \
	  */${name}.${type};
	if [ "${archive}" != "" ]; then
	  echo ${dir}/${type}_${name}.csv >>${archive};
	fi;
      fi;
    done;
  fi;
  echo;
}


# main

  init "$@";
  submit;

