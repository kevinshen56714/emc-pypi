#!/usr/bin/env perl
#
#  program:	replace.pl
#  author:	Pieter J. in 't Veld
#  date:	August 10, 2005, April 9, 2013, April 26, 2017, January 26,
#  		November 4, 2018, January 12, May 10, 2019, June 9, 2020,
#  		May 17, June 10, 2021, March 26, 2024.
#  purpose:	Search and replace strings in multiple files; part of EMC
#  		distribution
# 
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  Notes:
#    20050810	- Inception date
#    20180126	- Change to only filtering options -f, -h, and -q instead of
#    		  showing help when a search or replace string starts with -
#    20181104	- Added variable replacement using '@' as identifier
#    20190112	- Added underscore as part of variable name
#    20190511 	- Added @ as delimiter for variable recognition
#    		- Added curly brackets for variable designation, i.e. @{var};
#    		  adds curly brackets for variables without delimiters
#    20190622	- Changed behavior of braced variables
#    20200609	- Added replacement of specific lines
#    20210517	- Added -d to use replace string as file name
#    20210610	- Added check for square brackets to exclude @ interpretation
#    		  for SMILES
#    20240326	- Change to v2.5
#    		- Addition of -s option
#    20240428	- Addition of -m option
#    20250609	- Filtered out replacement of $@ to $@{}
#

#use Data::Dumper;
use File::Find;
use Time::Piece;

$Version = "2.5.1";
$Year = "2025";
$Date = "June 9, $Year";
$Copyright = "2004-$Year";

# functions

sub help {
  print("EMC Replace v$Version ($Date), (c) $Copyright Pieter J. in 't Veld\n\n");
  print("Usage:\n");
  print("  replace.pl [-option[=#]] search_string replace_string file[:#] ...\n");
  print("\n");
  print("Options:\n");
  print("  -d\t\tuse replace_string as replace file name\n");
  print("  -f\t\tconsider full file\n");
  print("  -h\t\tthis message\n");
  print("  -m\t\tprovide mask for find\n");
  print("  -q\t\tno output\n");
  print("  -s\t\treplace date stamps\n");
  print("  -v\t\tvariable replacement using '\@' (not with -f)\n");
  print("\n");
  print("Notes:\n");
  print("  * Only a specific line is considered when indicated after file\n");
  print("\n");
  exit(-1);
}


sub init {
  my @arg		= @_;

  $flag_vars		= 0;
  $flag_data 		= 0;
  $flag_full 		= 0;
  $flag_replace		= 1;
  $flag_screen		= 1;
  $flag_stamp		= 0;
  $mask			= undef;
  foreach (@arg) {
    if (substr($_,0,1) eq "-") {
      my @a = split("=");
      if (@a[0] eq "-q") {
       	$flag_screen = defined(@a[1]) ? flag(@a[1]) : 0; next; }
      elsif (@a[0] eq "-d") {
       	$flag_data = defined(@a[1]) ? flag(@a[1]) : 1; next; }
      elsif (@a[0] eq "-f") {
       	$flag_full = defined(@a[1]) ? flag(@a[1]) : 1; next; }
      elsif (@a[0] eq "-m") {
       	$mask = @a[1] if (defined(@a[1])); next; }
      elsif (@a[0] eq "-r") {
       	$flag_replace = defined(@a[1]) ? flag(@a[1]) : 0; next; }
      elsif (@a[0] eq "-s") {
       	$flag_stamp = defined(@a[1]) ? flag(@a[1]) : 1; next; }
      elsif (@a[0] eq "-v") {
       	$flag_vars = defined(@a[1]) ? flag(@a[1]) : 1; next; }
      elsif (@a[0] eq "-h") {
       	help(); }
    }
    $_			=~ s/\\n/\n/g;
    $_			=~ s/\\t/\t/g;
    push(@files, $_);
  }
  if ($flag_replace) {
    $search		= shift(@files);
    $replace		= shift(@files);
    $replace		= `cat $replace` if ($flag_data);
    chop($replace) if ($flag_data);
  }
  if (defined($mask)) {
    my @f = ffind(".", $mask);
    push(@files, @f) if (scalar(@f));
  }
  help() if (scalar(@files)<1);
  return if (!$flag_vars);
  return if (substr($search,0,1) ne "@");
  $search		=~ s/[@,\{,\}]//g;
  $search		= "\@{$search}";
}


