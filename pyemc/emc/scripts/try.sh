#!/bin/bash
#
#  File:	try.sh
#  Author:	Pieter J. in 't Veld
#  Date:	May 15, 2004
#  Purpose:	Try compilation of single modules; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#

function try () {
  local command="-g -O3 -Wall";
  local last="";
  local dir="";
  while [ ! "$1" = "" ]; do
    if [ ! "$last" = "" ]; then command="$command $last"; fi;
    last=$1; shift;
  done;
  if [ "$last" = "" ]; then
    echo "usage: try [options] file[.c|.cpp]"; return;
  fi;
  dir=$(dirname "$last");
  if [ "$dir" = "." ]; then dir=""; else dir="$dir/"; fi;
  last=$dir$(basename "$last" .cpp);
  dir=$(dirname "$last");
  if [ "$dir" = "." ]; then dir=""; else dir="$dir/"; fi;
  last=$dir$(basename "$last" .c);
  if [ -e "$last".cpp ]; then
    echo g++ $command -c -o "$last.o" "$last.cpp";
    g++ $command -c -o "$last.o" "$last.cpp";
  else
    echo gcc $command -c -o "$last.o" "$last.c";
    gcc $command -c -o "$last.o" "$last.c";
  fi;
  rm -f "$last.o";
}

# main 

  try $@;

