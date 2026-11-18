#!/bin/bash

  emc.pl -ntotal=1000 -field=trappe example;
  emc_${HOST} build.emc 2>&1 | tee build.out

