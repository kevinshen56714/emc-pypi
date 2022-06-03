#!/bin/bash

  if [ "$1" = "" ]; then
    echo "usage: $0 root"; exit; 
  fi

  if [ ! -e $(ls $1_*.pdb | head -1) ]; then
    echo "no files found"; echo; exit;
  fi;

  last=$(basename $(ls -r $1_*.pdb | head -1) .pdb);
  
  cat $1_*.pdb >$1.pdb
  cp $last.psf $1.psf;

  rm $1.pdb.gz $1.psf.gz;
  gzip $1.pdb $1.psf;

  echo "#!/usr/bin/env vmd -e

# variables

set project \"$1\"

# load structure

if { [file exists \$project.psf.gz] == 1} {
  exec gunzip \$project.psf.gz
}
if { [file exists \$project.pdb.gz] == 1} {
  exec gunzip \$project.pdb.gz

}
mol new \$project.psf waitfor all
mol addfile \$project.pdb waitfor all

exec gzip \$project.psf
exec gzip \$project.pdb

# set representation

mol delrep 0 top
mol representation Licorice 0.3
mol selection {not {x = 0 and y = 0 and z = 0}}
mol addrep top
mol selupdate 0 top 1
mol colupdate 0 top 0
mol scaleminmax top 0 0.000000 0.000000
mol smoothrep top 0 0
mol showrep top 0 1

mol representation PaperChain 1.000000 10.000000
mol color Name
mol selection {not {x = 0 and y = 0 and z = 0}}
mol material EdgyGlass
mol addrep top
mol selupdate 1 top 1
mol colupdate 1 top 0
mol scaleminmax top 1 0.000000 0.000000
mol smoothrep top 1 0

# reset view

display resetview

# set periodic box

pbc box
" > $1.vmd;

  chmod +x $1.vmd;

  rm -f $1_*.pdb
  rm -f $1_*.psf
  rm -f $1_*.vmd

