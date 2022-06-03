#!/usr/bin/env perl
#
#  program:	ref_search.pl
#  author:	Pieter J. in 't Veld
#  date:	June 3, 2021
#  purpose:	Search references.csv for pattern
#
#  notes:
#    20210603	Inception
#

use strict;

$::EMCSearch::Year = "2021";
$::EMCSearch::Version = "1.0";
$::EMCSearch::Copyright = "2004-$::EMCSearch::Year";
$::EMCSearch::Date = "June 3, $::EMCSearch::Year";
$::EMCSearch::Author = "Pieter J. in 't Veld";

%::EMCSearch::Flag = (
  debug => 0,
  info => 1,
  message => 1
);

%::EMCSearch::Pattern = (
  comment => "*",
  mass => [0,"all"],
  smiles => "*",
  type => "*",
  volume => [0,"all"]
);

# functions

# general

sub flag {
  return @_[0] eq ""	? 1 : 
    @_[0] eq "true"	? 1 : 
    @_[0] eq "false"	? 0 : eval(@_[0]);
}


sub boolean {
  return @_[0] if (@_[0] eq "true");
  return @_[0] if (@_[0] eq "false");
  return @_[0] ? @_[0]<0 ? "auto" : "true" : "false";
}


sub my_eval {
  my $string;
  my $first = 1;
  my $error = 0;

  foreach (split(//, @_[0])) {
    next if ($first && $_ eq "0");
    $string .= $_;
    $first = 0;
  }
  $string = "0" if ($string eq "");
  {
    local $@;
    no warnings;
    unless (eval($string)) { $error = 1; }
  }
  return $error ? $string : eval($string);
}


# screen output

sub message {
  print(@_) if ($::EMCSearch::Flag{message});
}


sub info {
  printf("Info: ".shift(@_), @_) if ($::EMCSearch::Flag{info});
}


sub debug {
  printf("Debug: ".shift(@_), @_) if ($::EMCSearch::Flag{debug});
}


sub error {
  printf("Error: ".shift(@_), @_);
  printf("\n");
  exit(-1);
}


sub tprint {
  print(join("\t", @_), "\n");
}


sub header {
  message("Reference search v$::EMCSearch::Version ($::EMCSearch::Date), ");
  message("(c) $::EMCSearch::Copyright $::EMCSearch::Author\n\n");
}


# i/o

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


# application

sub search {
  my @arg;
  my $stream;
  my $cr = 0;
  my $name = shift(@_);
  my %col = (type => 0, mass => 2, volume => 3, smiles => 7, comment => 8);
  my %val = (mass => 1, volume => 1);
  my %lc = (type => 1, comment => 1);

  $stream = fopen($name.".csv", "r");
  print("\n");
  foreach (<$stream>) {
    next if (substr($_,0,1) eq "#");
    chop; 
    @arg = split(",");
    my $flag = 1;

    foreach (sort(keys(%::EMCSearch::Pattern))) {
      my $a = @arg[$col{$_}];
      my $p = $::EMCSearch::Pattern{$_};
      
      $a = lc($a) if (defined($lc{$_}));
      $p = lc($p) if (defined($lc{$_}));
      if (defined($val{$_})) {
	$flag = 0 if ($a<@{$p}[0]);
	$flag = 0 if (@{$p}[1] eq "all" ? 0 : $a>@{$p}[1]); 
      } else {
	$flag = 0 if (($p ne "*" ? index($a, $p) : 0)<0);
      }
    }
    next if (!$flag);
    message($_, "\n"); $cr = 1;
  }
  print("\n") if ($cr);
  fclose($stream);
}


# initialization

sub help {
  $::EMCSearch::Flag{message} = 1;
  header();
  message("Usage:\n  $::EMC::Script [-option[=value]] reference\n");
  message("\nOptions:\n");
  message("  -comment\tSet comment pattern [$::EMCSearch::Pattern{comment}]\n");
  message("  -help\t\tThis message\n");
  message("  -info\t\tProvide info [", boolean(flag($::EMCSearch::Flag{info})), "]\n");
  message("  -mass\t\tSet mass range [", join(",", @{$::EMCSearch::Pattern{mass}}), "]\n");
  message("  -message\tOutput messages [", boolean(flag($::EMCSearch::Flag{message})), "]\n");
  message("  -smiles\tSet SMILES pattern [$::EMCSearch::Pattern{smiles}]\n");
  message("  -quiet\tTurn all output off\n");
  message("  -type\t\tSet type pattern [$::EMCSearch::Pattern{type}]\n");
  message("\nNotes:\n");
  message("  * Assumes .csv extension\n");
  message("\n");
  exit;
}


sub init {
  my $hash;
  my @names = ();
  my $win = $^O eq "MSWin32" ? 1 : 0;
  my $split = ($win ? "\\\\" : "/");
  my @arg = split($split, $0);
 
  @arg = (split($split, $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  $::EMC::Script = @arg[-1];
  foreach (@_) {
    if (substr($_, 0, 1) eq "-") {
      @arg = split("=");
      my $command = substr(shift(@arg), 1);
      my @string = split(",", @arg[0]);
      my @value = @string;

      foreach (@value) { $_ = my_eval($_); }
      
      if ($command eq "-help") { 
	help();
      } elsif ($command eq "comment") {
       	$::EMCSearch::Pattern{comment} = @string[0];
      } elsif ($command eq "debug") { 
	$::EMCSearch::Flag{debug} = flag(@string[0]);
      } elsif ($command eq "info") { 
	$::EMCSearch::Flag{info} = flag(@string[0]);
      } elsif ($command eq "mass") {
	error("mass values != 2\n") if (scalar(@value)!=2);
	$::EMCSearch::Pattern{mass} = [@value];
      } elsif ($command eq "message") { 
	$::EMCSearch::Flag{message} = flag(@string[0]);
      } elsif ($command eq "quiet") { 
	$::EMCSearch::Flag{debug} = 0;
	$::EMCSearch::Flag{info} = 0;
	$::EMCSearch::Flag{message} = 0;
      } elsif ($command eq "smiles") {
       	$::EMCSearch::Pattern{smiles} = @string[0];
      } elsif ($command eq "type") {
       	$::EMCSearch::Pattern{type} = @string[0];
      } elsif ($command eq "volume") {
	error("mass values != 2\n") if (scalar(@value)!=2);
	$::EMCSearch::Pattern{volume} = [@value];
      } else { 
	help();
      }
      next;
    }
    $_ = substr($_, 0, length($_)-4) if (substr($_, -4) eq ".csv");
    push(@names, $_);
  }
  help() if (scalar(@names)!=1);
  return (names => [@names]);
}


# main

{
  my %hash = init(@ARGV);

  header();
  foreach (@{$hash{names}}) {
    search($_);
  }
}

