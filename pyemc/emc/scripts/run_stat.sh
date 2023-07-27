#!/bin/bash
#
#  script:	run.sh
#  author:	Pieter J. in 't Veld
#  date:	May 30, October 29, 2018.
#  purpose:	submit parallel jobs to LSF, PBS, or Slurm queues; calls itself
#		as submit script
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20180530	Creation date
#    20181028	Addition of queueing system recognition
#

# Functions

local_which() {
  local output="$(which $1 2>&1)";

  if [ "${output}" != "" ]; then
    if [ "$(echo "${output}" | grep "no $1")" == "" ]; then echo $1; fi;
  fi;
}


system_queue() {
  if [ "$(local_which bsub)" != "" ]; then echo lsf;
  elif [ "$(local_which qsub)" != "" ]; then echo pbs;
  elif [ "$(local_which sbatch)" != "" ]; then echo slurm; fi;
}


lsf_stat() {
  local name="$1";
}


pbs_stat() {
  qstat -f $1 2>&1 | grep job_state | perl -e '
    foreach(<>) { @a=split(" "); } print(@a[-1]);';
}


slurm_stat() {
  local result=$( \
    squeue -j $1 2>&1 | grep $1 | perl -e '
      foreach(<>) { @a=split(" "); } print(@a[4]);');

  if [ "${result}" == "R" ]; then echo "R";
  elif [ "${result}" == "PD" ]; then echo "Q";
  elif [ "${result}" == "CG" ]; then echo "F";
  else echo "U"; fi;
}


stat() {
  local queue=$(system_queue);

  if [ "${queue}" == "lsf" ]; then lsf_stat;
  elif [ "${queue}" == "pbs" ]; then lsf_stat;
  elif [ "${queue}" == "slurm" ]; then lsf_stat; fi;
}


# main

  current="U";
  while [ "$1" != "" ]; do
    stat=$(stat $1);
    case "$stat" in
      R) current="R";;
      Q) if [ "$current" != "R" ]; then current="Q"; fi;;
      F) if [ "$current" != "R" -a "$current" != "Q" ]; then current="F"; fi;;
    esac;
    shift;
  done;
  echo $current;

