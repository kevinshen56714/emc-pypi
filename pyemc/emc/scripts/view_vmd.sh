#!/bin/bash
#
#  program:	view_vmd.sh
#  author:	Pieter J. in 't Veld
#  date:	July 12, 2017, February 8, November 29, 2018, February 25, 2019
#  purpose:	Creation of a VMD Tcl script for viewing multiple PDBs at once;
#		part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20170712	Creation date
#    20180203	Added index counter
#    20181129	Added find option
#    20190225	Added background color
#

# variables

script=$0;
version=1.2;

execute="false";
info="true";
orthographic="true";
bgcolor="white";
output="view.vmd";
find=false;

# functions

function boolean() {
  if [ "$1" == "" || "$1" == "1" || "$1" == "true" ]; then echo "true";
  else echo "false";
  fi;
}


function intialize() {
  local file;
  local tmp;

  while [ "$1" != "" ]; do
    case "$1" in
      -execute)		shift; execute=$(boolean $1);;
      -exec)		shift; execute=$(boolean $1);;
      -e)		execute="true";;
      -f)		find=true;;
      -find)		find=true;;
      -h)		script_help;;
      -help)		script_help;;
      -i)		info="true";;
      -info)		shift; info=$(boolean $1);;
      -orthographic)	shift; orthographic=$(boolean $1);;
      -ortho)		shift; orthographic=$(boolean $1);;
      -o)		orthographic="true";;
      -output)		shift; output=$(basename "$1" .vmd).vmd;;
      -p)		orthographic="false";;
      -q)		info="false";;
      *)		files+=($1);;
    esac;
    shift;
  done;
  if [ ${#files[@]} -eq 0 ]; then script_help; fi;
  if [ "$find" = "true" ]; then
    for file in ${files[@]}; do 
      tmp+=($(find * -name "$file")); 
    done;
    files=(${tmp[@]});
  fi;
  if [ "$info" = "true" ]; then header; fi;
}


function header() {
  echo "EMC script creating VMD Tcl script for viewing PDBs v$version";
  echo;
}


function script_help() {
  header;
  echo "Usage:";
  echo "  $(basename $script) [-option [#]] file.pdb|file.vmd [...]"
  echo ""
  echo "Options:"
  echo -e "  -help\t\tthis message";
  echo -e "  -bg\t\tset background color [$bgcolor]";
  echo -e "  -e\t\tforce VMD execution of the created script";
  echo -e "  -execute\texecute the created script with VMD [$execute]";
  echo -e "  -f[ind]\tuse find to collect files";
  echo -e "  -i\t\tforce info output";
  echo -e "  -info\t\tset info output [$info]";
  echo -e "  -output\tset output VMD Tcl script name [$output]";
  echo -e "  -o\t\tforce orthographic viewing mode";
  echo -e "  -ortho\tset orthographic viewing mode [$orthographic]";
  echo -e "  -p\t\tforce perspective viewing mode";
  echo "";
  echo "Notes:"
  echo "  * Works with specifying either .pdb, .psf, or .vmd extensions";
  echo "";
  exit;
}


function info {
  if [ "$info" = "true" ]; then echo "Info: $@"; fi;
}


function write {
  if [ "$info" = "true" ]; then echo "$@"; fi;
}


function create_vmd() {
  local structure;
  local file;
  local root;
  local dir;
  local index=0;
  local	n=-1;

  home=$(pwd);
  info "using $output for output";
  echo "#!/usr/bin/env vmd -e" >$output;
  echo "" >>$output;
  if [ "$orthographic" == "true" ]; then
    echo "display projection Orthographic" >>$output;
  fi;
  echo "set val [catch {color Display {Background} $bgcolor}]" >>$output;
  echo "" >>$output;
  for structure in $@; do n=$[$n + 1]; done;
  for structure in $@; do
    if [ ! -e "$structure" ]; then continue; fi;
    info "adding $structure";
    dir=$(dirname $structure);
    file=$(basename $structure .vmd);
    file=$(basename $file .pdb);
    file=$(basename $file .psf);
    echo "puts \"\"" >> $output;
    echo "puts \"reading $index/$n: $dir/$file\"" >> $output;
    if [ -e "$dir/$file.vmd" ]; then
      echo "cd \"$dir\"" >>$output;
      echo "source \"$file.vmd\"" >>$output;
      echo "cd \"$home\"" >>$output;
      echo "mol rename top \"$dir\"" >>$output;
      echo "mol off top" >>$output;
    else
      if [ -e "$dir/$file.psf" ]; then
	echo "set current [ mol new \"$dir/$file.psf\" waitfor all ]" >>$output;
	echo "mol addfile \"$dir/$file.pdb\" waitfor all" >>$output;
      else
	echo "set current [ mol new \"$dir/$file.pdb\" waitfor all ]" >>$output;
      fi;
      echo "mol rename \$current \"$dir\"" >>$output;
      echo "mol modstyle 0 \$current Lines 1" >>$output;
      echo "pbc box" >>$output;
      echo "mol off \$current" >>$output;
    fi;
    echo "" >>$output;
    index=$[$index + 1];
  done;
  chmod +x $output;
}


# main

  intialize $@;
  create_vmd ${files[@]};
  if [ "$execute" == "true" ]; then
    info "starting VMD";
    write;
    vmd -e "$output";
  else
    write;
  fi;

