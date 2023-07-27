#!/bin/bash
#
#  name:	run_host.sh
#  author:	Pieter J. in 't Veld
#  date:	February 20, March 4, 2017.
#  purpose:	start analysis script remotely and transfer data back; part of
#		EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#


  if [ "$2" == "" ]; then
    echo "usage: run_analyze.sh [user@]host script [...]";
    echo;
    exit;
  fi;

  . ~/.bashrc;

  host=$1; shift;
  for file in $@; do
    run_host.sh $host $file;
    scp -p $host:$(here)/data.tgz .;
    tar -zxvf data.tgz;
  done;

