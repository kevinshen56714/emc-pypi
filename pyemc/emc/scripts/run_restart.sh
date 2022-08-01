#!/bin/bash
#
#  script:	run_restart.sh
#  author:	Pieter J. in 't Veld
#  date:	April 11, 2018
#  purpose:	Restart crashed LAMMPS jobs
#
#  notes:
#    20180411	Creation date
#    20180627	Addition of queue
#    20180704   Addition of error
#

# settings

version=0.3;
date="July 4, 2018";
script=$(basename "$0");

err="range";
queue="default";
walltime=24:00:00;
starttime=now;

# functions
  
help() {
  echo "LAMMPS restart script v$version ($date)";
  echo;
  echo "Usage:";
  echo "  ${script} -n nprocs [-option value] project [dir [...]]";
  echo;
  echo "Options:"
  echo -e "  -help\t\tthis message";
  echo -e "  -error\tset specific error [${err}]";
  echo -e "  -n\t\tset number of processors";
  echo -e "  -queue\tset queue [${queue}]";
  echo -e "  -walltime\tset total wall time [${walltime}]";
  echo;
  exit -1;
}


error() {
  echo "ERROR: $1";
  echo;
  exit -1;
}


run() {
  echo "$@"; $@;
}


calc() {
  perl -e 'print(eval($ARGV[0]));' $@;
}


substr() {
  perl -e 'print(substr($ARGV[0],eval($ARGV[1])));' $@;
}


init() {
  local error;

  n="";
  project="";
  directories=();
  if [ "$1" = "" ]; then help; fi;
  while [ "$1" != "" ]; do
    case "$1" in 
      -help)		help;;
      -error)		shift; err="$1";;
      -n)		shift; n=$1;;
      -queue)		shift; queue=$1;;
      -walltime)	shift; walltime=$1;;
      *)		if [ "${project}" == "" ]; then project="$1";
			else directories+=("$1"); fi;;
    esac;
    shift;
  done;
  if [ "${n}" == "" ]; then error "n not set"; fi;
  if [ "${project}" == "" ]; then error "project not set"; fi;
  if [ ${#directories[@]} -eq 0 ]; then directories=(*); fi;
}


run_emc() {
  run_sh -n 1 \
    -walltime ${walltime} -starttime ${starttime} -queue ${queue} \
    -project ${project} \
      emc_${HOST} -seed=${seed} build.emc -output build.out
  seed=$(calc ${seed}+1);
}


run_lammps() {
  run \
    run.sh -n ${n} \
      -queue ${queue} \
      -walltime ${walltime} \
      -input ${project}.in \
      -output ${project}.out \
      lmp_${HOST} \
	-var frestart 0 \
	-var lseed $(substr ${seed} -8) \
	-var vseed $(substr $(calc "${seed}+1") -8);
  seed=$(calc "${seed}+2");
}


last() {
  perl -e '
    $read = 0;
    foreach (reverse(<>)) {
      @a = split(" ");
      if (substr($_,0,11) eq "application") { next; }
      if (substr($_,0,5) eq "ERROR") { $read = 1; next; }
      last if ($read == 1);
    };
    print(join(" ", @a), "\n") if ($read);
  ' $@;
}


submit() {
  for file in $(find ${directories[@]} -name ${project}.out | sort); do
    result="$(grep ERROR "${file}")";
    if [ "${result}" = "" ]; then
      continue;
    fi;
    if [ "${err}" != "" ]; then
      if [ "$(echo "${result}" | grep "${err}")" = "" ]; then continue; fi;
    fi;
    #echo ${file} $(average.pl "${file}" | grep SAMPLES | wc) $(last "${file}");
    home=$(pwd);
    dir=$(dirname $file);
    echo "# ${dir}";
    echo;
    run cd ${dir};
    run_lammps;
    run cd ${home};
    echo;
  done;
}


# main

  seed=$(date +%s);

  init $@;
  submit;
  
