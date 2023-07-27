#!/bin/bash
#
#  script:	emc.sh
#  author:	Pieter J. in 't Veld
#  date:	February 19, November 3, 2018, July 24, 2023.
#  purpose:	Wrapper around EMC for starting correct executable
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20180218	Creation date
#    20181103	Addition of version flag
#    20230724	Addition of aarch64 and source checking
#

# variables

emc_root=$(d=$(pwd); cd $(dirname $0)/..; r=$(pwd); cd "$d"; echo "$r");
emc_version=9.4.4;


# functions

function init() {
  local dir;
  local host;

  if [ "$HOST" = "" ]; then
    dir=$(dirname "$0");
    host=$(/bin/hostname 2>&1 || sed -e 's/\..*$//');
    if [ -e "${dir}/emc_${host}" ]; then
      HOST=${host};
    else
      case "${OSTYPE}" in
	darwin*)  HOST="macos";; 
	linux*)   if [ "$(uname -m)" = "x86_64" ]; then 
		    HOST="linux_x86_64";
		  elif [ "$(uname -m)" = "aarch64" ]; then
		    HOST="linux_aarch64";
		  else
		    HOST="linux";
		  fi;;
	msys*)    HOST="win32";;
	*)        echo "ERROR: unsupported OS '${OSTYPE}'"; exit -1;;
      esac;
    fi;
  fi;
}


# main

  init "$@";
  if [ -e "$(which emc_${HOST})" ]; then
    emc_${HOST} "$@";
  elif [ -e "${EMC_ROOT}/bin/emc_${HOST}" ]; then
    "${EMC_ROOT}/bin/emc_${HOST}" "$@";
  elif [ -e "${emc_root}/bin/emc_${HOST}" ]; then
    "${emc_root}/bin/emc_${HOST}" "$@";
  else
    echo "ERROR: cannot find EMC executable";
    echo "ERROR:"
    echo "ERROR: set HOST and/or add EMC bin and scripts directories to your PATH";
    echo "ERROR: alternatively set EMC_ROOT";
    echo "ERROR: EMC_ROOT=\"${EMC_ROOT}\"";
    echo "ERROR: HOST=\"${HOST}\"";
  fi;


