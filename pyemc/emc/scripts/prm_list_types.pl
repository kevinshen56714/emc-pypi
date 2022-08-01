#!/usr/bin/env perl
#
#  script:	prm_list_types.pl
#  author:	Pieter J. in 't Veld
#  date:	July 25, 2017, February 27, 2018, April 2, May 26, June 4, 2021
#  purpose:	List the types occuring in an EMC setup script
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20170725	- Creation date
#    20180227	- Addition of REPLICAS paragraph
#    20210402	- Introduced excluded group entries
#    20210526	- Added '&' line extension interpretation
#    20210604	- Added -debug and -list
#

$Version = "1.3";
$Year = "2021";
$Copyright = "2004-$Year";
$Date = "June 4, $Year";
$Author = "Pieter J. in 't Veld";
$Target = 0;
$Debug = 0;
$Quiet = 0;

# general functions

sub error {
  printf("Error: ".shift(@_), @_);
  printf("\n");
  exit(-1);
}


sub info {
  printf("Info: ".shift(@_), @_) if (!$Quiet);
}


sub fopen {
  my $name = shift(@_);
  my $mode = shift(@_);
  my $file;
  my $result;

  error("illegal mode") if (!($mode eq "r" || $mode eq "w"));
  info("opening \"$name\" for %s", ($mode eq "r" ? "read" : "writ")."ing\n");
  open($file, ($mode eq "r" ? "<" : ">").$name);
  error("cannot open file \"$name\"") if (!scalar($file));
  return $file;
}


sub fclose {
  my $file = shift(@_);

  close($file) if (scalar($file));
}


sub header {
  return if ($Quiet);
  print("$Script v$Version ($Date), (c) $Copyright by $Author\n\n");
}


sub set_commands {
%Commands = (
  "help"	=> "this message",
  "debug"	=> "output debug information",
  "list"	=> "output types list only"
);
@Notes = (
  "* Lists the occuring types in an EMC Setup script"
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
      } elsif (@a[0] eq "-debug") {
	$Debug = 1;
      } elsif (@a[0] eq "-list") {
	$Quiet = 1;
      } else {
	help();
      }
    } else {
      push(@arg, $_);
    }
  }
  help() if (scalar(@arg)<1);

  $Source = shift(@arg);
  @ARGS = sort(@arg);

  if (! -e $Source) {
    print("Error: cannot open \"$Source\"\n\n"); exit(-1);
  }
  if (! -f $Source) {
    print("Error: \"$Source\" is not a file\n\n"); exit(-1);
  }
}


sub set_origin {
  my @arg = split("/", @_[0]);
  @arg = (split("/", $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  $Script = @arg[-1];
  pop(@arg); pop(@arg);
  $Root = join("/", @arg);
}


sub help {
  my $key;

  header();
  set_commands();
  print("Usage:\n  $Script [-command] script type [...]\n\n");
  print("Commands:\n");
  foreach $key (sort(keys %Commands)) {
    printf("  -%-12.12s %s\n", $key, ucfirst($Commands{$key}));
  }
  if (scalar(@Notes)) {
    print("\nNotes:\n");
    foreach (@Notes) { printf("  %s\n", $_); }
  }
  printf("\n");
  exit(-1);
}


sub list_types {
  my %exclude = (alternate => 1, block => 2, random => 3, "&" => 4, "" => 5);
  my $stream;
  my %replicas;
  my %types;
  my $read;
  my $line;
  my $type;
  my $skip;
  my $i;
  my $n;
  my @a;

  $stream = fopen($Source, "r");
  foreach (<$stream>) {
    ++$line; chop;
    $_ =~ s/^\s+|\s+$//g;
    next if (substr($_,0,1) eq "#");

    if ($skip) {
      $skip = substr($_,-1,1) eq "&" ? 1 : 0;
      next;
    }
    $skip = 1 if (substr($_,-1,1) eq "&");
    
    my @arg = split(" ");
    if (!$read) {
      next if (@arg[2] eq "comment=true" || @arg[2] eq "comment=1");
      $read = 1 if (join(" ", @arg[0,1]) eq "ITEM GROUPS");
      $read = 1 if (join(" ", @arg[0,1]) eq "ITEM SHORTHAND");
      $read = 1 if (join(" ", @arg[0,1]) eq "ITEM STRUCTURES");
      $read = 2 if (join(" ", @arg[0,1]) eq "ITEM REPLICAS");
      $read = 3 if (join(" ", @arg[0,1]) eq "ITEM NONBONDS");
      next;
    }
    next if (!scalar(@arg));
    if (@arg[0] eq "ITEM") {
      if (@arg[1] eq "END") { $read = 0; next; }
      print("Error: unexpected ITEM in $line of input.\n\n");
      exit(-1);
    }
    if ($read==2) {
      @a = split(":", @arg[0]);
      $replicas{@a[0]} = 1;
      @a = split(":", @arg[1]);
      $types{@a[0]} = 1;
      next;
    } elsif ($read==3) {
      foreach (@arg[0..1]) {
	$types{$_} = 1 if (!(defined($replicas{$_}) || ($_ =~ m/\*/)));
      }
      next;
    }
    my $group = @arg[1];
    foreach ("\t", ",", " ") { $group = (split($_, $group))[0]; }
    $n = length($group);
    $type = "";
    my $brackets = 0;
    my $charge = 0;
    next if (defined($exclude{$group}));
    for ($i = 0; $i < $n; ++$i) {
      my $c = substr($group, $i, 1);
      next if ($c eq "(");
      next if ($c eq ")");
      next if ($c eq ".");
      next if ($c eq "*");
      next if ($c eq "&");
      next if (($c eq "0" || $c > 0) && !$brackets);
      if ($brackets && ($c eq "-" || $c eq "+")) { $charge = 1; }
      if ($c eq "[") { ++$brackets; next };
      if ($c ne "]") { $type .= $c if (!$charge); }
      else { --$brackets; }
      if (!$brackets) {
	print(join("\t", __LINE__.":", $line, $type), "\n") if ($Debug);
	$types{$type} = 1 if (!defined($replicas{$type}));
	$charge = 0;
	$type = "";
      }
    }
  }
  if ($Quiet) {
    print(join(" ", sort(keys(%types))), "\n");
  } else {
    info("types = {%s}\n\n", join(", ", sort(keys(%types))));
  }
  fclose($stream);
}


# main

{
  initialize();
  header();
  list_types();
}
