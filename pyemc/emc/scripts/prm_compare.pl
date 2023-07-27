#!/usr/bin/env perl
#
#  script:	prm_compare.pl
#  author:	Pieter J. in 't Veld
#  date:	April 4, 2016, December 2, 2019.
#  purpose:	Compare nonbonded parameters in either .csv or .prm parameter
#		files; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#

$Version = "1.0";
$Year = "2016";
$Offset = 0;
$Target = 0;

# general functions

sub set_commands {
%Commands = (
  "help"	=> "this message",
  "all"		=> "show all entries",
  "cross"	=> "show only selected cross terms",
  "csv"		=> "output as comma separated values",
  "offset"	=> "subtract offset from interaction constant",
  "target"	=> "pick target column [$Target]",
  "tex"		=> "output in tex table format"
);
}

sub initialize {
  my @arg;

  set_origin($0);
  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @a = split("=");
      my $value = eval(@a[1]);
      my $flag = @a[1] eq "true" ? 1 : @a[1] eq "" ? 1 : $value ? 1 : 0;
      if (@a[0] eq "-help") {
	help();
      } elsif (@a[0] eq "-all") { 
	$FlagAll = $flag;
      } elsif (@a[0] eq "-cross") { 
	$FlagCross = $flag;
      } elsif (@a[0] eq "-csv") { 
	$FlagCSV = $flag;
	$FlagTEX = 0;
      } elsif (@a[0] eq "-offset") { 
	$Offset = scalar(@a)>1 ? $value : 25;
      } elsif (@a[0] eq "-target") { 
	$Target = $value;
      } elsif (@a[0] eq "-tex") { 
	$FlagTEX = $flag;
	$FlagCSV = 0;
      } else {
	help();
      }
    } else {
      push(@arg, $_);
    }
  }
  help() if (scalar(@arg)<($FlagAll ? 1 : 2));
  $Parameters = shift(@arg);
  @ARGS = $FlagAll ? get_types() : sort(@arg);
}


sub help {
  my $key;

  header();
  set_commands();
  print("Usage:\n  $Script [-command] parameters.prm target [...]\n\n");
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


sub header {
  print("$Script v$Version (c)$Year by Pieter J. in 't Veld\n\n");
}


sub set_origin {
  my @arg = split("/", @_[0]);
  @arg = (split("/", $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  $Script = @arg[-1];
  pop(@arg); pop(@arg);
  $Root = join("/", @arg);
}


sub get_types {
  my %args;
  my $stream;
  my $read = 1;

  open($stream, "<$Parameters");
  foreach (<$stream>) {
    next if (substr($_,0,1) eq "#");
    chop();
    my @arg = split(","); 
    @arg = split(" ", @arg[0]) if (scalar(@arg)<2);
    if (@arg[0] eq "ITEM") {
      $read = @arg[1] eq "NONBOND" ? 1 : 0; next;
    }
    next if (!$read);
    next if (scalar(@arg)<3);
    $args{@arg[0]} = $args{@arg[1]} = 1;
  }
  return sort(keys(%args));
}


# specific functions

sub compare
{
  my %header;
  my @targets;
  my %results;
  my $sep = $FlagCSV ? "," : $FlagTEX ? "\t& " : "\t";
  
  foreach (@ARGS) {
    push(@targets, $_);
    open($stream, "<$Parameters");
    my $read = 1;
    foreach (<$stream>) {
      next if (substr($_,0,1) eq "#");
      chop();
      my @arg = split(","); 
      @arg = split(" ", @arg[0]) if (scalar(@arg)<2);
      if (@arg[0] eq "ITEM") {
	$read = @arg[1] eq "NONBOND" ? 1 : 0; next;
      }
      next if (!$read);
      next if (scalar(@arg)<3);
      foreach (@arg[0,1]) { 
       	next if (lc($_) ne lc(@targets[-1]));
	@targets[-1] = $_;
	$header{$_} = 1;
      }
      if (@arg[0] eq @targets[-1]) { $type = @arg[1]; }
      elsif (@arg[1] eq @targets[-1]) { $type = @arg[0]; }
      else { next; }
      push(@{$results{$type}}, sprintf("%6.6s", sprintf("%.4f", @arg[2+$Target]-$Offset)));
    }
    close($stream);
  }
  print(
    join($sep, "", sort(keys(%header))), $FlagTEX ? "\t\\\\\n" : "\n");
  foreach (sort(keys(%results))) {
    my $flag = 0;
    if ($FlagCross) {
      my $type = $_;
      foreach (@targets) {
	next if ($type ne $_);
	$flag = 1; last;
      }
    } else {
      $flag = 1;
    }
    print(
      join($sep, $_, @{$results{$_}}), $FlagTEX ? "\t\\\\\n" : "\n") if ($flag);
  }
}


# main

{
  initialize();
  compare();
}

