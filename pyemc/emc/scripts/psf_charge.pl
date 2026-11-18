#!/usr/bin/env perl
#
#  script:	psf_charge.pl
#  author:	Pieter J. in 't Veld
#  date:	August 30, 2018
#  purpose:	Determine charge of PSF file
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  Notes:
#    20180830	- Inception
#    		- v1.0
#    20251001	- GZIP addition
#    		- v1.1
#

use File::Basename;

use lib dirname($0)."/modules";
use EMC::Message;
use EMC::IO;

$Script = basename($0);
$Version = "1.1";
$Year = "2025";


# functions

sub set_commands {
%Commands = (
  "help"	=> "this message"
);
@Notes = (
  "* Calculates the total charge of one or more PSF files"
);
}


sub header {
  print("$Script v$Version (c)$Year by Pieter J. in 't Veld\n\n");
}


sub init {
  my @arg;

  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @a = split("=");
      my $value = eval(@a[1]);
      my $flag = @a[1] eq "true" ? 1 : @a[1] eq "" ? 1 : $value ? 1 : 0;
      if (@a[0] eq "-help") {
	help();
      } else {
	help();
      }
    } else {
      push(@arg, $_);
    }
  }
  #help() if (scalar(@arg)<1);
  header();
  return @arg;
}


sub help {
  my $key;

  header();
  set_commands();
  print("Usage:\n  $Script [-command] PSF [...]\n\n");
  print("Commands:\n");
  foreach $key (sort(keys %Commands)) {
    printf("  -%-12.12s %s\n", $key, $Commands{$key});
  }
  if (scalar(@Notes)) {
    print("\nNotes:\n");
    foreach (@Notes) { printf("  %s\n", $_); }
  }
  printf("\n");
  exit(-1);
}


# main

{
  foreach (init()) {
    EMC::Message::info("reading '$_'\n");

    my $stream = EMC::IO::open($_, "r");
    
    foreach(<$stream>) {
      chop();
      @arg = split(" ");
      if (!$n) {
	$n = $ntotal = @arg[0] if (@arg[1] eq "!NATOM");
	next;
      }
      ++$ncharged if (eval(@arg[6]) != 0);
      $charge += @arg[6];
      last if (!--$n);
    }
  }
  printf(
    "\ntotal charge = %f (%f%% charged)\n\n",
    $charge, $ntotal ? $ncharged/$ntotal*100 : 0.0);
  EMC::IO::close($stream);
}

