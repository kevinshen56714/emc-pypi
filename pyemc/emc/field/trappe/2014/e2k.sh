#!/bin/bash

# functions

calc () {
  perl -e 'printf "%5.3f\n",'$1';'
}


convert() {
  for i in $@; do
    echo -en $(calc "$i") "\t->\t" $(calc "$i/0.00198720425864083") "\n";
  done;
}


# main

{
  if [ "$1" == "" ]; then
    echo "usage: e2k.sh energy [...]";
    echo "converts energy from kcal/mol to K";
    exit;
  fi;

  convert $@;
}

