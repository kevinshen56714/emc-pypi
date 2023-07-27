#!/usr/bin/env perl
#
#  program:	prm_duplicate.pl
#  author:	Pieter J. in 't Veld
#  date:	May 2, 2012.
#  purpose:	duplicate exisiting parameters; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#

  if (scalar(@ARGV)<3) {
    print("usage: duplicate_parm.pl source target parm.csv\n\n");
    exit;
  }
  $source = shift(@ARGV);
  $target = shift(@ARGV);
  foreach (<>) {
    chop();
    if ($header eq "") {
      $header = $_; next;
    }
    push(@data, $_);
    my $flag = 0;
    my @arg = split(",");
    if ($arg[0] eq $source) {
      $flag = 1;
      $arg[0] = $target;
    }
    if ($arg[1] eq $source) {
      $flag = 1;
      $arg[1] = $target;
    }
    if ($arg[1]<$arg[0]) {
      my $t = $arg[0]; $arg[0] = $arg[1]; $arg[1] = $t;
    }
    push(@data,join(",", @arg)) if ($flag);
  }
  sort(@data);
  print("$header\n");
  foreach(@data) {
    print("$_\n");
  }

