#!/bin/bash
#
#  File:	hold.sh
#  Author:	Pieter J. in 't Veld
#  Date:	May 15, 2004
#  Purpose:	Swap files between active and hold directories; part of EMC
#		distribution
#
#  Copyright (c) 2004-2019 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#

function hold()
{
  local dir=$(perl -e '@arg=split("core", "'$(pwd)'"); print("$arg[-1]\n");');
  local home=$(perl -e '@arg=split("core", "'$(pwd)'"); print("$arg[0]\n");');
 
  if [ "$dir" == "$home" ]; then dir=""; fi;
  mkdir -p "$home/hold/$dir";
  for file in $@; do
    if [ ! -e "$file" ]; then continue; fi;
    if [ -e "$home/hold/$dir/$file" ]; then
      mv "$file" "$file.tmp";
      mv "$home/hold/$dir/$file" .;
      mv "$file.tmp" "$home/hold/$dir/$file";
    else
      cp "$file" "$home/hold/$dir/$file";
    fi;
  done;
}

# main

  hold $@;

