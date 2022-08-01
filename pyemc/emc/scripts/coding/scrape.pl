#!/usr/bin/env perl
#
#  program:	header.pl
#  author:	Pieter J. in 't Veld
#  date:	May 18, 2019.
#  purpose:	Create continuous list of file names and line number as 
#  		produced by grep
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#

# main

{
  foreach(<>) { 
    push(@a, join(":",(split(":"))[0,1])); 
  } 
  print(join(" ", sort(@a)));
}

