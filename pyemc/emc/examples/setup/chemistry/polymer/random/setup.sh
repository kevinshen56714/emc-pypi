#!/bin/bash

  emc.pl

  emc_${HOST} build.emc 2>&1 | tee build.out

