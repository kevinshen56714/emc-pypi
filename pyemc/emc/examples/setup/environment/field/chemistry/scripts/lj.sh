#!/bin/bash
#
#  script:	scripts/lj.sh
#  author:	emc_setup.pl v3.9.2, November 19, 2019
#  date:	Thu Dec  5 09:59:07 CET 2019
#  purpose:	Create chemistry file based on sample definitions; this
#  		script is auto-generated
#

# functions

init() {
  while [ "$1" != "" ]; do
    case "$1" in
      -project) shift; project="$1";;
      -trial) shift; trial="$1";;
      -phase) shift; stage="$1";;
      -stage) shift; stage="$1";;
      -nbranches) shift; nbranches="$1";;
      -*) shift;;
      *) if [ "$chemistry" = "" ]; then chemistry="$home/$1.esh"; fi;;
    esac;
    shift;
  done;

  if [ "$chemistry" = "" ]; then chemistry="$home/chemistry.esh"; fi;
  if [ "$trial" = "" ]; then trial="generic"; fi;
  if [ "$stage" = "" ]; then stage="generic"; fi;
  
  template=stages/$project/$stage.esh;
  if [ ! -e "$template" ]; then error "nonexistent template '$template'"; fi;
}

error() {
  echo "Error: $@";
  echo;
  exit -1;
}

# create chemistry file

create() {
  cp "$template" "$chemistry";

  replace "@GROUPS" "groups/$stage" "$trial";
  replace "@CLUSTERS" "clusters/$stage" "$trial";
  replace "@POLYMERS" "polymers/$stage" "$trial";
  replace "@SHORTHAND" "shorthand/$stage" "$trial";
  replace "@STRUCTURE" "structures/$stage" "$trial";
  
  replace "@WORKDIR" "${HOME}/emc/v9.4.4/examples/setup/environment/field";
  replace "@STAGE" "$stage";
  replace "@TRIAL" "$trial";
  replace "@NBRANCHES" "$nbranches";

  chmod a+rx "$chemistry";
}

replace() {
  if [ "$3" = "" ]; then
    if [ "$2" != "" ]; then
      replace.pl -v -q "$1" "$2" "$chemistry";
    fi;
  elif [ -f "$2/$3.dat" ]; then 
    replace.pl -v -q "$1" "$(cat $2/$3.dat)" "$chemistry";
  fi;
}

# main

  home=$(pwd);
  project="lj";
  cd $(dirname $0)/..;
  init $@;
  create;
