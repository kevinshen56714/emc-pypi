#!/usr/bin/env perl
#
#  file:	cpmod.pl
#  author:	Pieter J. in 't Veld
#  date:	March 10, 2006, April 14, 2007, September 30, 2010,
#  		February 8, 2018, June 6, 2020, November 28, 2021,
#  		January 2, 2022.
#  purpose:	copy modules, preserving function and data structure; part of
#  		EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20060310	Inception date
#    20070414	Added replacement of prefaces
#    20180208	Added check for .sh
#    20200606	Added changes to include paths
#    20211128	Added check for .pm
#    		Canceled lower case of file names
#    		Added replacement of date indicators @{DATE} etc.
#    20220102	Refined handling of date indicators
#    20220314	Added check for .txi
#

use Time::Piece;

sub test {
  my $file = shift;
  my $xor = shift;
  my $result = scalar(stat($file))^$xor;

  printf("Error: %s %sexist%s.\n", 
    $file, $xor ? "does not " : "", $xor ? "" : "s") if ($result);
  return $result;
}


sub replace {
  my $ext = shift;
  my $input = $files[0];
  my $output = $files[1];
  my $file_in;
  my $file_out;
  my $time = Time::Piece::localtime();
  my $day = sprintf("%02d", $time->day_of_month);		# 20220102
  my $month = sprintf("%02d", $time->mon);			# 20220102
  my $year = $time->year;
  my $ymd = $time->ymd("");
  my $fullmonth = $time->fullmonth;
  my $date = "$fullmonth ".$time->day_of_month.", $year";	# 20220102

  return if (test($input.$ext, 1)||test($output.$ext, 0));
  open($file_in, "<", $input.$ext);
  open($file_out, ">", $output.$ext);
  foreach (<$file_in>)
  {
    my $tmp = $_;
    if (length($prefaces[0])) {					# 20070414
      #$tmp =~ s/$includes[0]/$includes[1]/g;			# 20200606
      $tmp =~ s/$prefaces[0]/$prefaces[1]/g;
      $tmp =~ s/$Prefaces[0]/$Prefaces[1]/g;
      $tmp =~ s/$PREFACES[0]/$PREFACES[1]/g;
    }
    $tmp =~ s/$names[0]/$names[1]/g;
    $tmp =~ s/$Names[0]/$Names[1]/g;
    $tmp =~ s/$NAMES[0]/$NAMES[1]/g;
    $tmp =~ s/@\{DATE\}/$date/g;				# 20211128
    $tmp =~ s/@\{DAY\}/$day/g;
    $tmp =~ s/@\{MONTH\}/$month/g;
    $tmp =~ s/@\{YEAR\}/$year/g;
    $tmp =~ s/@\{YMD\}/$ymd/g;
    print($file_out $tmp);
  }
  close($file_out);
  close($file_in);
  ++$nreplacements;
}


sub uc_first {
  my $result = "";
  my @list = split("_", shift);
  foreach (@list) {
    $result = $result.ucfirst($_);
  }
  return $result;
}


sub initialize {
  @files = ();
  @names = ();
  @Names = ();
  @NAMES = ();
  @prefaces = ();
  @Prefaces = ();
  @PREFACES = ();
  $help = 0;
  $nreplacements = 0;
  
  my $ext;

  foreach(@ARGV) {
    if (substr($_,0,1) eq '-') {
      $help = 1;
    }
    else {
      push(@files, $_) if (scalar(@files)<2);
    }
  }
  if ($help || (scalar(@files)!=2))
  {
    printf("usage: cpmod [preface/]name [preface/]replacement\n\n");
    exit(-1); 
  }
  my $pop = 1;
  foreach(@files) {
    my @arg = split("/");
    $pop = 0 if (scalar(@arg)<2);
  }
  foreach(@files) {
    my @arg = split("/");
    my @a = split("\\.", pop(@arg));
    my $tmp = scalar(@a)>1 ? pop(@a) : "";
    my $name = join("\\.", @a);

    #$_ = lc($_);						# 20211128
    push(@arg, $name);
    $_ = join("/", @arg);
    $ext = $tmp if ($ext eq "");
    $ext = "pm" if ($ext eq "" && -e "$_.pm");
    push(@names, lc($name));
    push(@NAMES, uc($name));
    push(@Names, uc_first($name));
    pop(@arg) if ($pop);
    push(@includes, lc(join("/", @arg)));			# 20200606
    push(@prefaces, lc(join("_", @arg)));
    push(@PREFACES, uc(join("_", @arg)));
    foreach(@arg) { $_ = uc_first($_); }
    push(@Prefaces, join($ext eq "pm" ? "::" : "", @arg));
  }
}


# main

  initialize();
  replace(".h") if (-e "@files[0].h");
  replace(".c") if (-e "@files[0].c");
  replace(".cpp") if (-e "@files[0].cpp");
  replace(".sh") if (-e "@files[0].sh");			# 20180208
  replace(".pm") if (-e "@files[0].pm");			# 20211128
  replace(".txi") if (-e "@files[0].txi");			# 20220314
  replace(".define") if (-e "@files[0].define");		# 20230307
  
  print("copied $nreplacements file", $nreplacements==1 ? "" : "s", "\n");

