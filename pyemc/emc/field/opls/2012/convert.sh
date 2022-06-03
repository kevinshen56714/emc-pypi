#!/bin/bash

  emc_opls.pl -source=src/oplsaa opls-aa $@
  emc_opls.pl -source=src/oplsaa opls-ua $@

