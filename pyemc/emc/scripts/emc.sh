#!/bin/bash
#
#  script:	emc.sh
#  author:	Pieter J. in 't Veld
#  date:	February 19, November 3, 2018
#  purpose:	Wrapper around EMC for starting correct executable
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20180218	Creation date
#    20181103	Addition of version flag
#

# variables

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
		    HOST="linux64" else HOST="linux";
		  fi;;
	msys*)    HOST="win32";;
	*)        echo "ERROR: unsupported OS '${OSTYPE}'"; exit -1;;
      esac;
    fi;
  fi;
}


# main

  init "$@";
  emc_${HOST} "$@";

