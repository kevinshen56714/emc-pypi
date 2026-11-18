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
  echo "# load structure

mol new $1.psf waitfor all
mol addfile $1.pdb waitfor all

# set representation

mol delrep 0 top
mol representation Licorice 0.3
mol addrep top
mol showrep top 0 1
#mol representation VDW 1 20
#mol addrep top
#mol showrep top 1 0

# set periodic box

pbc box
" > $1.vmd

