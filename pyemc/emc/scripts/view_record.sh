#!/bin/bash
#
#  program:	view_vmd.sh
#  author:	Pieter J. in 't Veld
#  date:	September 3, 2019
#  purpose:	View recorded builds
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20190903	Creation date
#

# variables

script=$0;
version=0.1;

execute="false";
info="true";
orthographic="true";
bgcolor="white";
output="record";
find=false;

# functions

function boolean() {
  if [ "$1" == "" || "$1" == "1" || "$1" == "true" ]; then echo "true";
  else echo "false";
  fi;
}


function strip_ext () {
  local ext;
  local name="$1"; shift;

  for ext in .pdb .psf .vmd; do
    name="$(basename "$name" $ext)";
  done;
  echo "$name";
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
      -output)		shift; output="$(strip_ext "$1")";;
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
  echo "EMC script creating VMD Tcl script for viewing recorded PDBs v$version";
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
  echo -e "  -output\tset base output name [$output]";
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
  local out="$output.vmd";

  home=$(pwd);
  info "using $out for output";
  echo "#!/usr/bin/env vmd -e" >$out;
  echo "" >>$out;
  if [ "$orthographic" == "true" ]; then
    echo "display projection Orthographic" >>$out;
  fi;
  echo "set val [catch {color Display {Background} $bgcolor}]" >>$out;
  echo "
# variables

set project "record"

# load structure

mol new \$project.psf waitfor all
mol addfile \$project.pdb waitfor all

# set representation

mol delrep 0 top
mol representation Licorice
mol selection {not x = 0}
mol color Type
mol addrep top
mol selupdate 0 top 1
mol colupdate 0 top 1
mol showrep top 0 1

# set periodic box

pbc box
  " >>$out;
  chmod +x $out;
}


function convert_ext()
{
  local dir;
  local name;
  local result;
  local ext=$1; shift;

  for file in $@; do
    dir=$(dirname $file);
    name=$(strip_ext $file);
    result+=($dir/$name$ext);
  done;
  echo ${result[@]};
}


# main

  intialize $@;
  cat $(convert_ext .pdb ${files[@]}) >$output.pdb;
  create_vmd $output.pdb;
  cp $(convert_ext .psf ${files[${#files[@]}-1]}) $output.psf;
  if [ "$execute" == "true" ]; then
    info "starting VMD";
    write;
    vmd -e "$output.vmd";
  else
    write;
  fi;

