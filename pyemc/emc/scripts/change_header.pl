#!/usr/bin/env perl
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#

  if (scalar(@ARGV)<1)
  {
    printf("usage: replace.pl [-q] file ...\n\n");
    exit(-1);
  }
  $screen		= 1;
  if ($search eq "-q") { $screen = 0; $search = shift(@ARGV); }
  foreach (@ARGV)
  {
    $name		= $_;
    $found		= 0;
    $nlines		= 0;
    $nchanges		= 0;
    @output		= ();
    open($file, "<".$name);
    while (<$file>)
    {
      ++$nlines;
      if (m/\t\tEMC directory.\*\//) {
	$line		= "\t\tEMC directory.\n*/\n";
	printf("%s:%s: %s", $name, $nlines, $line) if ($screen);
	++$nchanges;
      } else {
	$line		= $_;
      }
      push(@output, $line);
    }
    close($file);
    next if ($nchanges<1);
    open($file, ">".$name);
    foreach (@output) { printf($file "%s", $_); }
    close($file);
    printf("%s: changed %s line%s.\n",
      $name, $nchanges, $nchanges!=1 ? "s" : "") if ($screen);
  }

