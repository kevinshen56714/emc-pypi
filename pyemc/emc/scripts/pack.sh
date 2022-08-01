#!/usr/bin/env bash

  if [ "$2" == "" ]; then
    echo "usage: "$(basename $0)" dir ext";
    echo;
    exit;
  fi;

  dir="$1"; shift;
  ext="$1"; shift;

  for file in $(find "$dir" -name "*$ext" | sort); do
    echo $file;
    gzip $file;
  done;

