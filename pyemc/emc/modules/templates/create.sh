#!/bin/bash
#
#  script:	create.sh
#  author:	Pieter J. in 't Veld
#  date:	June 6, 2020.
#  purpose:	Create EMC modules using predefined templates
#
#  Copyright (c) 2004-2020 Pieter J. in 't Veld
#  Distributed under GNU Public License v3 as stated in LICENSE file in EMC
#  root directory
#

last() {
  perl -e 'print(@ARGV[-1]);' $@;
}

# main

  if [ "$2" == "" ]; then
    echo "usage: create.sh template target[/...]";
    echo "templates: " $(find * -type d);
    echo;
    exit;
  fi;

  arg=$(perl -e 'print(join(" ", @ARGV[0], split("/", @ARGV[1])));' $@);
  template=$(perl -e 'print(@ARGV[0]);' ${arg[0]});
  target=$(perl -e 'shift(@ARGV); print(join("/", @ARGV));' ${arg[@]});
  name=$(perl -e 'shift(@ARGV); print(join("_", @ARGV));' ${arg[@]});
  
  if [ -e core/${target}.h -o -e core/${target}.c ]; then
    echo "${target} exists.";
    exit;
  fi;
  
  echo "module.pl ${template}/template ${name}";
  ./module.pl ${template}/template ${name};
  replace.pl -q "\"${name}.h\"" "\"$(last ${arg[@]}).h\"" ${name}.c
  mv ${name}.c core/${target}.c;
  mv ${name}.h core/${target}.h;
