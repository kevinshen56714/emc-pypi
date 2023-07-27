#!/bin/bash
#
#  name:	run_host.sh
#  author:	Pieter J. in 't Veld
#  date:	February 21, 2012, March 14, November 2, 2016,
#		January 18, July 5, August 1, 2017, January 9,
#		February 7, 2018, March 23, 2022.
#  purpose:	start jobs remotely or collect data; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20120221	Creation date
#    20180109	Separated run_host.sh commands from executed script commands
#    20180210	Added retrieval and unpacking of archived data from host;
#		needed after analysis executed on queueing system
#    20181028	Added -[no]back options for capturing submission logs
#    20220323	Added -keep option for keeping exchange data files
#

# initial variables

version=1.5.2;
date="March 23, 2022";
script=$(basename $0);

# functions

function strip() {
  local dir=$(echo $1 | awk '{split($0,a,"'$HOME/'"); print a[2]}');

  if [ "$dir" = "" ]; then dir=$1; fi;
  if [ "$dir" = "$HOME" ]; then dir=""; fi;
  echo "$dir";
}

function split() {
  echo $1 | awk '{split($0,a,"'$2'"); print a['$3']}';
}

function location() {
  #local home=$(pwd -P);
  local home=$(pwd);
  cd $(dirname $1);
  #pwd -P;
  pwd;
  cd $home;
}

function nodouble() {
  local v="$1";

  while [[ "${v#\"}" != "$v" && \
	"${v%\"}" != "$v" ]]; do v="${v#\"}"; v="${v%\"}"; done;
  echo "$v";
}

function quote() {
  local v="$(nodouble "$1")";

  if [[ "$v" =~ ' ' ]]; then echo "\"$v\"";
  else echo "$v"; fi;
}

function error() {
  echo -e "Error: $@\n";
  exit;
}

function info() {
  if [ "$info" != true ]; then return; fi;
  if [ "$1" != "" ]; then echo -e "Info: $@";
  else echo; fi;
}

function header() {
  if [ "$info" != "true" ]; then return; fi;
  echo "$script v$version, $date.";
  echo "";
}
  
function help() {
  info=true;
  header;
  echo "Usage:";
  echo "  $script [-option [value]] [user@]host[:dir] exec [...]";
  echo "";
  echo "Options:"
  echo -e "  -help\t\tthis message";
  echo -e "  -[no]back\tcontrol background submission of script on host";
  echo -e "  -clear\tclear staged exchange data on host";
  echo -e "  -data\t\tdownload and unpack data.tgz upon completion";
  echo -e "  -debug\tproduce debug output";
  echo -e "  -exchange\tretrieve and unpack archived data from host";
  echo -e "  -[no]info\tcontrol informational output";
  echo -e "  -keep\t\tkeep exchange data files";
  echo -e "  -quiet\tswitch off any output";
  echo -e "  -sync\t\tset directory to synchronize";
  echo;
  echo "Notes:";
  echo "  * The -exchange option will create a local ./exchange/data directory";
  echo;
  if [ "$1" != "" ]; then error $@; fi;
  exit;
}

