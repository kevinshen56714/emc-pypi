#!/bin/bash
#
#  script:	cavity.sh
#  author:	Pieter J. in 't Veld
#  date:	February 8, 24, October 8, 2018.
#  purpose:	cavity size sampling of LAMMPS trajectories 
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20180208	Creation date
#    20180224	Refined execution by adding clean up
#    20181008	Added -target to allow for alternate output directory
#

# variables

version="1.2.1";
type="cavity";
date="February 24, 2018";
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
  window=1;
  replace=1;
  binsize=0.01;
  frequency=1;
  ninserts=1000;
  niterations=200;
  record="";
  queue="default";
  walltime="24:00:00";

  while [ "$1" != "" ]; do
    case "$1" in
      -help) 		help;;
      -archive)		shift; archive="$1";;
      -binsize)		shift; binsize=$(calc "$1");;
      -dir)		shift; dir="$1";;
      -end)		shift; end=$(calc "$1");;
      -frequency)	shift; frequency=$(calc "$1");;
      -ninserts)	shift; ninserts=$(calc "$1");;
      -niterations)	shift; niterations=$(calc "$1");;
      -record)		shift; record=$(flag "$1");;
      -replace)		shift; replace=$(flag "$1");;
      -queue)		shift; queue="$1";;	
      -start)		shift; start=$(calc "$1");;
      -skip)		shift; start=$(calc "$1");;
      -target)		shift; target="$1";;
      -type)		shift; type="$1";;
      -walltime)	shift; walltime="$1";;
      -zero)		shift; zero=$(flag "$1");;
      -*)		shift;;
      *)		if [ "${project}" == "" ]; then project="$1"; fi;;
    esac
    shift;
  done;
  if [ "${project}" == "" ]; then help; fi;
  if [ "${record}" == "1" ]; then
    record="${type}_${project}";
  else
    record="";
  fi;
  if [ "${target}" != "" ]; then 
    if [ "${archive}" != "" ]; then archive="${target}/${archive}"; fi;
    target="${target}/${dir}/";
    if [ ! -e "${target}" ]; then 
      mkdir -p "${target}";
    fi;
  fi;
}


help() {
  echo "EMC $type cavity analysis script v${version}, ${date}
";
  echo "Usage:
  $script [-option [#]] project
";
  echo "Options:";
  echo "  -help		this message";
  echo "  -archive	set file to which to archive [${archive}]";
  echo "  -binsize	set binsize [${binsize}]";
  echo "  -dir		set work directory [${dir}]";
  echo "  -end		set end frame; -1 is end of file [${end}]";
  echo "  -frequency	set sampling frequency [${frequency}]";
  echo "  -ninserts	set number of inserts [${ninserts}]";
  echo "  -niterations	set number of trials [${niterations}]";
  echo "  -record	set recording of cavities in PDB [$(boolean ${record})]";
  echo "  -replace	set replacement of exisiting results [$(boolean ${replace})]";
  echo "  -skip		set time step to start at [${start}]";
  echo "  -start	set time step to start at [${start}]";
  echo "  -target	set alternate output directory [${target}]";
  echo "  -type		set evaluation type [${type}]";
  echo "  -walltime	set submission walltime [${walltime}]";
  echo "  -zero		set inclusion of negative sizes as zero [$(boolean ${zero})]";
  echo;
  exit;
}


create_vmd() {
  echo "#!/usr/bin/env vmd -e

# load structure

set project ${type}_${project}

if { [file exists \$project.psf.gz] == 1} {    
  exec gunzip \$project.psf.gz
}
if { [file exists \$project.pdb.gz] == 1} {    
  exec gunzip \$project.pdb.gz
}

mol new \$project.psf waitfor all
mol addfile \$project.pdb waitfor all

exec gzip \$project.psf
exec gzip \$project.pdb

# adapt VDW radii

set select [atomselect top all]
\$select set radius [vecscale 0.010 [\$select get type]]
\$select delete

# cavity centers

mol representation VDW
mol selection {segname A}
mol material Opaque
mol addrep top

# cavity saddle points

mol representation VDW
mol selection {segname B}
mol material Opaque
mol addrep top

# set render mode

display rendermode GLSL

# set periodic box

pbc box
" >"$1";
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
	  -start=${start} -end=${end} -frequency=${frequency} \
	  -zero=${zero} -binsize=${binsize} -ninserts=${ninserts} \
	  -niterations=${niterations} -record="${target}${record}" \
	  -traject="*/${project}.dump" 
	  -input="build/${project}.emc.gz" -work="${target}" \
	  -output="${target}${type}_${project}" \
	  "${root}/sample/${type}.emc";
      create_vmd "${type}_${project}";
    fi;
    if [ "${archive}" != "" ]; then
      echo ${dir}/${type}_${project}.csv >>"${archive}";
      echo ${dir}/${type}_${project}.m >>"${archive}";
      if [ "${record}" != "" ]; then
	create_vmd "${target}${type}_${project}.vmd";
	echo ${dir}/${type}_${project}.psf >>"${archive}";
	echo ${dir}/${type}_${project}.pdb >>"${archive}";
	echo ${dir}/${type}_${project}.vmd >>"${archive}";
      fi;
    fi;
  fi;
  echo;
}


# main

  init "$@";
  submit;

