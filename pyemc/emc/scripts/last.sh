#!/bin/bash
#
#  File:	last.sh
#  Author:	Pieter J. in 't Veld
#  Date:	September 12, 2017, July 6, 2018, May 8, July 20, 2019
#  Purpose:	Create VMD input for last frame; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  Notes:
#    20170912	Creation date
#    20180706	Consiliation of formats
#    20190508	Added find functionality
#    20190720	Added workdir and rank functionality
#

# settings

version="2.2";
date="July 20, 2019";

compress=1;
cut=0;
vdw=0;
pbc=1;
rank=0;
find=0;
format=pdb;
unwrap=1;
ext=.dump;
workdir=.;

# functions

first() {
  echo "$1";
}


run() {
  echo "$@"; $@;
}


calc() {
  perl -e 'print(eval($ARGV[0]));' $@;
} 


flag() {
  if [ "$1" = "" ]; then echo 1;
  elif [ "$1" = "on" ]; then echo 1;
  elif [ "$1" = "true" ]; then echo 1;
  elif [ "$1" = "1" ]; then echo 1;
  else echo 0; fi;
}


boolean() {
  local f=$(flag $1);
  if [ $f -eq 1 ]; then echo true;
  else echo false; fi;
}


init() {
  files="";
  ffind=false;
  while [ "$1" != "" ]; do
    case "$1" in
      -h)		help;;
      -help)		help;;
      -compress)	shift; compress=$(flag $1);;
      -cut)		shift; cut=$(flag $1);;
      -ext)		shift; ext=$1;;
      -f)		find=1;;
      -find)		shift; find=$(flag $1);;
      -format)		shift; format=$1;;
      -pbc)		shift; pbc=$(flag $1);;
      -rank)		shift; rank=$(flag $1);;
      -unwrap)		shift; unwrap=$(flag $1);;
      -vdw)		shift; vdw=$(flag $1);;
      -wd)		shift; workdir="$1";;
      -workdir)		shift; workdir="$1";;
      -*)		help;;
      *)		directories+=($1);;
    esac
    shift;
  done;
  error="unsupported format '${format}'";
  if [ "${format}" == "emc" ]; then error="";
  elif [ "${format}" == "lammps" ]; then error="";
  elif [ "${format}" == "pdb" ]; then error=""; fi;
  if [ "${error}" != "" ]; then echo ${error}; echo; exit; fi;
  if [ "${find}" != "1" ]; then directories=(.); fi;
}


help() {
  echo "Converter for last LAMMPS snapshot v${version} (${date})";
  echo;
  echo "Usage:";
  echo "  $(basename $0) [-option #] [dir [...]]";
  echo;
  echo "Options:";
  echo -e "  -h[elp]\tthis message";
  echo -e "  -compress\tset compression [$(boolean ${compress})]";
  echo -e "  -cut\t\tcut bonds that wrap box [$(boolean ${cut})]";
  echo -e "  -ext\t\tset trajectory file extension [${ext}]";
  echo -e "  -find\t\ttraverse directory to find files [$(boolean ${find})]";
  echo -e "  -format\tset export format [${format}]";
  echo -e "  -pbc\t\tenforce periodic boundary conditions [$(boolean ${pbc})]";
  echo -e "  -rank\t\tset ranking of atom id [$(boolean ${rank})]";
  echo -e "  -unwrap\tunwrap polymers [$(boolean ${unwrap})]";
  echo -e "  -wd or \n  -workdir\tset work directory [${workdir}]";
  echo -e "  -vdw\t\toutput Van der Waals radii [$(boolean ${vdw})]";
  echo;
  echo "Notes:"
  echo "  * Searches for last trajectory file in simulation series";
  echo "  * Allowed formats are emc, lammps, and pdb";
  echo "  * Defaults are listed in brackets";
  echo;
  exit;
}


# main

  init "$@";

  root="$(dirname $(which emc_${HOST}))/..";

  for location in ${directories[@]}; do
    echo "# scanning ${location}";
    echo;
    files=($(find ${location} -name "*${ext}"));
    if [ -e "${files[0]}" ]; then
      last="";
      parents=();
      for file in $(echo ${files[@]} | sort); do
	parent=$(dirname "$(dirname ${file})");
	if [ "${parent}" == "${last}" ]; then continue; fi;
	parents+=(${parent});
	last=${parent};
      done;
      for parent in ${parents[@]}; do
	echo "# creating ${parent}/last"; echo;
	home=$(pwd); cd ${parent};
	name=$(first $(ls -r */*${ext}));
	dir=$(dirname ${name});
	name=$(basename ${name} ${ext});
	nsites=$(head -n 4 "${dir}/${name}${ext}" | tail -n 1);
	tail \
	  -n $(calc "${nsites}+9") \
	  "${dir}/${name}${ext}" >"${workdir}/last.traject";
	run emc.sh \
	  ${root}/scripts/lammps2${format}.emc \
	    -cut=${cut} -pbc=${pbc} -vdw=${vdw} -rank=${rank} \
	    -unwrap=${unwrap} -source="\"build\"" -target="\"${workdir}\"" \
	    -traject="\"*/*${ext}\"" -start=last -end=last \
	    -compress=${compress} \"${name}\" "\"${workdir}/last\"";
	rm "${workdir}/last.traject";
	cd ${home};
      done;
    fi;
  done;

