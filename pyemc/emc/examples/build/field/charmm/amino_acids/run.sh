#!/bin/bash
#
#    script:	run.sh
#    author:	Pieter J. in 't Veld
#    date:	October 13, 2013.
#    purpose:	Check correctness of CHARMM force field definition
#

# functions

  run() {
    echo "$@"; $@; }
  array() {
    perl -e '$t = $ARGV[0]; $t =~ s/,/ /g; print($t);' $@; }
  lc() {
    perl -e 'print(lc($ARGV[0]));' $@; }
  substr() {
    perl -e 'print(substr($ARGV[0],$ARGV[1],$ARGV[2]));' $@; }
  split() {
    perl -e '@arg = split("\\.", $ARGV[0]); print(join(" ", @arg));' $@; }
  first() {
    echo $1; }

  submit() {
    local home=$(pwd);
    local chemistry;
    local error;
    local data;
    local n=0;

    echo "# start at $(date)";
    echo;
    while read line; do
      data=($(array $line));
      data[0]=$(lc ${data[0]});
      data[1]=$(lc ${data[1]});
      chemistry=($(split ${data[3]}));
      if [ "$(substr "${data[0]}" 0 1)" = "#" ]; then
	continue;
      fi;
      let "n++";
      echo "# ${data[0]}";
      if [ -e ${data[0]}/${data[0]}.emc ]; then
	echo; continue;
      fi;
      mkdir -p ${data[0]};
      cd ${data[0]};
      if [ "${chemistry[1]}" = "" ]; then
	run \
	  emc_${HOST} \
	    -chemistry=\"${chemistry[0]}\" \
	    -output=${data[0]} \
	    ../build >& build.out;
      else
	run \
	  emc_${HOST} \
	    -chemistry=\"${chemistry[0]}\" \
	    -chemistry_ion=\"${chemistry[1]}\" \
	    -nion=1 \
	    -output=${data[0]} \
	    ../build >& build.out;
      fi;
      error=$(grep Error build.out);
      if [ "$error" != "" ]; then echo "# $error"; fi;
      cd $home;
      echo;
    done <amino_acids.csv;
    grep -n Error */build.out >& error.out;
    echo "# nerrors = $(first $(wc -l error.out)) of $n amino acids"
    echo;
    echo "# end at $(date)";
    echo;
  }

# main

  submit 2>&1 | tee run.out;

