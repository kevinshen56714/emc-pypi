#!/bin/bash

  src=.;
  home=$(pwd);
  if [ -d src ]; then src=src; fi;
  cd $src;
  files=($(find * -name '*.itp' -and -not -name martini.itp -exec sh -c 'echo "$(basename {} .itp)"' \;));
  cd $home;

  for file in ${files[@]}; do 
    emc_martini.pl -ffapply=GROUPS -source=$src -output=$file $file;
  done;
  emc_martini.pl -ffapply=ALL -source=$src -output=martini ${files[@]};

