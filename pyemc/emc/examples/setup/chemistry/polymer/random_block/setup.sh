#!/bin/bash

  emc_setup.pl

  emc_${HOST} build.emc 2>&1 | tee build.out

