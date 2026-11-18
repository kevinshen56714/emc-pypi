#!/bin/bash

  emc.pl -field=opls-aa -ntotal=1000 -charge -msd ethanol
#  emc_${HOST} build.emc 2>&1 | tee build.out
#  lmp_${HOST} -var source . -var params . -var trun 1000 -var dtthermo 10 -var nsample 10 <acid.in 2>&1 | tee acid.out