function init() {
  local left="";
  local right="";

  set -e;
  set -o pipefail;
  
  dir="";
  src="";
  host="";
  sync="";
  back=false;
  data=false;
  debug=false;
  exchange=false;
  info=true;
  keep=false;
  log=true;
  while [ "$1" != "" ]; do
    case "$1" in
      -help)	help;;
      -back)	back=true;;
      -clear)	clear=true;;
      -noback)	back=false;;
      -data)	data=true;;
      -debug)	debug=true;;
      -exchange) exchange=true;;
      -info)	info=true;;
      -keep)	keep=true;;
      -noinfo)	info=false;;
      -quiet)	info=false; debug=false; log=false;;
      -sync)	shift; sync=$1;;
      -*)	help "unknown command: $1";;
      *)	host=$1; shift; break;;
    esac;
    shift;
  done;

  while [ "$1" != "" ]; do commands+=("$1"); shift; done;
  if [ ${#commands[@]} -eq 0 ]; then 
    if [ "${exchange}" != "true" -a "${clear}" != "true" ]; then help; fi;
    commands+=(".");
  fi;
  src="${commands[0]}";
  if [ ! -e $src ]; then error "$src not found"; fi;
  if [ "${host}" == "" ]; then error "target host not set"; fi;

  root=$(strip $(location .));
  left=$(split $host : 1);
  right=$(split $host : 2);
  if [ "$right" != "" ]; then
    host=$left;
    dir=$right;
    dest=$(basename $src);
    target="$dir/$(dirname $src)";
  else
    dest=$src;
    dir=$root;
    target=$(strip $(location $src));
  fi;
  commands[0]="$dest";
  if [ "$dest" == "." ]; then
    mkdir -p exchange/log;
    output=$(mktemp exchange/log/$(date +%Y%m%d.%H%M%S).XXXXXXXX);
  else
    output=$(split $dest . 1).log;
  fi;

  header;
  info "src=$src";
  info "host=$host";
  info "dir=$dir";
  info "root=$root";
  info "target=$target";
  info "dest=$dest";
  info "output=$output";
  info;

  dest="";
  for i in "${commands[@]}"; do
    if [ "$dest" == "" ]; then dest=$(quote "$i");
    else dest="$dest $(quote "$i")"; fi;
  done;
}


function myrsync() {
  rsync --progress "$@";
}


# main

  . ~/.bash/functions.sh;
  init "$@";
 
  if [ "$clear" == "true" ]; then

    echo ssh $host "rm -f \"$dir/exchange/files/\"* \"$dir/exchange/data/\"*.tgz" | tee -a $output;
    if [ "$keep" == "false" ]; then
      ssh $host "rm -f \"$dir/exchange/files/\"* \"$dir/exchange/data/\"*.tgz" | tee -a $output;
    fi;
    echo | tee -a $output;

  else

    if [ "$exchange" != "true" ]; then
      info "ssh $host \"mkdir -p $target\"";
      info;
      ssh $host "mkdir -p \"$target\"";

      info "rsync -avz \"$src\" \"$host:$target\"";
      info;
      myrsync -avz "$src" "$host:$target";
      
      if [ "$sync" != "" ]; then
	info "rsync -avz \"$sync\" \"$host:$dir\"";
	info;
	myrsync -avz "$sync" "$host:$dir";
      fi;
      
      info;

      if [ "${back}" != "true" ]; then
	info "ssh $host \"cd $dir; $dest\"";
	ssh $host "cd $dir; $dest" 2>&1 | tee $output;
      else
	info "ssh $host \"cd $dir; nohup $dest &>/dev/null &\"";
	ssh $host "cd $dir; nohup $dest &>/dev/null &";
      fi;
      info;
    else
      ssh $host "
	cd $dir; a=(exchange/files/*); 
	if [ -e \${a[0]} ]; then
	  for f in \${a[@]}; do
	    tar -zvcf exchange/data/\$(basename \$f).tgz -T \$f;
	    rm -f \$f;
	    echo;
	  done;
	fi;
      " 2>&1 | tee -a $output;
      data=true;
    fi

    if [ "$data" = "true" ]; then
      mkdir -p exchange/data;
      echo "rsync -avz \"$host:$dir/exchange/data/*.tgz\" exchange/data/" | tee -a $output;
      myrsync -avz "$host:$dir/exchange/data/*.tgz" exchange/data/;
      echo | tee -a $output;
      if [ "$keep" == "false" ]; then 
	echo "ssh $host \"rm $dir/exchange/data/*.tgz\"" | tee -a $output;
	ssh $host "rm \"$dir/exchange/data/\"*.tgz" | tee -a $output;
      fi;
      echo | tee -a $output;
      for file in exchange/data/*.tgz; do
	echo "tar -zxvf ${file}" | tee -a $output;
	tar -zxvf ${file} 2>&1 | tee -a $output;
      done;
      echo | tee -a $output;
      if [ "$keep" == "false" ]; then
	rm exchange/data/*.tgz;
      fi;
    fi;
  fi;

