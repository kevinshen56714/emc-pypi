#!/usr/bin/env perl
#
#  program:	emc_align.pl
#  author:	Pieter J. in 't Veld
#  date:	July 12, 2020, January 14, 2022.
#  purpose:	Align EMC Script input
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20200712	Conception date
#    20200719	Adaptation to include headers etc.
#    20220114	Preceeded curly braces in regex with a backslash
#    		Added stack for item history
#

$::EMCAlign::script = "emc_align.pl";
$::EMCAlign::author = "Pieter J. in 't Veld";
$::EMCAlign::version = "v1.0";
$::EMCAlign::date = "January 14, 2022";
$::EMCAlign::EMCVersion = "9.4.4";

%::EMCAlign::Flag = (
  message => 1
);

# initialization

sub header {
  message(
    "EMC Script alignment $::EMCAlign::version, ".
    "$::EMCAlign::date, (c) $::EMCAlign::author\n\n");
}


sub help {
  my $command = shift(@_);

  $::EMCAlign::Flag{message} = 1;
  header();
  message("Usage:\n  $::EMCAlign::script [-option[=value]] file.esh [..]\n");
  message("\nOptions:\n");
  message("  -help\t\tThis message\n");
  message("  -output\tSet alternative output name\n");
  message("  -quiet\tSuppress output\n");
  message("\nNotes:\n");
  message("  * Output occurs to STDOUT by default\n");
  message("\n");
  message("Error: unknown command '$command'\n\n") if ($command ne "");
  exit;
}
  

sub initialize {
  my @arg = @_;

  help() if (!scalar(@arg));
  foreach (@arg) {
    if (substr($_,0,1) eq "-") {
      my @a = split("=");
      @a[0] = substr(@a[0],1);
      if (@a[0] eq "help") { help(); }
      elsif (@a[0] eq "output") { $::EMCAlign::Output = @a[1]; }
      elsif (@a[0] eq "quiet") { $::EMCAlign::Flag{message} = flag(@a[1]); }
      else { help(@a[0]); }
    } else {
      push(@::EMCAlign::Input, $_);
    }
  }
}


# functions

sub trim {
  my $s = shift(@_);
  $s =~ s/^\s+|\s+$//g;
  return $s;
}


sub flag {
  return @_[0] eq ""		? 1 : 
    lc(@_[0]) eq "true"		? 1 : 
    lc(@_[0]) eq "false"	? 0 : eval(@_[0]);
}


sub message {
  printf(shift(@_)."%s", join(" ", @_)) if ($::EMCAlign::Flag{message});
}


sub error {
  printf("Error: ".shift(@_)."%s\n", join(" ", @_));
  exit(-1);
}


sub error_line {
  my $line = shift(@_);
  if ($line<0) { error(@_); }
  else { 
    my $format = shift(@_);
    $format =~ s/\n/ in line $line of input\n/g;
    if (scalar(@_)) { error($format, @_); }
    else { error($format); }
  }
}


sub align {
  my $n;
  my $amp;
  my $item;
  my @stack;							# 20220114
  my $first;
  my $flag = 0;
  my @empty = (0, 0);
  my %verbatim = (emc => 1, lammps => 1, namd => 1);
  my %flags = (replicas => 1, nonbonds => 1, bonds => 1, angles => 1);
  my %exclude = (include => 1, stage => 1, trial => 1);
  my %all_caps = (emc => 1, lammps => 1, namd => 1, gromacs => 1);
  my @output;
  my $comment;

  foreach(@::EMCAlign::Input) {
    my $stream;

    open($stream, "<$_");
    if (!$stream) { error("cannot open '$_'.\n"); }
    foreach(<$stream>) {
      chop();
      @a = split(" ", trim($_));
      @empty = (scalar(@a) ? 0 : 1, @empty); pop(@empty);
      next if (@empty[0] && $item eq "");
      if (substr($_,0,1) eq "#") { 
	push(@output, "\n") if ($first);
	push(@output, $_, "\n");
	$comment = $_;
	$first = 0;
	next;
      }
      if (@a[0] eq "ITEM") {
	push(@output, "\n") if ($item eq "" || !@empty[1]);
	if (($item = lc(@a[1])) eq "end") {
	  my $previous = pop(@stack);				# 20220114
	  push(@a, "#", uc($previous)) if (@a[2] eq "");
	  push(@output, 
	    join("\t", (shift(@a), shift(@a), join(" ", @a))), "\n");
	  $item = "";
	} else {
	  my $key = lc(@a[1]);
	  my $section = defined($all_caps{$key}) ? uc($key) : ucfirst($key);
	  my $tmp = "# $section section";
	  push(@output, "$tmp\n\n") if (lc($tmp) ne lc($comment));
	  @a[2] = join(" ", splice(@a, 2)) if (substr(@a[2],0,1) eq "#");
	  push(@output, join("\t", @a), "\n");
	  $flag = $flags{$item};
	  push(@stack, $item) if(!defined($exclude{$item}));	# 20220114
	}
	$first = 1;
	next;
      }
      push(@output, "\n") if (!@empty[0] && $first); $first = 0;
      if (defined($verbatim{$item})) { push(@output, $_, "\n"); next; }
      unshift(@a, "") if ($amp);
      $amp = substr(@a[-1],-1,1) eq "&" ? 1 : 0;
      my $tab = 1;
      if ($flag) {
	foreach (@a) {
	  push(@output, $_);
	  last if ($_ eq @a[-1]);
	  $n = 8-length(@a[0]);
	  if ($n<0) {
	    push(@output, " ");
	  } else {
	    while ($n>0) { push(@output, "\t"); $n -= 8; }
	  }
	}
      } elsif (scalar(@a)) {
	push(@output, @a[0]);
	if (scalar(@a)>1) {
	  $n = 16-length(@a[0]);
	  if ($n<=0) {
	    push(@output, "\t");
	  } else {
	    while ($n>0) { push(@output, "\t"); $n -= 8; }
	  }
	  my $tmp = $_;
	  @a[0] =~ s/\{/\\\{/g;					# 20220114
	  @a[0] =~ s/\}/\\\}/g;					# 20220114
	  $tmp =~ s/^@a[0]//;
	  $tmp =~ s/^\t/ /;
	  push(@output, trim($tmp));
	}
      }
      push(@output, "\n");
    }
    close($stream);
  }
  return @output;
}


# main

{
  initialize(@ARGV);
 
  my @output = align();

  if ($::EMCAlign::Output eq "") {
    foreach (@output) {
      print($_);
    }
  } else {
    open($stream, ">".$::EMCAlign::Output);
    if (!$stream) { 
      error("cannot open '$::EMCAlign::Output'.\n");
    }
    header();
    message("Info: aligning {".
      join(", ", @::EMCAlign::Input)."} to $::EMCAlign::Output\n\n");
    foreach (@output) {
      printf($stream "%s", $_);
    }
    close($stream);
  }
}

