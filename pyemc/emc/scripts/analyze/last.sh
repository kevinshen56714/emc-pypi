#!/bin/bash
#
#  script:	analyze_last.sh
#  author:	Pieter J. in 't Veld
#  date:	February 7, 24, October 8, 2018.
#  purpose:	Conversion of LAMMPS last profiles into CSV
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
cut=0;
dir=".";
emc=0;
pdb=1;
replace=1;
type="last";
unwrap=1;
vdw=0;


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
  while [ "$1" != "" ]; do
    case "$1" in
      -help) 		help;;
      -archive)		shift; archive="$1";;
      -cut)		shift; cut=$(flag "$1");;
      -dir)		shift; dir="$1";;
      -emc)		shift; emc=$(flag "$1");;
      -pdb)		shift; pdb=$(flag "$1");;
      -replace)		shift; replace=$(flag "$1");;
      -target)		shift; target="$1";;
      -vdw)		shift; vdw=$(flag "$1");;
      -unwrap)		shift; unwrap=$(flag "$1");;
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
  echo "EMC last frame analysis script, v${version}, ${date}
";
  echo "Usage:
  $script [-option [#]] project
";
  echo "Options:";
  echo "  -help		this message";
  echo "  -archive	set file to which to archive [${archive}]";
  echo "  -cut		set bond cut flag [$(boolean ${cut})]";
  echo "  -dir		set work directory [${dir}]";
  echo "  -emc		set creation of EMC structure [$(boolean ${emc})]";
  echo "  -pdb		set creation of PDB structure [$(boolean ${pdb})]";
  echo "  -replace	set replacement of exisiting results [$(boolean ${replace})]";
  echo "  -target	set alternate output directory [${target}]";
  echo "  -unwrap	set cluster unwrap flag [$(boolean ${unwrap})]";
  echo "  -vdw		set van der waals radii flag [$(boolean ${vdw})]";
  echo;
  exit;
}


submit() {
  local file last nsites;
  local root="$(dirname $(which emc_${HOST}))/..";

  echo;
  if [ ! -e $(first */${project}.dump) ]; then
    echo "# */${project}.dump does not exist -> skipping";
  else
    last=$(first $(ls -r */${project}.dump));
    nsites=$(head -n 4 ${last} | tail -n 1);
    tail -n $(calc "${nsites}+9") ${last} >"${target}last.traject";
    if [ ${emc} = 1 ]; then
      if [ -e "${target}${project}.emc.gz" -a ${replace} = 0 ]; then
	echo "# ${project}.emc.gz exists -> skipping";
      else
	run emc_${HOST} \
	  ${root}/scripts/lammps2emc.emc \
	    -source='"build"' -traject="\"${target}last.traject\"" \
	    -compress=1 ${project} last;
      fi;
    fi;
    if [ ${pdb} = 1 ]; then 
      if [ -e "${target}${project}.pdb.gz" -a ${replace} = 0 ]; then
	echo "# ${project}.pdb.gz exists -> skipping";
      else
	run emc_${HOST} \
	  ${root}/scripts/lammps2pdb.emc \
	    -cut=1 -unwrap=0 -vdw=0 \
	    -source='"build"' -traject='"last.traject"' \
	    -compress=1 ${project} "${target}last";
      fi;
    fi;
    rm "${target}last.traject";
    if [ "${target}" != "" ]; then cd "${target}"; fi;
    for file in last.*; do
      echo ${dir}/${file} >>"${archive}";
    done;
  fi;
  echo;
}


# main

  init "$@";
  submit;

