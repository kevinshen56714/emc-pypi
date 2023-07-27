#!/usr/bin/env perl
#
#  script:	prm_list_types.pl
#  author:	Pieter J. in 't Veld
#  date:	July 25, 2017, February 27, 2018, April 2, May 26, June 4,
#  		2021, April 6, 2023.
#  purpose:	List the types occuring in an EMC setup script
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20170725	- Creation date
#    20180227	- Addition of REPLICAS paragraph
#    20210402	- Introduced excluded group entries
#    20210526	- Added '&' line extension interpretation
#    20210604	- Added -debug and -list
#    20230406	- New version: 2.0
#    		- Added ITEM INCLUDE interpretation
#

$Version = "2.0";
$Year = "2023";
$Copyright = "2004-$Year";
$Date = "April 6, $Year";
$Author = "Pieter J. in 't Veld";
$Target = 0;
$Debug = 0;
$Quiet = 0;
$Path = ["."];

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
  info("%s \"%s\"\n", ($mode eq "r" ? "read" : "writ")."ing", scrub_dir($name));
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


# i/o routines

sub scrub_dir {
  my $result;
  my @arg;

  if ($^O eq "MSWin32") {
    my $a = @_[0];

    $a =~ s/\//\\/g;
    foreach (split("\\\\", $a)) {
      push(@arg, $_) if ($_ ne "");
    }
    $result = join("/", @arg);
  } else {
    $result = substr(@_[0], 0, 1) eq "/" ? "/" : "";
    foreach (split("/", @_[0])) {
      push(@arg, $_) if ($_ ne "");
    }
    $result .= join("/", @arg);
    $result =~ s/^$ENV{HOME}/~/;
  }
  return $result;
}


sub fexpand {
  return @_[0] if (substr(@_[0],0,1) ne "~");
  return $ENV{HOME}.substr(@_[0],1) if (substr(@_[0],1,1) eq "/");
  return $ENV{HOME}."/../".substr(@_[0],1);
}


sub fexist {
  my $name = fexpand(shift(@_));

  return 1 if (-f $name);
  foreach (@_) { return 1 if (-f $name.$_); }
  return 0;
}


sub flocate {
  my $name = shift(@_);
  my @ext = ("", @{shift(@_)});

  foreach ("", @_) {
    my $root = ($_ eq "" ? "" : $_."/").$name;
    foreach (@ext) {
      my $file = $root.$_;
      return $file if (-f fexpand($file));
    }
  }
  return "";
}


sub trim {
  my $s = shift(@_);
  $s =~ s/^\s+|\s+$//g;
  return $s;
}


sub split_data {
  my $s = trim(@_[0]);
  my @arg = split(",", $s);
  my @result = ();
  my @i = map({index(@arg[0],$_)} (":", "="));

  if (@i[0]>=0 && @i[0]<@i[1]) {
    @arg = split(" ", $s);
    push(@result, @arg[0]);
    $s = substr($s,length(@arg[0]));
  }
  foreach (split("\t", $s)) {
    foreach (split(",", $_)) { 
      $_ =~ s/^\s+|\s+$//g;
      foreach ($_ =~ /(".+"|\S+)/g) {
	push(@result, $_);
      }
    }
  }
  if (substr(@result[0],0,1) ne "\"") {
    @arg = split(" ", @result[0]);
    if (scalar(@arg)>1) {
      shift(@result);
      unshift(@result, @arg);
    }
  }
  push (@result, ",") if (substr(@_[0],-1,1) eq ",");
  @arg = (); 
  foreach (@result) {
    last if (substr($_,0,1) eq "#");
    push(@arg, $_) if ($_ ne "");
  }
  return @arg;
}


sub get_data {
  my $name = shift(@_);
  my $stream = fopen($name, "r");
  my $data = scalar(@_) ? shift(@_) : [];
  my $text;

  foreach (<$stream>) {
    ++$line; chomp;
    $_ = trim($_);
    next if (substr($_,0,1) eq "#");

    if (substr($_,-1,1) eq "&") {
      $_ = trim(substr($_,0,-1));
      $text = length($text) ? "$text $_" : $_;
      next;
    }

    my @arg = split_data(length($text) ? "$text $_" : $_);
    push(@{$data}, [@arg]) if (scalar(@arg));
    $text = "";
    if (!$read) {
      next if (@arg[2] eq "comment=true" || @arg[2] eq "comment=1");
      if (join(" ", @arg[0,1]) eq "ITEM OPTIONS") {
	$read = 1;
      } elsif (join(" ", @arg[0,1]) eq "ITEM INCLUDE") {
	@arg[2] =~ s/^\"|\"$//g;
	my $file = flocate(@arg[2], [".dat", ".inc"], @{$Path});
	$data = get_data($file, $data) if ($file ne "");
	next;
      }
      next;
    }
    next if (!scalar(@arg));
    if (@arg[0] eq "ITEM") {
      if (@arg[1] eq "END") { $read = 0; next; }
      print("Error: unexpected ITEM in $line of '$name'.\n\n");
      exit(-1);
    }
    if ($read) {
      if (@arg[0] eq "location") {
	shift(@arg);
	foreach (@arg) {
	  my @a = split("=");
	  next if (@a[0] ne "include");
	  @a[1] =~ s/^\"|\"$//g;
	  push(@{$Path}, @a[1]);
	}
      }
      next;
    }
  }
  close($stream);
  return $data;
}


sub list_types {
  my %exclude = (alternate => 1, block => 2, random => 3, "&" => 4, "" => 5);
  my $data = get_data($Source);
  my %replicas;
  my %types;
  my $read;
  my $line;
  my $type;
  my $skip;
  my $i;
  my $n;
  my @a;

  foreach (@{$data}) {
    my @arg = @{$_};
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
