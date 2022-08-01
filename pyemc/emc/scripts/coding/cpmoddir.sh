#!/bin/bash
#
#  file:	cpmoddir.sh
#  author:	Pieter J. in 't Veld
#  date:	March 10, 2006, April 14, 2007, September 30, 2010.
#  purpose:	copy module directories; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#

# globals

  script=$(basename $0);
  version=0.1beta;

# functions

help() {
  echo "usage: $script source_dir destination_dir";
  echo;
  exit;
}

info() {
  echo "info: $@";
}

error() {
  echo "error: $@";
  echo;
  exit;
}

# main

  echo "### $script $version";
  echo;

  if [ "$2" = "" ]; then help; fi ;
  if [ ! -d $1 ]; then error "$1 is not a directory."; fi;
  if [ ! -e $2 ]; then info "creating $2"; mkdir -p $2;
  elif [ ! -d $2 ]; then error "$2 is not a directory."; fi;

  src=$1; dest=$2; flag=false;

  for i in $src/*.c; do
    file=$(basename $i .c);
    if [ ! -e $dest/$file.c ]; then
      info "copying $src/$file to $dest/$file";
      cpmod.pl $src/$file $dest/$file;
      flag=true;
    fi;
  done;
  cd $dest;
  if [ ! -e core ]; then 
    info "linking $dest/core to ../core";
    ln -s ../core;
    flag=true;
  fi;

  if [ $flag = false ]; then info "nothing to be done"; fi;

  echo;

