#!/usr/bin/env perl
#
#  program:	emc_comments.pl
#  author:	Pieter J. in 't Veld
#  date:	May 14, 2020.
#  purpose:	Generate comment and function list of perl script source	
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20200514	Inception
#

# main

{
  foreach (<>) {
    ++$line;
    $flag = 0;
    $flag = 1 if (substr($_,0,2) eq "# ");
    $flag = 2 if (substr($_,0,4) eq "sub ");
    $flag = 0 if (substr($_,0,3) eq "#  ");
    $flag = 0 if ($_ =~ m/:/);
    next if (!$flag);
    $_ = "  - ".(split(" "))[1]."\n" if ($flag == 2);
    print($_);
  }
}
