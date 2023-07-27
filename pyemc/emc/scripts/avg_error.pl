#!/usr/bin/env perl
#
#  program:	average.pl
#  author:	Pieter J. in 't Veld
#  date:	October 22, 2018.
#  purpose:	Repair of LAMMPS time-averaged output; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20181022	Conception
#

# functions

sub scan {
  my $name = shift(@_);
  my $error = 0;
  my $skip = 2;
  my $stream;
  my $line;

  open($stream, "<$name");
  foreach (<$stream>) {
    ++$line;
    my @arg = split(" ");
    if ($skip) {
      push(@output, join(" ", @arg));
      if ($skip==1) {
	$ntarget = scalar(@arg)-1;
      }
      --$skip;
      next;
    }
    if (scalar(@arg)!=$ntarget) { 
      $error = 1;
      next;
    }
    push(@output, join(" ", @arg));
  }
  close($stream);
  return 0 if (!$error);
  print("$name\n");
  return 1;
}


# main

{
  my $stream;

  foreach (@ARGV) {
    @output = ();
    next if (!scan($_));
    open($stream, ">$_.correct");
    foreach(@output) {
      print($stream "$_\n");
    }
    close($stream);
  }
}