sub flag {
  my %allowed = ("true" => 1, "false" => 0, "1" => 1, "0" => 0);
  
  return 
    @_[0] eq "" ? 1 : 
    defined($allowed{@_[0]}) ? $allowed{@_[0]} : 
    eval(@_[0]) ? 1 : 0;
}


sub ffind {							# 20240428
  my $dir = shift(@_);
  my $pattern = shift(@_);
  my @dirs;
  my @files;

  File::Find::find( sub{ -d $_ and push @dirs, $File::Find::name; }, $dir );
  for (my $i=0; $i<2; ++$i) {
    foreach (@dirs) {
      foreach (sort(glob($_."/".$pattern))) {
	push(@files, $_) if (-e $_);
      }
    }
    last if (scalar(@files));
    $pattern .= ".gz"
  }
  return @files;
}


sub lines {
  my ($name, $nline)	= (split(":", shift(@_)))[0,1];
  my $found		= 0;
  my $nlines		= 0;
  my $nchanges		= 0;
  my @output		= ();
  my $file;
  my $stamp;

  if ($flag_stamp) {
    my $time		= Time::Piece::localtime();		# 20240326
    my $fullmonth	= $time->fullmonth;

    $stamp		= {
      day		=> sprintf("%02d", $time->day_of_month),
      month		=> sprintf("%02d", $time->mon),
      year		=> $time->year,
      ymd		=> $time->ymd(""),
      date		=> "$fullmonth ".$time->day_of_month.", ".$time->year
    };
  }

  open($file, "<".$name);
  while (<$file>)
  {
    ++$nlines;
    $line		= $_;
    if ($flag_stamp) {
      foreach (keys(%{$stamp})) {
	my $STAMP	= "@\\{".uc($_)."\\}";
	$line		=~ s/$STAMP/$stamp->{$_}/g;
      }
    }
    if ($nline) {
      if ($flag_replace) {
	$line		=~ s/$search/$replace/g if ($nline==$nlines);
      }
    } elsif ($flag_vars && ($_ =~ tr/@//)) {
      my $var;
      my $last;
      my $read;
      my $braces;
      my $result;
      my $brackets;
      
      foreach(split("", $line)) {
	if ($_ eq "[") {
	  ++$brackets;
	} elsif ($_ eq "]") {
	  --$brackets;
	}

	if ($_ eq "@" && $last ne "\$" && !$brackets) {
	  if ($var ne "") {
	    $var	.= "}";
	    $result	.= ($var eq $search ? $replace : $var);
	  }
	  $var		= $_."{";
	  $read		= 1;
	  $braces	= 0;
	} elsif ($read) {
	  if (($_ =~ /[a-zA-Z]/)||($_ =~ /[0-9]/)||($braces && $_ ne "}")) {
	    $var	.= $_;
	  } elsif ($_ eq "{" && $last eq "@") {
	    $braces	= 1;
	  } else {
	    $var	.= "}";
	    $result	.= ($var eq $search ? $replace : $var).
			   ($braces && $_ eq "}" ? "" : $_);
	    $var	= "";
	    $read	= 0;
	    $braces	= 0;
	  }
	} else {
	  $result	.= $_;
	}
	$last		= $_;
      }
      $result		.= ($var eq $search ? $replace : $var) if ($read);
      $line		= $result;
    } elsif ($flag_vars ? substr($search,0,1) ne "@" : 1) {
      $line		=~ s/$search/$replace/g if ($flag_replace);
    }
    push(@output, $line);
    next if ($line eq $_);
    printf("%s:%s: %s", $name, $nlines, $line) if ($flag_screen);
    ++$nchanges;
  }
  close($file);
  next if ($nchanges<1);
  open($file, ">".$name);
  foreach (@output) { printf($file "%s", $_); }
  close($file);
  return $nchanges;
}


sub full {
  my $name		= shift(@_);
  my $data		= `cat $name`;
  my $nchanges		= $data	=~ s/$search/$replace/g;
  my $file;

  open($file, ">$name");
  print($file $data);
  close($file);
  return $nchanges
}


# main

  init(@ARGV);

  foreach (@files)
  {
    my $nchanges;
    my $name		= $_;

    if ($flag_full) {
      $nchanges		= full($name);
    } else {
      $nchanges		= lines($name);
    }
    $nchanges		= 0 if (!$nchanges);
    printf("%s: changed %s line%s.\n",
      $name, $nchanges, $nchanges!=1 ? "s" : "") if ($flag_screen);
  }

