#!/usr/bin/env perl
#
#  script:	prm_reduce.pl
#  author:	Pieter J. in 't Veld
#  date:	April 6, 2017, April 5, 2019, June 12, 2020, July 2, 2021.
#  purpose:	Reduce number of parameters using parameters.csv and
#		references.csv files; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20170406	Creation date
#    20190405	Added -source, -source_dir, -target, and -target_dir options
#    20200612	Corrected behavior of abovementioned options
#    20210702	Addition of reading gzipped files
#

use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

$Version = "2.2";
$Year = "2021";
$Copyright = "2004-$Year";
$Date = "July 2, $Year";
$Target = 0;
$Columns = 80;

%Compress = (params => 0, refs => 0);
%Source = (params => "parameters.csv", refs => "references.csv");
%Target = (params => "parameters.csv", refs => "references.csv");
$SourceDir = "src/";
$TargetDir = "./";

# general functions

sub set_commands {
%Commands = (
  help		=> {
    comment	=> "this message",
    default	=> ""
  },
  source	=> {
    comment	=> "set source file names",
    default	=> "params:$Source{params}, refs:$Source{refs}"
  },
  source_dir	=> {
    comment	=> "set source directory",
    default	=> $SourceDir
  },
  target	=> {
    comment	=> "set target file names",
    default	=> "params:$Target{params}, refs:$Target{refs}"
  },
  target_dir	=> {
    comment	=> "set target directory",
    default	=> $TargetDir
  }
);
@Notes = (
  "Reduces $SourceDir$Source{params} and $SourceDir$Source{params} to ".
  "$TargetDir$Target{params} and $TargetDir$Target{params} respectively ".
  "using types as given by the type list"
);
}


sub initialize {
  my @arg;
  my @order = ("params", "refs");

  set_origin($0);
  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @value;
      my @string = split("=");
      my $option = shift(@string);
     
      foreach (@string = split(",", @string[0])) { push(@value, eval($_)); }
      my $flag = @string[0] eq "true" ? 1 :
		 @string[0] eq "" ? 1 : $value[0] ? 1 : 0;
      if ($option eq "-help") {
	help();
      } elsif ($option eq "-source") {
	my @index = @order;
	my $i = 0; foreach (@string) {
	  my @a = split(":");
	  my $index = scalar(@a)>1 ? shift(@a) : shift(@index);
	  next if (!defined($Source{$index}));
	  $Source{$index} = @a[0];
	  $Compress{$index} = 1 if (substr(@a[0],-3) eq ".gz");
	}
      } elsif ($option eq "-source_dir") {
	$SourceDir = @string[0];
	if (length($SourceDir)) {
	  $SourceDir .= "/" if (substr($SourceDir,-1,1) ne "/");
	}
      } elsif ($option eq "-target") {
	my @index = @order;
	my $i = 0; foreach (@string) {
	  my @a = split(":");
	  my $index = scalar(@a)>1 ? shift(@a) : shift(@index);
	  next if (!defined($Target{$index}));
	  $Target{$index} = @a[0];
	}
      } elsif ($option eq "-target_dir") {
	$TargetDir = @string[0];
	if (length($TargetDir)) {
	  $TargetDir .= "/" if (substr($TargetDir,-1,1) ne "/");
	}
      } else {
	help();
      }
    } else {
      push(@arg, $_);
    }
  }
  help() if (scalar(@arg)<1);

  @ARGS = sort(@arg);

  $SourceDir = check_dir($SourceDir);
  $TargetDir = check_dir($TargetDir);

  foreach (@order) {
    if (! -e $SourceDir.$Source{$_}) {
      next if (! -e $SourceDir.$Source{$_}.".gz");
      $Source{$_} .= ".gz";
      $Compress{$_} = 1;
    } else {
      $Compress{$_} = 0;
    }
    if ($SourceDir.$Source{$_} eq $TargetDir.$Target{$_}) {
      print("$SourceDir$Source{$_} eq $TargetDir$Target{$_}\n");
      print("Error: source and target $_ are equal\n\n"); exit(-1);
    }
  }
}


