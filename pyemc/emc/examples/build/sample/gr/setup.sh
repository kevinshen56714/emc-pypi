#!/bin/bash

  emc.pl -ntotal=1000 -field=oplsua ethane;
  emc_${HOST} build.emc 2>&1 | tee build.out

