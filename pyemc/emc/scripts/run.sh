#!/bin/bash
#
#  script:	run.sh
#  author:	Pieter J. in 't Veld
#  date:	July 5, September 10, 2013, February 10, 2014,
#		April 16, 2014, March 14, 23, May 8, July 3, 17, 2017,
#		December 2, 19, 2017, February 24, May 26, 31, July 5,
#		October 29, 2018, August 17, 2019, May 23, 2020, April 4,
#		August 20, 2022, September 3, December 19, 2023, 
#		January 3-19, July 9, August 14, 2024.
#  purpose:	execute job in LSF, PBS, or Slurm queues or directly on local
#		host; part of EMC work flow
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License v3 as stated in LICENSE file in EMC
#  root directory
#
#  notes:
#    20130705	- Creation date
#    20170314	- Added local queue to side-step queue submission
#    20170323	- Added wait and file options
#		- Rewrote use of commands
#    20170703	- Made some minor adjustements with respect to queue
#    20170716	- Adjusted the use of the -file and @FILE combo
#    20171202	- Corrected behavior when using -file for PBS
#    20171219	- Added -nppt to allow for assigning multiple threads for
#		  PBS
#		- Added -mode to select PBS assignment mode (how processes are
#		  to nodes)
#		- Added -backfill, which equals -mode 1
#    20180224	- Added -sleep to avoid queueing system time outs
#    20180526	- Added local mpi execution of multi-processor jobs
#    20180531	- Added -memory per core for PBS queues
#		- Added -single node mode
#    20180705	- Corrected -file behavior
#    20181028	- Corrected queueing system determination (behavior of which
#		  depends on OS)
#    20190817	- Added -account to allow for charging accounts and -user to
#		  allow for queue-specific settings not covered by run.sh
#    20200523	- Corrected behavior for running local jobs
#    20220404	- New version: 3.4
#		- Added -modules for loading modules during execution
#    20220820	- New version: 3.5
#		- Changed interpretation of pbs_select
#		- Added purge to module interpretation
#    20230914	- New version: 3.6
#    		- Added -scratch for use of local scratch on compute nodes
#    20231219	- Deleted spurious colon in PBS memory designation
#    20240103	- New version: 3.7
#    		- Added -account and -queue_project to run_init() options
#		- -queue_projects is a PBS option only
#		- Guaranteed colons as separation between modules
#    20240112	- Added -headnode to set alternate stageout headnode
#    20240119	- Added -scratch_cd to control changing to scratch directory
#    20240709	- Added 'export OMPI_MCA_hwloc_base_binding_policy=none' before
#    		  mpiexec to force a bind to none of processes on one node by
#    		  OpenMPI
#    20240814	- Corrected slurm_run() to call sbatch
#    20241002	- Added -bind option
#    20241019	- Added --use-hwthread-cpus to mpiexec when using local mode
#

# Script version

version=3.7;
date="October 19, 2024";
script=$(basename "$0");


# Variables

account=none;

bind=default;

headnode="default";

join=true;

local="local";

memory=default;
mode=0;
mpiprocs=default;

nppt=1;
nppn=64;

project=default;

queue=default;
queue_project=none;

scratch=none;
scratch_cd=true;
sleep=0.1;
starttime=now;
subscript=;
sync=false;

walltime=;


# Functions

run() {
  echo "$@"; $@;
}


append() {
  echo "$@";
}


first() {
  echo "$1";
}


nosingle() {
  local v="$1";

  while [[ "${v#\'}" != "$v" && \
	   "${v%\'}" != "$v" ]]; do v="${v#\'}"; v="${v%\'}"; done;
  echo "$v";
}


single() {
  local v="$(nosingle "$1")";

  if [[ "$v" =~ ' ' ]]; then echo "'$v'";
  elif [[ "$v" =~ '*' ]]; then echo "'$v'";
  else echo "$v"; fi;
}


nodouble() {
  local v="$1";

  while [[ "${v#\"}" != "$v" && \
	"${v%\"}" != "$v" ]]; do v="${v#\"}"; v="${v%\"}"; done;
  echo "$v";
}