sub check_dir {
  my $dir = shift(@_);

  $dir =~ s/^~/$ENV{HOME}/g;
  return if ($dir eq "");
  if (! -e $dir) {
    print("Error: cannot open \"$dir\"\n\n"); exit(-1);
  }
  if (! -d $dir) {
    print("Error: \"$dir\" is not a directory\n\n"); exit(-1);
  }
  return $dir;
}


sub header {
  print("$Script v$Version ($Date), (c) $Copyright by Pieter J. in 't Veld\n\n");
}


sub set_origin {
  my @arg = split("/", @_[0]);
  @arg = (split("/", $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  $Script = @arg[-1];
  pop(@arg); pop(@arg);
  $Root = join("/", @arg);
}


sub help {
  my $n;
  my $key;
  my $format;
  my $columns;
  my $offset = 3;
  my $gap = 2;

  header();
  set_commands();
  $columns = $Columns-3;
  foreach (keys %Commands) {
    $n = length($_) if (length($_)>$n); }
  $n += $gap;
  $format = "%-$n.".$n."s";
  $offset += $n;

  print("Usage:\n  $Script ");
  print("[-command[=#[,...]]] type [...]\n\n");
  print("Commands:\n");
  foreach $key (sort(keys %Commands)) {
    printf("  -$format", $key);
    $n = $offset;
    foreach (split(" ", ${$Commands{$key}}{comment})) {
      if (($n += length($_)+1)>$columns) {
	printf("\n   $format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    if (${$Commands{$key}}{default} ne "") {
      foreach (split(" ", "[${$Commands{$key}}{default}]")) {
	if (($n += length($_)+1)>$columns) {
	  printf("\n   $format", ""); $n = $offset+length($_)+1; }
	print(" $_");
      }
    }
    print("\n");
  }

  printf("\nNotes:\n");
  $offset = $n = 3;
  $format = "%$n.".$n."s";
  foreach (@Notes) { 
    $n = $offset;
    printf($format, "*");
    foreach (split(" ")) {
      if (($n += length($_)+1)>$columns) {
	printf("\n$format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    print("\n");
  }
  printf("\n");
  exit(-1);
}


sub reduce {
  my %match;
  my $stream;
  my @result;
  my $header;
  my $input = shift(@_);
  my $output = shift(@_);
  my $mode = shift(@_);
  my $compress = shift(@_);
  my $n = $mode ? 1 : 0;

  if (! -f $input) {
    print("Error: could not open \"$input\"\n\n"); exit(-1);
  }

  if ($compress) {
    $input = new IO::Uncompress::Gunzip $input [OPTS]
	     or die "gunzip failed: $GunzipError\n";
  } else {
    open ($input, "<$input");
  }
  foreach (@_) { $match{$_} = 1; }

  my $fheader = 1;
  foreach (<$input>) {
    chop();
    if ($fheader) {
      $header = $_; $fheader = 0; next;
    }
    my $flag = 1;
    my @arg = split(",");
    foreach (@arg[0..$n]) {
      if (!defined($match{$_}) && defined($match{uc($_)})) {
	$_ = uc($_); @arg[1] = uc(@arg[1]) if ($mode == 0);
      }
      $flag = 0 if (!defined($match{$_}));
    }
    next if (!$flag);
    if ($mode) { 
      foreach(@arg[2 .. scalar(@arg)-1]) { $_ = sprintf("%.10g", $_); }
    }
    push(@result, join(",", @arg));
  }
  close($input);
  open ($output, ">$output");
  my @arg = split(",", $header);
  @arg = ("","",@arg) if ($mode && @arg[0] ne "");
  printf($output "%s\n", join(",", @arg));
  foreach (sort(@result)) {
    printf($output "%s\n", $_);
  }
  close($output);
}


# main

{
  initialize();

  header();
  print("Info: using {", join(", ", @ARGS), "}\n");
  foreach ("params", "refs") {
    print("Info: reducing $SourceDir$Source{$_} to $TargetDir$Target{$_}\n");
    reduce(
      $SourceDir.$Source{$_}, $TargetDir.$Target{$_},
      $_ eq "refs" ? 0 : 1, $Compress{$_},
      @ARGS);
  }
  print("\n");
}

