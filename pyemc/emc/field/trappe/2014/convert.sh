#!/bin/bash

  root=$EMC_ROOT;

  $root/scripts/emc_trappe.pl trappe-ua
  $root/scripts/emc.sh convert

