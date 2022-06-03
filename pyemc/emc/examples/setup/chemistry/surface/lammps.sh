#!/bin/bash

  mpiexec -n 2 \
    lmp_${HOST} \
    -var dtthermo 10 -var trun 0 -var dtdump 1 \
    -in surface.in 2>&1 | tee surface.out