quote() {
  local v="$(nodouble "$1")";

  if [[ "$v" =~ ' ' ]]; then echo "\"$v\"";
  else echo "$v"; fi;
}


comma2colon() {
  perl -e '@ARGV[0] =~ s/,/:/g; print(@ARGV[0]);' "$@";
}


split() {
  perl -e 'print(join(" ", split(@ARGV[0], @ARGV[1])));' "$@";
}


calc() {
  perl -e 'print(eval(@ARGV[0]));' "$@";
}


int() {
  calc "int($1)";
}


flag() {
  local value=$(calc "$1");

  if [ "$1" == true ]; then echo $1;
  elif [ "$1" == false ]; then echo $1;
  elif [ "${value}" == 0 ]; then echo false;
  else echo true; fi;
}


local_which() {
  local output="$(which $1 2>&1)";

  if [ "${output}" != "" ]; then
    if [ "$(echo "${output}" | grep "no $1")" == "" ]; then echo $1; fi;
  fi;
}


set_modules() {
  local module;
  local args;
  local arg;

  for args in $@; do
    for module in $(split ":" ${args}); do
      arg=($(split "=" ${module}));
      if [ ${module} == "purge" ]; then
	echo "module purge";
	module purge;
      elif [ ${#arg[@]} == 1 ]; then
	echo "module load ${module}";
	module load ${module};
      else
	echo "module ${arg[0]} ${arg[1]}";
	module ${arg[0]} ${arg[1]};
      fi;
    done;
  done;
}


system_queue() {
  if [ "$(local_which bsub)" != "" ]; then echo lsf;
  elif [ "$(local_which qsub)" != "" ]; then echo pbs;
  elif [ "$(local_which sbatch)" != "" ]; then echo slurm;
  else echo "unknown"; fi;
}


set_time() {
  perl -e '
    $nargs = scalar(@arg = split(":", @ARGV[1]));
    $max = @ARGV[0]; $digit = $nargs ? 0 : 24;
    while (scalar(@arg)<$max) {
      push(@arg, $digit); $digit = 0;
    }
    @arg = @arg[0 .. $max-1];
    foreach (@arg) {
      $_ = sprintf("%02d", $_);
    }
    print(join(":", @arg))
  ' $@;
}


# Initialization

script_help() {
  echo "Wrap-around for PBS, Slurm, and LSF queue submission v${version} (${date})";
  echo;
  echo "Usage:";
  echo "  ${script} -n nprocs [-option value] command ...";
  echo;
  echo "Options:"
  echo -e "  -help\t\tthis message";
  echo -e "  -account\tset account to charge to [${account}]";
  echo -e "  -backfill\tset backfill mode; can scatter processes (PBS only)";
  echo -e "  -bind\t\tset binding policy for processes [${bind}]";
  echo -e "  -exclude\tset nodes to be excluded during run (LSF only) []";
  echo -e "  -file\t\tdefine newest file name by means of wildcards";
  echo -e "  -headnode\tset alternate stageout head node [${headnode}]";
  echo -e "  -input\tset piped input file name";
  echo -e "  -join\t\tkeep cpus together on full nodes (PBS only) [${join}]";
  echo -e "  -local\texecute arguments locally";
  echo -e "  -memory\tset memory per core in gb (PBS only) [${memory}]";
  echo -e "  -mode\t\tset processor assignment mode (PBS only) [${mode}]";
  echo -e "  -modules\tset modules to load";
  echo -e "  -n\t\tset number of processors; includes threads";
  echo -e "  -nodes\tset nodes subset to run on (LSF only) []";
  echo -e "  -output\tset piped output file name";
  echo -e "  -ppn\t\tset number of processors per node (PBS only) [${nppn}]";
  echo -e "  -ppt\t\tset number of processes per thread (PBS only) [${nppt}]";
  echo -e "  -project\tset project name [${project}]";
  echo -e "  -queue\tset desired queue [${queue}]";
  echo -e "  -queue_project\tset queue project name (PBS only) [${queue_project}]";
  echo -e "  -scratch\tset scratch directory variable of value [${scratch}]";
  echo -e "  -scratch_cd\tchange directory to scratch upon execution [${scratch_cd}]";
  echo -e "  -single\tactivate single node mode (no mpiexec)";
  echo -e "  -sleep\tset sleep time after submission [${sleep}]";
  echo -e "  -starttime\tset time for job to start [${starttime}]";
  echo -e "  -sub\t\tset alternate submission script [${subscript}]";
  echo -e "  -submit\trun script in submission mode";
  echo -e "  -system\tset queueing system (PBS or LSF) []";
  echo -e "  -sync\t\tsynchronization by job [${sync}]";
  echo -e "  -user\t\tallow for including queue-specific commands";
  echo -e "  -wait\t\tset job id to wait on [${wait}]";
  echo -e "  -walltime\tset total wall time [${walltime}]";
  echo -e "  -work\t\tset root of originating work directory [${work}]";
  echo;
  echo -e "Notes:";
  echo -e "  * After command use";
  echo -e "      * '-input name' for pipe '< name'";
  echo -e "      * '-output name' for pipe '> name'";
  echo -e "  * '-queue ${local}' side-steps queueing system and executes on local host";
  echo -e "  * '-queue default' selects default queue as defined by queueing system"
  echo -e "  * -file '*' will pass the newest file to command line variable @FILE";
  echo -e "  * -user allows for unsupported options to be passed on directly to the";
  echo -e "    selected queuing system";
  echo;
  exit -1;
}


run_init() {
  local fuser=0;
  local error="";
  
  help=false;
  wait="";
  single=0;
  system="";
  work="";
  error=();
  commands=();
  mpiexec=();
  user=();
  while [ "$1" != "" ]; do
    if [ ${fuser} != 0 ]; then
      case "$1" in
	-*) if [ ${fuser} == 2]; then
	      user+=($1);
	      fuser=1;
	    else
	      fuser=0;
	    fi;;
	*)  if [ ! -e "$(which $1)" -a ${fuser} == 1 ]; then
	      user+=($1);
	    fi;
	    fuser=0;;
      esac;
    fi;
    if [ ${fuser} == 0 ]; then
      case "$1" in
	-account)	shift; account="$1";;
	-backfill)	mode=1;;
	-bind)		shift; commands+=(-bind "$1");;
	-exclude)	shift; exclude=$1;;
	-file)		shift; commands+=(-file "$(single "$1")");;
	-help)		help=true;;
	-headnode)	shift; headnode=$1;;
	-input)		shift; commands+=(-input "$(single "$1")");;
	-join)		shift; commands+=(-join "$(flag $1)");; 
	-local)		system=${local};;
	-memory)	shift; memory=$1;;
	-mode)		shift; mode=$(int $1);;
	-modules)	shift; commands+=(-modules "$(comma2colon "$1")");;
	-mpiexec)	shift; mpiexec+=("$1");;
	-mpiprocs)	shift; mpiprocs=$(int $1);;
	-n)		shift; nprocs=$(int $1);;
	-nodes)		shift; nodes=$(int $1);;
	-output)	shift; commands+=(-output "$(single "$1")");;
	-ppn)		shift; nppn=$(int $1);;
	-ppt)		shift; nppt=$(int $1);;
	-project)	shift; project=$1;;
	-queue)		shift; queue=$1;;
	-queue_project)	shift; queue_project="$1";;
	-scratch)	shift; commands+=(-scratch "$1"); scratch="$1";;
	-scratch_cd)	shift; commands+=(-scratch_cd $(flag "$1"));;
	-single)	commands+=(-single);;
	-sleep)		shift; sleep=$1;;
	-starttime)	shift; starttime=$1;;
	-sub)		shift; subscript=$1;;
	-sync)		shift; sync=$(flag "$1"); commands+=(-sync $sync);;
	-system)	shift; system=$1;;
	-user)		fuser=2;;
	-wait)		shift; wait=$1;;	
	-walltime)	shift; walltime=$1;;
	-work)		shift; commands+=(-work "$1"); work="$1";;
	-*)		script_help;;
	*)		if [ ! -e "$(which $1)" ]; then
			  echo "ERROR: '$1' not found"; echo; exit; fi;
			commands+=($(quote "$(which $1)")); shift; break;;
      esac;
    fi;
    shift;
  done;
  if [ "${help}" == true ]; then script_help; fi;
  while [ "$1" != "" ]; do commands+=("$1"); shift; done;
  system=$(perl -e 'print(lc(@ARGV[0]));' ${system});
  if [ "${headnode}" == default ]; then headnode=$(hostname); fi;
  if [ ${#commands[@]} -eq 0 ]; then script_help; fi;
  if [ "${subscript}" == "" ]; then subscript="$(which ${script})"; fi;
  if [ "${queue}" == ${local} ]; then system=${local}; fi;
  if [ ${nppn} -lt 1 ]; then nppn=1; fi;
  if [ "${system}" == "" ]; then system=$(system_queue); fi;
  if [ "${system}" == "" ]; then
    error+=("Could not determine queueing system");
  elif [ "${system}" != "lsf" -a \
	 "${system}" != "pbs" -a \
	 "${system}" != "slurm" -a \
	 "${system}" != ${local} ]; then 
    error+=("Unknown queueing system '${system}'");
  fi;
  if [ "${scratch}" == "" ]; then scratch=none; fi;
  if [ "${scratch}" != none -a "${system}" != "pbs" ]; then
    error+=("Use of scratch not supported for system '${system}'");
  fi;
  if [ "${work}" == "" ]; then
    work="$(pwd)";
  fi;
  if [ "${nprocs}" == "" ]; then 
    error+=("Number of processors is not set; process is not submitted");
  fi;
  if [ ${#error[@]} == 0 ]; then return; fi;
  for message in "${error[@]}"; do
    echo "ERROR: ${message}";
  done;
  echo;
  exit;
}


# LSF submission

lsf_nodes() {
  perl -e '
    @arg = split(" ", (split("\n", `bmgroup`))[2]);
    shift(@arg);
    foreach (@arg) {
      $list{$_} = 1;
    }
    foreach (@ARGV) {
      foreach (split(" ")) {
	$list{$_} = 0;
      }
    }
    @arg = ();
    foreach (sort(keys %list)) {
      push(@arg, $_) if ($list{$_});
    }
    printf("%s\n", join(" ", @arg));
  ' $@;
}


lsf_run() {
  local options="-n ${nprocs}";
  local resource="";
  local command="-submit lsf $@";

  export nprocs;

  if [ "${starttime}" != "now" -a "${starttime}" != "" ]; then
    options="${options} -b $(set_time 2 ${starttime})"; fi;
  if [ "${walltime}" != "" ]; then
    options="${options} -W $(set_time 2 ${walltime})"; fi;
  if [ "${queue}" != "" -a "${queue}" != "default" ]; then
    options="${options} -q ${queue}"; fi;
  if [ "${account}" != "" -a "${account}" != "none" ]; then
    options="${options} -P ${account}"; fi
  if [ "${wait}" != "" ]; then
    options="${options} -w \"ended(${wait})\""; fi;
  if [ "${exclude}" != "" ]; then
    options="${options} -m \"$(lsf_nodes ${exclude})\"";
  elif [ "{$nodes" != "" ]; then
    options="${options} -R \"select[${nodes}]\"";
  fi;
  if [ "${resource}" != "" ]; then
    echo "bsub ${options}" "${user[@]}" \
      "-J \"${project}\" -oo \"${project}.o\" -eo \"${project}.e\"" \
      "-R \"${resource}\" ${subscript} ${command}";
    eval bsub ${options} ${user[@]} \
      -J "${project}" -oo "${project}.o" -eo "${project}.e" \
      -R "${resource}" ${subscript} ${command};
  else
    echo "bsub ${options}" "${user[@]}" \
      "-J \"${project}\" -oo \"${project}.o\" -eo \"${project}.e\"" \
      "${subscript} ${command}"
    eval bsub ${options} ${user[@]} \
      -J "${project}" -oo "${project}.o" -eo "${project}.e" \
      ${subscript} ${command};
  fi;
  sleep ${sleep};
}


# PBS submission

set_nodes() {
  perl -e '
    $n=$ARGV[0]; $=$ARGV[1];
    printf "%d\n", int(($n+($n%$ ? $nppn : 0))/$nppn);
  ' $@;
}


pbs_nodes() {
  local n=$1;
  local nnodes=$(set_nodes ${n} ${nppn});
  local mem;

  if [ "${nnodes}" == "1" ]; then
    if [ "${memory}" != "default" ]; then
      mem=":$(calc "${n}*${memory}")gb";
    fi;
    echo "${nnodes}:=${n}${mem}";
  else
    if [ "${memory}" != "default" ]; then
      mem=":$(calc "${nppn}*${memory}")gb";
    fi;
    echo "${nnodes}:=${nppn}";
  fi;
}


pbs_select() {
  local n=$1;
  local nnodes=$(calc "int(${n}/${nppn})");
  local nextra=$(calc "${n}-${nnodes}*${nppn}");
  local nmpi=$(calc "int(${nppn}/${nppt})");
  local nmpiextra=$(calc "int(${nextra}/${nppt})");
  local extra;
  local mem;

  if [ "${nextra}" != "0" ]; then
    extra="1:ncpus=${nextra}:mpiprocs=${nmpiextra}:ompthreads=${nppt}";
    if [ "${memory}" != "default" ]; then
      extra="${extra}:mem=$(calc ${nextra}*${memory})gb";
    fi;
  fi;
  if [ "${nnodes}" == "0" ]; then
    echo ${extra};
  else
    if [ "${extra}" != "" ]; then
      extra="+${extra}";
    fi;
    if [ "$memory" != "default" ]; then
      mem=":mem=$(calc "${nppn}*${memory}")gb";
    fi;
    echo "${nnodes}:ncpus=${nppn}:mpiprocs=${nmpi}:ompthreads=${nppt}${mem}${extra}";
  fi;
}


pbs_run() {
  local options="-N ${project}";
  local n=$(calc "int(${nprocs}/${nppt})");
  local command="-submit pbs $@";
  local settings;
  local select;
  local mem;

  if [ "${mode}" == "1" ]; then
    if [ "${memory}" != "default" ]; then
      mem=":$(calc $memory*$nppt)gb";
    fi;
    settings="select=${n}:ncpus=${nppt}${mem}";
  elif [ "${mode}" == "2" ]; then
    settings="nodes=$(pbs_nodes ${nprocs})";
  else
    settings="select=$(pbs_select ${nprocs})";
  fi;

  command="$(echo "${command}" | sed 's/"/\\"/g')";
  
  if [ "${starttime}" != "now" -a "${starttime}" != "" ]; then
    options="${options} -a $(set_time 3 ${starttime})"; fi;
  if [ "${walltime}" != "" ]; then
    settings="${settings},walltime=$(set_time 3 ${walltime})"; fi;
  if [ "${wait}" != "" ]; then
    options="${options} -W depend=afterany:$wait"; fi;
  if [ "${queue}" != "" -a "${queue}" != "default" ]; then
    options="${options} -q ${queue}"; fi;
  if [ "${account}" != "" -a "${account}" != "none" ]; then
    options="${options} -A ${account}"; fi;
  if [ "${queue_project}" != "" -a "${queue_project}" != "none" ]; then
    options="${options} -P ${queue_project}"; fi;
  if [ "${scratch}" != none -a ${sync} != true ]; then
    options="${options} -W stageout=\"*@${headnode}:${work}/\""; fi;
  echo "qsub ${options}" "${user[@]}" \
    "-l ${settings}" \
    "-v nprocs=${n},command=\"${command}\"" \
    "-e $(pwd)/${project}.e -o $(pwd)/${project}.o ${subscript}";
  eval qsub ${options} ${user[@]} \
    -l ${settings} \
    -v nprocs=${n},command="\"${command}\"" \
    -e $(pwd)/${project}.e -o $(pwd)/${project}.o ${subscript};
  sleep ${sleep};
}


# Slurm submission

slurm_run() {
  local options="--job-name ${project}";
  local command="-submit slurm $@";

  command="$(echo "${command}" | sed 's/"/\\"/g')";
  
  if [ "${starttime}" != "now" -a "${starttime}" != "" ]; then
    options="${options} --begin=$(set_time 3 ${starttime})"; fi;
  if [ "${walltime}" != "" ]; then
    options="--time=$(set_time 3 ${walltime})"; fi;
  if [ "${wait}" != "" ]; then
    options="${options} --dependency=afterany:$wait"; fi;
  if [ "${queue}" != "" -a "${queue}" != "default" ]; then
    options="${options} -p ${queue}"; fi;
  if [ "${account}" != "" -a "${account}" != "none" ]; then
    options="${options} --account=${account}"; fi;

  # note: add ALL to --export?

  echo "sbatch ${options}" "${user[@]}" \
    "-n ${nprocs}" \
    "--export=nprocs=${n},command=\"${command}\"" \
    "-e $(pwd)/${project}.e -o $(pwd)/${project}.o ${subscript}";
  eval sbatch ${options} ${user[@]} \
    -n ${nprocs} \
    --export=nprocs=${n},command="\"${command}\"" \
    -e $(pwd)/${project}.e -o $(pwd)/${project}.o ${subscript};
  sleep ${sleep};
}


# Execution once submitted

dir_expand()
{
  perl -e '
    foreach (split("/", @ARGV[0])) {
      if (substr($_,0,1) eq "\$" || substr($_,0,1) eq "@") {
	$b = substr($_,1);
	$b =~ s/^\{|\}$//g;
	push(@a, $ENV{$b});
      } else {
	push(@a, $_);
      }
    }
    print(join("/", @a), "\n");
  ' "$1";
}


sub_init() {
  local i;
  local files;

  file="";
  single=0;
  input="";
  output="";
  modules=();
  scratch="none";
  work="";

  while [ "$1" != "" ]; do
    case "$1" in
      -bind)		shift; bind="$1";;
      -file)		shift; file="$(nosingle "$1")";;
      -input)		shift; input="$1";;
      -join)		shift; join=$(flag $1);;
      -modules)		shift; modules+=($(split "," "$1"));;
      -n)		shift; nprocs=$1;;
      -output)		shift; output="$1";;
      -scratch)		shift; scratch="$1";;
      -scratch_cd)	shift; scratch_cd=$(int $1);;
      -sync)		shift; sync=$(flag "$1");;
      -single)		single=1;;
      -submit)		shift; system="$1";;
      -work)		shift; work="$1";;
      -*)		script_help;;
      *)		break;;
    esac;
    shift;
  done;

  if [ "${scratch}" == none ]; then
    sync=false;
  elif [ "${scratch}" != "" ]; then
    scratch="$(dir_expand "${scratch}")";
  fi;

  if [ "${system}" == "lsf" ]; then
    if [ "${LSB_SUBCWD}" != "" ]; then cd ${LSB_SUBCWD}; fi;
  elif [ "${system}" == "pbs" ]; then
    if [ "${PBS_O_PATH}" != "" ]; then export PATH=${PBS_O_PATH}; fi;
    if [ "${PBS_O_WORKDIR}" != "" ]; then cd ${PBS_O_WORKDIR}; fi;
  elif [ "${system}" == "slurm" ]; then
    if [ "${SLURM_SUBMIT_DIR}" != "" ]; then cd ${SLURM_SUBMIT_DIR}; fi;
  fi;

  if [ "${work}" == "" ]; then
    work="$(pwd)";
  fi;

  if [ "${file}" != "" ]; then
    set +f; files=(${file}); file=${files[0]};
    for i in "${files[@]}"; do [[ "${i}" -nt "${file}" ]] && file="${i}"; done; 
    set -f;
  fi;

  commands=();
  
  while [ "$1" != "" ]; do
    case "$1" in
      @FILE)	commands+=($(quote "${file}"));;
      *)	commands+=($(quote "$1"));;
    esac;
    shift;
  done;
}


