#!/bin/bash
#
#  name:	trj_reduce.sh
#  author:	Pieter J. in 't Veld
#  date:	October 15, 2018.
#  purpose:	Reduce number of frames in LAMMPS trajectories
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20181015	Creation date
#

# global variables

  version=0.1;
  date="October 15, 2018";
  script=$(basename $0);
  debug=false;
  info=true;

# functions

function first() {
  echo "$1";
}

function bc() {
  echo "scale=0; $1" | /usr/bin/bc -l;
}

function calc() {
  perl -e 'print(eval(@ARGV[0]), "\n");' "$@";
}
  
function error() {
  echo -e "Error: $@\n";
  exit -1;
}

function info() {
  if [ "$info" != true ]; then return; fi;
  if [ "$1" != "" ]; then echo -e "Info: $@";
  else echo; fi;
}

function header() {
  if [ "$info" != "true" ]; then return; fi;
  echo "LAMMPS trajectory reduction v$version, $date";
  echo "";
}
  
# initialization

function help() {
  info=true;
  header;
  echo "Usage:";
  echo "  $script [-option [value]] traject output";
  echo "";
  echo "Options:"
  echo -e "  -help\t\tthis message";
  echo -e "  -end\t\tset end [${end}]";
  echo -e "  -freq\t\tset freq [${freq}]";
  echo -e "  -start\tset start [${start}]";
  echo;
  if [ "$1" != "" ]; then error $@; fi;
  echo;
  exit;
}

function init() {
  start=0;
  end=-1;
  freq=1;
  while [ "$1" != "" ]; do
    case "$1" in
      -help)	help;;
      -end)	shift; end=$(calc "$1");;
      -freq)	shift; freq=$(calc "int($1)");;
      -start)	shift; start=$(calc "$1");;
      -*)	help "unknown command: $1";;
      *)	if [ "${traject}" == "" ]; then traject="$1";
		elif [ "${output}" == "" ]; then output="$1"; fi;;
    esac;
    shift;
  done;
  if [ "${traject}" == "" ]; then help "undefined traject"; fi;
  if [ "${output}" == "" ]; then help "undefined output"; fi;
}

# application

function apply()
{
  local nframes=$(first $(grep TIMESTEP "${traject}" | wc));
  local natoms=$(head -n 4 "${traject}" | tail -n 1);
  local dline=$(bc "${natoms}+9");
  local first=$(head -n 2 "${traject}" | tail -n 1);
  local last=$(tail -n -$(bc "${dline}-1") "${traject}" | head -n 1);
  local delta=$(bc "(${last}-${first})/(${nframes}-1)");
  local frame=$(bc "(${start}-${first})/${delta}");
  local maxline=$(bc "${nframes}*${dline}");
  local line=$(bc "${maxline}-${frame}*${dline}");
  local dframes=$(bc "(${end}-${start})/${delta}+1");
  local lastline=$(bc "${line}+${dline}*${dframes}");

  if [ "${end}" -lt 0 ]; then lastline=${maxline}; fi;

  info "start = ${start}";
  info "end = ${end}";
  info "freq = ${freq}";
  info "nframes = ${nframes}";
  info "natoms = ${natoms}";
  info "timestep[first] = ${first}";
  info "timestep[last] = ${last}";
  info "timestep[delta] = ${delta}";
  info "frame = ${frame}";
  info "line = ${line}";

  if [ "${freq}" == "1" ]; then
    if [ "${end}" == "-1" ]; then 
      tail -n ${line} "${traject}" >"${output}";
    else
      tail -n ${line} "${traject}" | head -n $(bc "${dline}*${dframes}") >"${output}";
    fi;
  elif [ "${freq}" -gt 0 ]; then
    rm -f "${output}";
    while [ "${line}" -ge "${dline}" ]; do
      tail -n ${line} "${traject}" | head -n ${dline} >>"${output}";
      line=$(bc "${line}-${freq}*${dline}");
    done;
  fi;
  echo;
}

# main

  init "$@";
  header;
  if [ "${end}" != "-1" ]; then
    if [ "${end}" -le "${start}" ]; then error "end before start"; fi;
  fi;
  if [ "${freq}" -lt 1 ]; then error "frequency < 1"; fi;
  apply;
