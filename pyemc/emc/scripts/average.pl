#!/usr/bin/env perl
#
#  program:	average.pl
#  author:	Pieter J. in 't Veld
#  date:	August 22, 2011, April 23, 2014, May 27, June 15, 2016,
#  		May 18, 2017, December 15, 2018, September 25, 2020.
#  purpose:	Average EMC and LAMMPS output (including ave/time); part of
#  		EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20110822	Conception
#    20160826	Adaptation to profiles using LAMMPS chunk
#    20170518	Correction for use of -nskip
#    20181215	Added exclusion of null vector in average
#    20200925	Correction for use of -nskip with profiles
#    		Change of x-coordinate to third from back for profiles
#

# initial settings

$null = 1;
$info = 1;
$debug = 0;
$nskip = 0;
$nwindow = 1;
$program = "average.pl";
$version = "1.5";
$date = "September 25, 2020";
$header = "EMC and LAMMPS averaging v$version, $date";


# functions

sub error {
  printf("Error: %s.\n\n", join(" ", @_));
  exit(-1);
}


sub debug {
  return if (!$debug);
  my @arg = @_;
  @arg[0] = "Debug: ".@arg[0];
  printf(@arg);
}


sub info {
  return if (!$info);
  my @arg = @_;
  @arg[0] = "Info: ".@arg[0];
  printf(@arg);
}


sub help {					# script help
  print("$header\n\n");
  print("Usage:\n  $program [-option=#] file ...\n\n");
  print("Commands:\n");
  print("  -help\t\tthis message\n");
  print("  -debug\tselect debug output [$debug]\n");
  print("  -info\t\tselect info output [$info]\n");
  print("  -null\t\tinclude null vector in average [$null]\n");
  print("  -out\t\tset output file [\"\"]\n");
  print("  -quiet\tsuppress info and header output\n");
  print("  -skip\t\tset number of frames to skip [$nskip]\n");
  print("  -window\tset number of frames in averaging window [$nwindow]\n");
  print("\n");
  exit();
}


sub init {					# script initialization
  foreach (@_) {
    my @arg = split("=");
    my $id = shift(@arg);
    @arg = split(",", join("=", @arg));
    my $n = scalar(@arg);
    if ($id eq "-debug") { $debug = $n ? ($arg[0] ? 1 : 0) : 1; }
    elsif ($id eq "-help") { help(); }
    elsif ($id eq "-info") { $info = $n ? ($arg[0] ? 1 : 0) : 1; }
    elsif ($id eq "-null") { $null = $n ? ($arg[0] ? 1 : 0) : 1; }
    elsif ($id eq "-out") { $out = $arg[0] if ($n>0); }
    elsif ($id eq "-quiet") { $info = 0; $quiet = 1; }
    elsif ($id eq "-skip") { $nskip = $arg[0] if ($n>0); }
    elsif ($id eq "-window") { $nwindow = $arg[0] if ($n>0); }
    elsif (substr($id,0,1) eq "-") { error("unknown command \'$id\'"); }
    else { push(@files, $id); }
    shift(@ARGV) if (substr($id,0,1) eq "-");
  }
  help() if (!scalar(@files));
  print("$header\n\n") if (!$quiet);
}


sub scan {					# determine averaging mode
  my $head = 2;
  my @tmp = @files;

  $mode = -1;
  foreach (@tmp) {
    my $name = $_;
    info("scanning $name\n");
    open($file, "<$name");
    my $first = 1;
    my $timestep = -1;
    while (<$file>) {
      chop;
      my @arg = split(" ");
      if ($first) {
	my $local = -1;
	if ($arg[1] eq "Time-averaged") { $local = 0; }
	elsif ($arg[1] eq "Spatial-averaged") { $local = 1; }
	elsif ($arg[1] eq "Chunk-averaged") { $local = 1; }
	elsif ($arg[0] eq "LAMMPS") { $local = 3; }
	elsif ("$arg[1] $arg[2]" eq "EMC: Enhanced") { $local = 3; }
	$mode = $local if ($mode<0);
	error("unrecognized format in \"$name\"") if ($local<0);
	error("non-matching modes ($mode != $local)") if ($mode != $local);
	$first = 0;
      }	elsif ($mode == 0) {
	$mode = 2 if ($arg[2] eq "Number-of-rows");
      }
      next if ($arg[0] eq "#");
      $timestep = $arg[0];
      last;
    }
    push(@end, $timestep);
    close($file);
  }
  shift(@end);
  push(@end, -1);
  info("mode = $mode\n");
  info("ends = {%s}\n", join(", ", @end)) if ($mode<3);
  info("files = {%s}\n", join(", ", @files));
}


# averaging

