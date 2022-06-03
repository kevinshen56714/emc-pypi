#!/bin/bash
#
#  script:	prm_reduce.sh
#  author:	Pieter J. in 't Veld
#  date:	April 9, 2019
#  purpose:	Reduce DPD parameters using EMC Setup script
#
#  notes:
#    20190409	Creation date
#

# settings

version=1.0;
date="April 9, 2019";
script=$(basename "$0");

# main

{
  if [ "$2" = "" ]; then
    echo "usage: prm_reduce.sh field_dir setup";
    echo;
    exit;
  fi;

  field="$1";
  setup="$2";
  if [ ! -d "$field" ]; then
    echo "ERROR: '$field' is not a directory";
    echo;
    exit;
  fi;
  if [ ! -e "$setup" ]; then
    echo "ERROR: '$setup' not found";
    echo;
    exit;
  fi;

  prm_reduce.pl -source_dir="$field" $(prm_list_types.pl -list "$setup");
} 
