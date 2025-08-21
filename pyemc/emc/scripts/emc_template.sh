#!/bin/bash
#
#  program:	emc_template.sh
#  author:	Pieter J. in 't Veld
#  date:	June 22, 27, July 23, 2018, March 2, 18, 2019, March 26, 2024.
#  purpose:	Copying of templates as available in the template directory
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20180622	Creation date
#    20180627	Added empty line at end
#    20190302	Added -list
#    20190318	Creates setup.esh when target is omitted (was template.esh)
#    20240326	Change to v1.2
#    		Added date and script replacement in resulting .esh
#

# variables

info=1;
replace=0;
script=$0;
version=1.2;
year=2014;
author="Pieter J. in 't Veld";
date="March 26, $year";


# functions

function header() {
  echo "EMC setup template v$version ($date), (c) 2008-$year $author";
  echo;
}


function show_list() {
  if [ -d "${template_dir}" ]; then
    if [ "${list}" != "1" ]; then echo "Available templates:"; fi;
    pushd "${template_dir}" >& /dev/null;
    for file in *.esh; do
      echo "  "$(basename ${file} .esh);
    done;
    popd >& /dev/null;
    echo;
  fi;
}


function script_help() {
  header;
  echo "Usage:";
  echo "  $(basename $script) [-option [#]] template [target]"
  echo ""
  echo "Options:"
  echo -e "  -help\t\tthis message";
  echo -e "  -info\t\toutput information";
  echo -e "  -list\t\toutput of template list only";
  echo -e "  -quiet\tsuppress output information";
  echo -e "  -replace\treplace exisiting setup scripts";
  echo;
  echo -e "Notes:"
  echo -e "  * An input file with name 'setup.esh' is created when target is omitted";
  echo -e "  * Options can be activated by either using its full representation or its";
  echo -e "    first letter";
  echo;
  show_list;
  exit;
}


function list() {
  echo $(show_list);
  echo;
  exit;
}


function initialize() {
  if [ "$EMC_ROOT" == "" ]; then
    root="$(dirname $(dirname ${script}))";
  else
    root="$EMC_ROOT";
  fi;
  template_dir="${root}/templates";

  while [ "$1" != "" ]; do
    case "$1" in
      -h)	script_help;;
      -help)	script_help;;
      -i)	info=1;;
      -info)	info=1;;
      -l)	list=1;;
      -list)	list=1;;
      -q)	info=0;;
      -quiet)	info=0;;
      -r)	replace=1;;
      -replace)	replace=1;;
      *)	files+=("$(basename $1 .esh)");;
    esac;
    shift;
  done;
  if [ "${list}" == "1" ]; then list; fi;
  if [ ${#files[@]} -eq 1 ]; then files+=("setup"); fi;
  if [ ${#files[@]} -ne 2 ]; then script_help; fi;
}


function info() {
  if [ "${info}" != "1" ]; then return; fi;
  echo -e "Info: $@";
}


function error() {
  if [ "${info}" != "1" ]; then header; fi;
  echo -e "Error: $@";
  echo;
  exit -1;
}


# main

  initialize $@;
  if [ "${info}" == "1" ]; then header; fi;
  if [ ! -e "${template_dir}/${files[0]}.esh" ]; then
    error "unknown file '${template_dir}/${files[0]}.esh'";
  fi;
  if [ "${replace}" != "1" -a -e "${files[1]}.esh" ]; then
    error "target file '${files[1]}.esh' exists";
  fi;

  info "using '${files[0]}.esh' to create '${files[1]}.esh'";
  cp "${template_dir}/${files[0]}.esh" "${files[1]}.esh";

  if [ "${info}" == "1" ]; then 
    replace.pl -s "${files[0]}.esh" "${files[1]}.esh" "${files[1]}.esh";
    echo;
  else
    replace.pl -q -s "${files[0]}.esh" "${files[1]}.esh" "${files[1]}.esh";
  fi;

