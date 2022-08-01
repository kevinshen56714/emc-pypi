#!/bin/bash
#
#  script:	prm_extract.sh
#  author:	Pieter J. in 't Veld
#  date:	April 2, August 2, 2021
#  purpose:	Extract and reduce DPD parameters using an EMC Setup project
#
#  notes:
#    20210402	Creation date
#    20210802	Expanded application area include 'includes' and 'structures'
#

# settings

version=0.2;
date="August 2, 2021";
script=$(basename "$0");

# functions

error() {
  echo $@;
  echo;
  exit -1;
}

expand() {
  local home="$(pwd - L)";
  cd "$1";
  pwd -L;
  cd "$home";
}

psf_types() {
  perl -e '
    foreach (<>) {
      @a = split(" ");
      if (!$read) {
	next if (@a[1] ne "!NATOM");
	$n = @a[0]; next;
      }
      next if (!$n);
      ++$t{@a[5]};
      --$n;
    }
    print(join(" ", sort(keys(%t))), "\n");;
  ' $@;
}

list_unique() {
  perl -e '
    foreach (@ARGV) { $a{$_} = 1; }; print(join(" ", sort(keys(%a))), "\n");
  ' $@;
}

# main

{
  if [ "$2" == "" ]; then
    error "usage: extract.sh chemistry_dir field_dir";
  fi;

  field="$(expand "$2")";
  chemistry="$(expand "$1")";

  #echo "field = $field";
  #echo "chemistry = $chemistry";

  if [ ! -d "$field" ]; then
    error "'$field' is not a directory";
  fi;
  if [ ! -d "$chemistry" ]; then
    error "'$chemistry' is not a directory";
  fi;

  cd "$chemistry";
  tmp=$(mktemp);
  if [ -d stages ]; then
    stages=($(find stages -name '*.esh' -type f));
    if [ "${#stages[@]}" == "0" ]; then
      error "no EMC scripts in chemistry directory";
    fi;
    #echo "stages = ${stages[@]}";
    cat "${stages[@]}" >$tmp;
  else
    error "directory 'stages' is missing in chemistry directory";
  fi;
  if [ -d groups ]; then
    groups=($(find groups -name '*.dat' -type f));
    if [ "${#groups[@]}" != "0" ]; then
      #echo "groups = ${groups[@]}";
      data=$(cat "${groups[@]}");
      replace.pl -q "@GROUPS" "$data" $tmp;
    fi;
  fi;
  if [ -d include ]; then
    include=($(find include -name '*' -type f));
    if [ "${#include[@]}" != "0" ]; then
      cat "${include[@]}" >>$tmp;
    fi
  fi;
  
  types=($(prm_list_types.pl -list $tmp));
  rm $tmp;
  
  if [ -d structures ]; then
    psf=($(find structures -name '*.psf' -type f));
    if [ "${#psf[@]}" != "0" ]; then
      types=(${types[@]} $(psf_types ${psf[@]}));
    fi;
    psf=($(find structures -name '*.psf.gz' -type f));
    if [ "${#psf[@]}" != "0" ]; then
      for file in ${psf[@]}; do 
	types=(${types[@]} $(gunzip -c $file | psf_types));
      done;
    fi;
  fi;

  mkdir -p field;
  types=($(list_unique ${types[@]}));
  prm_reduce.pl -source_dir="$field" -target_dir="field" "${types[@]}"
}