sub_execute() {
  set_modules "${modules[@]}";

  if [ "${system}" != "${local}" ]; then
    echo "PATH=${PATH}";
    echo;
    echo "command=${commands[@]}";
    echo "workdir=$(pwd)";
    if [ "${file}" != "" ]; then echo "file=${file}"; fi;
    echo;
  fi;
  if [ "${file}" != "" -a ! -e "${file}" ]; then 
    echo -e "\nERROR: no file found with '${file}'\n"; return;
  fi;

  export OMPI_MCA_hwloc_base_binding_policy=none;
 
  if [ "${single}" != "1" ]; then
    if [ "${system}" == "pbs" ]; then
      if [ "${nprocs}" != "" ]; then
	if [ "${bind}" != "default" ]; then
	  commands=(--bind-to ${bind} ${commands[@]});
	fi;
	commands=(mpiexec -n ${nprocs} ${commands[@]});
      fi;
    elif [ "${system}" == "slurm" ]; then
      if [ "${nprocs}" != "" ]; then
	if [ "${bind}" != "default" ]; then
	  commands=(--bind-to ${bind} ${commands[@]});
	fi;
	commands=(mpiexec -n ${nprocs} ${commands[@]});
      fi;
    elif [ "${system}" == "lsf" ]; then
      if [ "${nprocs}" == "" ]; then
	if [ "${bind}" != "default" ]; then
	  commands=(--bind-to ${bind} ${commands[@]});
	fi;
	commands=(mpiexec ${commands[@]});
      else
	if [ "${bind}" != "default" ]; then
	  commands=(--bind-to ${bind} ${commands[@]});
	fi;
	commands=(mpiexec -n ${nprocs} ${commands[@]});
      fi;
    elif [ "${system}" == "${local}" ]; then
      if [ ${nprocs} -gt 1 ]; then
	if [ "${bind}" != "default" ]; then
	  commands=(--bind-to ${bind} ${commands[@]});
	fi;
	commands=(mpiexec -n ${nprocs} --use-hwthread-cpus ${commands[@]});
      fi;
    fi;
  fi;
  
  if [ "${input}" == "" ]; then
    if [ "${output}" == "" ]; then
      echo "${commands[@]}";
      ${commands[@]};
    else
      echo "${commands[@]} >& ${output}";
      ${commands[@]} >& ${output};
    fi;
  else
    if [ "${output}" == "" ]; then
      echo "${commands[@]} < ${input}";
      ${commands[@]} < ${input};
    else
      echo "${commands[@]} < ${input} >& ${output}";
      ${commands[@]} < ${input} >& ${output};
    fi;
  fi;
}


