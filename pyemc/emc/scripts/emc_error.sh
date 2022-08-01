#!/bin/bash
#
#  script:	emc_error.sh
#  author:	Pieter J. in 't Veld
#  date:	July 1, 2018
#  purpose:	Check for errors in LAMMPS output and display last line
#
#  notes:
#    20180701	Creation date
#    20180704	Added error selection
#    20180817	Added LAMMPS restart capabilities
#    20180819	Added EMC restart capabilities
#

# settings

version="0.4";
date="August 19, 2018";

queue="default";
walltime=24:00:00;
starttime=now;

# initialization

init() {
  femc=0;
  flammps=0;
  fresult=0;
  project="";
  directories=();
  errors=();
  while [ "$1" != "" ]; do
    case "$1" in
      -help)		script_help;;
      -emc)		flammps=0; femc=1;;
      -error)		shift; errors+=("$1");;
      -lammps)		flammps=1; femc=0;;
      -n)		shift; n=$1;;
      -queue)		shift; queue=$1;;
      -result)		fresult=1;;
      -walltime)	shift; walltime=$1;;
      -*)		script_help;;
      *)		if [ "$project" = "" ]; then project="$1";
			else directories+=("$1"); fi;;
    esac;
    shift;
  done;
  if [ "$project" == "" ]; then script_help; fi;
  if [ ${#directories[@]} -eq 0 ]; then directories=(*); fi;
  if [ "${frestart}" == "1" ]; then
    if [ "${n}" == "" ]; then error "n not set"; fi;
  fi;
}


script_help() {
  echo "LAMMPS output error checker v${version} (${date})"
  echo;
  echo "Usage:";
  echo "  $(basename $0) [-option [value]]  project [dir [...]]";
  echo;
  echo "Options:"
  echo -e "  -help\t\tthis message";
  echo -e "  -emc\t\ttoggle emc restart"
  echo -e "  -error\tset specific error [${error}]";
  echo -e "  -lammps\ttoggle lammps restart";
  echo -e "  -n\t\tset number of processors";
  echo -e "  -queue\tset queue [${queue}]";
  echo -e "  -result\ttoggle output of resulting error";
  echo -e "  -walltime\tset total wall time [${walltime}]";
  echo;
  echo "Notes:"
  echo -e "  * Frequent errors:"
  echo;
  echo -e "      missing\tmissing atoms (bond or otherwise)";
  echo -e "      open\tcannot open file (read_data or read_restart)";
  echo -e "      range\tout of range atoms (PPPM issue)";
  echo -e "      unstable\tsimulation unstable (PPPM issue)";
  echo;
  echo -e "  * Invoking -error multiple times functions as additive"
  echo;
  exit -1;
}


# general functions

first() {
  echo "$1";
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


ltime() {
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


unique() {
  perl -e '
    foreach (@ARGV) {
      @a = split("\/"); pop(@a); pop(@a);
      $h{join("\/", @a)} = 1;
    }
    print(join(" ", sort(keys(%h))), "\n");
  ' $@;
}

fill() {
  perl -e '
    $w = shift(@ARGV);
    $f = "%".$w.".".$w."s";
    foreach(@ARGV) {
      print(" ") if ($t); $t = 1;
      printf($f, $_);
    }
  ' $@;
}


# execution

run_emc() {
  run \
    run.sh -n 1 \
      -queue ${queue} \
      -walltime ${walltime} \
      -project ${project} \
      -output build.out \
      emc_${HOST} \
	-seed=${seed} build.emc
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


# main

  init "$@";
  seed=$(date +%s);
  home="$(pwd)";

  for dir in $(unique $(find ${directories[@]} -name "${project}.out")); do
    files+=($(first $(ls -t $(find ${dir} -name "${project}.out"))));
  done;

  length=0;
  for file in ${files[@]}; do
    if [ ${#file} -gt ${length} ]; then length=${#file}; fi;
  done;

  for file in ${files[@]}; do
    
    result="$(grep ERROR "${file}")";
    if [ "${result}" = "" ]; then
      continue;
    fi;
    if [ "${#errors[@]}" -ne 0 ]; then
      flag=0;
      for error in ${errors[@]}; do
	if [ "$(echo "${result}" | grep "${error}")" != "" ]; then flag=1; fi;
      done;
      if [ "$flag" == 0 ]; then continue; fi;
    fi;

    output="$(fill ${length} ${file})";
    output+=" $(fill 5 $(average.pl "${file}" | grep SAMPLES | wc))";
    output+=" $(fill 10 $(ltime "${file}"))";
    if [ "${fresult}" == "1" ]; then
      output+=" | $(perl -e '
	@a=split(":", (split("\n", @ARGV[0]))[0]);
	shift(@a); print(join(" ", split(" ", join(":", @a))));' "${result}")";
    fi;
    
    home="$(pwd)";
    dir="$(dirname "$file")";

    if [ "${femc}" == 1 ]; then
      echo -e "# ${dir}\n";
      echo -e "# ${output}\n";
      run cd "$(dirname "${dir}")/build";
      rm -f error.xyz;
      run_emc;
      run cd "${home}";
      echo;

    elif [ "${flammps}" == 1 ]; then
      echo -e "# ${dir}\n";
      echo -e "# ${output}\n";
      run cd "${dir}";
      run_lammps;
      run cd "${home}";
      echo;

    else
      echo "${output}";
    fi;
  
  done;