sub process {					# process LAMMPS ave/...
  my $nsum = 0;
  my @sum = ();
  my @tmp = @files;
 
  error("output name not set") if ($out eq "");
  open($outfile, ">$out");
  foreach (@tmp) {
    my $name = $_;
    info("reading $name\n");
    open($file, "<$name");
    my $last = shift(@end);
    while (<$file>) {
      chop;
      my @arg = split(" ");
      next if (substr($arg[0],0,1) eq "#");
      next if (scalar(@arg)<2);
      if ($nskip) {
	--$nskip;
	my $i = 0;
	my $n = $arg[1];
	info("skipping timestep %d\n", $arg[0]);
	while (<$file>) {
	  last if (++$i>=$n);
	}
	next;
      }
      if ($mode == 1) {
	my $i = 0;
	my $n = $arg[1];
	my @xdata = ();
	my @ydata = ();
	info("processing time step %d\n", $arg[0]);
	if ($n) {
	  while (<$file>) {
	    chop;
	    my @arg = split(" ");
	    push(@xdata, @arg[-3]);
	    push(@ydata, @arg[-1]);
	    last if (++$i>=$n);
	  }
	  @arg = (@arg[0,1], @xdata[0], @xdata[1]-@xdata[0], @ydata);
	}
	else {
	  @arg = (@arg[0,1], 0, 0);
	}
      } elsif ($mode == 2) {
	my $i = 0;
	my $n = $arg[1];
	my @avg = (0);
	info("processing time step %d\n", $arg[0]);
	if ($n) {
	  my $count = 0;
	  while (<$file>) {
	    chop;
	    my $k = 0;
	    my @arg = split(" "); shift(@arg);
	    my $flag = 0;
	    foreach (@arg) { @avg[$k++] += $_; $flag = 1 if ($_!=0.0); }
	    ++$count if ($null ? 1 : $flag);
	    last if (++$i>=$n);
	  }
	  foreach (@avg) { $_ /= $count ? $count : 1; }
	  $arg[1] = $count;
	}
	@arg = (@arg, @avg);
      }
      next if (($last>=0) && ($arg[0]>=$last));
      $i = 0; foreach(@arg) { $sum[$i++] += $_ };
      next if (++$nsum<$nwindow);
      foreach(@sum) { $_ /= $nsum }; 
      printf($outfile "%s\n", join(", ", @sum));
      @sum = (); $nsum = 0;
    }
    close($file);
  }
  close($outfile);
  print("\n");
}


sub reset_avg {					# reset averages
  $n=0;
  @acc=();
  @acc2=();
}


sub add_avg {					# add sample to averages
  my $i; 
  my $flag = 0;
  
  for ($i=0; $i<scalar(@_); ++$i) {
    $acc[$i] += @_[$i];
    $acc2[$i] += @_[$i]*@_[$i];
    $flag = 1 if (@_[$_]!=0.0);
  }
  ++$n if ($null ? 1 : $flag);
}


sub output {					# output averages
  @hdr=@header;
  if (($hdr[0] eq "Step")||($hdr[0] eq "TimeStep")||($hdr[0] eq "Time")) {
    shift(@hdr); shift(@acc); shift(@acc2);
  }
  $n=1 if (!$n);
  printf("\nSAMPLES = %d\n", $n);
  if (scalar(@hdr)) {
    printf("%6.6s", "");
    foreach (@hdr) {
      my @arg=split("_"); printf(" %10.10s", $arg[-1]); 
    }
    printf("\n");
  }
  printf("%6.6s", "AVG");
  foreach (@acc) { printf(" %10.3e", $_/$n); }
  printf("\n%6.6s", "STDDEV");
  for ($i=0; $i<scalar(@acc); ++$i) {
    my $x= $n>1 ? ($acc2[$i]-$acc[$i]*$acc[$i]/$n)/($n-1) : 0.0;
    $x=0.0 if ($x<0);
    printf(" %10.3e", sqrt($x)); }
  printf("\n");
  reset_avg();
}


# main

  init(@ARGV);
  scan();

  if ($mode<3 && $out ne "") {			# process LAMMPS fix ave/...
    process();
    exit();
  }

  @a = ();					# process EMC and LAMMPS output
  @arg = ();
  @header = ("Step");
  $flag_header = 1;
  foreach (<>) {
    chop;
    if (!$read) {				# determine read mode
      @a = split(" ");
      shift(@a) if (@a[0] eq "#");
      $read = 1 if (@a[0] eq "Time" && join(" ", @a[0,1,2]) ne "Time step :");
      $read = 1 if (@a[0] eq "Step");
      $read = 1 if (@a[0] eq "TimeStep");
      $read = 1 if (@a[0] eq "cycle");
      $nskip += 1 if (@a[0] eq "cycle");
      @header = @a if ($read==1);
      $read = 2 if (join(" ", @a[0,1]) eq "# Time");
      next if (join(" ", @a[0,1]) ne "---------------- Step");
      $flag_header = 1;
      @header = ();
      @arg = ();
      $step = @a[2];
      $read = 3;
      next;
    }
    if ($read<3) {				# EMC and LAMMPS single styles
      if (!$nskip && $n && (substr($_,0,4) eq "Loop" ||
	  substr($_,0,10) eq "----------" ||
	  substr($_,0,7) eq "average" ||
	  substr($_,0,7) eq "mpiexec" ||
	  substr($_,0,5) eq "ERROR" )) {
	$read = 0;
	output();
	next;
      }
      if (substr($_,0,1) eq "#") {
	@header=split(" "); shift(@header); next;
      }
      if (substr($_,0,4) eq "Step" ||
	  substr($_,8,5) eq "cycle") {
	reset_avg();
	next;
      }
      if ($nskip) { --$nskip; next; }
      add_avg(split(" "));
    } else {					# LAMMPS multi style
      @a = split(" ");
      if (join(" ", @a[0,1]) ne "---------------- Step" && @a[0] ne "Loop") {
	while (scalar(@a)) {
	  push(@header, @a[0]) if ($flag_header); shift(@a); shift(@a);
	  push(@arg, shift(@a));
	}
	next;
      }
      add_avg(@arg); $flag_header = 0; @arg = ();
      next if (@a[0] ne "Loop" && @a[0] ne "mpiexec" && @a[0] ne "average");
      $read = 0; output();
    }
  }
  output if ($read);
  print("\n");

