#!/bin/bash
#
#  script:	convert.sh
#  author:	Pieter J. in 't Veld
#  date:	November 15-30, December 1-19, 2024.
#  purpose:	OPLS-AA and OPLS-UA parameter conversion into EMC readable
#  		force field files
#
#  notes:
#    20250106	- Start in directory where src resides
#

run() {
  echo "$@";
  $@;
}


convert() {
  dir=$(dirname $0);
  run $dir/emc_opls.pl -source=src $@
}


# main

  convert -united -wildcards=c4 opls-ua
  convert opls-aa