# General

execute() {
  local home="$(pwd)";

  echo -e "### ${script} v${version} started at $(date) ###\n";
  
  if [ "$1" == "-submit" ]; then
    sub_init "$@";
    if [ "${scratch}" != none ]; then
      scratch="$(dir_expand "${scratch}")";
      if [ ! -e "${scratch}" ]; then run mkdir -p "${scratch}"; fi;
      if [ "${scratch_cd}" == true ]; then run cd "${scratch}"; fi;
      sub_execute;
      if [ "${sync}" == true ]; then
	run rsync -avz "${scratch}/*" "${work}";
	run rm -rf "${scratch}/*";
	run rm -rf "${scratch}";
      fi;
      if [ "${scratch_cd}" == true ]; then run cd "${home}"; fi;
    else
      sub_execute;
    fi;
  else
    run_init "$@";
    if [ "${system}" == "lsf" ]; then
      lsf_run ${commands[@]};
    elif [ "${system}" == "pbs" ]; then
      pbs_run ${commands[@]};
    elif [ "${system}" == "slurm" ]; then
      slurm_run ${commands[@]};
    elif [ "${system}" == "${local}" ]; then 
      sub_init "${commands[@]}";
      sub_execute;
    fi;
  fi;
  
  echo -e "\n### ${script} v${version} ended at $(date) ###";
}


# Main
  
  set -f;
  if [ "$1" == "" ]; then
    execute ${command};
  else
    execute "$@";
  fi;

