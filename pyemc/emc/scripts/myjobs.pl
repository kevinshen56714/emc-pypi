#!/usr/bin/env perl
#
#  program:	myjobs.pl
#  author:	Pieter J. in 't Veld
#  date:	July 8, October 16, 2013, March 12, 2014, February 17, 
#  		October 15, December 17, 2017, January 18, February 25,
#  		April 13, June 5, 2018
#  purpose:	wrapper for LSF bjobs and PBS qstat; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20130708	Inception for LSF functionality
#    20171015	Addition of PBS qstat functionality
#    20171217	Added -file and -h[ome] options
#		Added automatic users home directory detection
#    20180118	Added preselection of user jobs for PBS qstat
#    20180225	Moved progress to main section and generalized interpretation
#    		to file name or extension
#    20180413	Refined -p[rogress] to ignore value when missing
#    20180605	Added interpretation of workdirs and progress for packed runs
#    		Added -f[ull] flag for invoking -name, -progress, and -wd
#    		options
#    		Repurposed -f to -full instead of -file
#

use File::Basename;

$Year = "2018";
$Copyright = "2004-$Year";
$Date = "June 5, $Year";
$Author = "Pieter J. in 't Veld";
$Script = basename($0);
$Version = "2.3.0";

use Time::Local;
use Scalar::Util qw(looks_like_number);

$Time = time;

# functions

sub myseconds {
  my %months = (
    "Jan" => 0, "Feb" => 1, "Mar" => 2, "Apr" => 3, "May" => 4, "Jun" => 5,
    "Jul" => 6, "Aug" => 7, "Sep" => 8, "Oct" => 9, "Nov" => 10, "Dec" => 11);
  my ($month, $year) = (localtime(time))[4,5];
  my @t = split(" ", @_[0]);
  return 0 if (!scalar(@t));
  shift(@t) if (!defined($months{@t[0]}));
  my ($day, $hours, $min, $sec) = (@t[1], split(":", @t[2]));
  $year -= 1 if ($months{@t[0]}-1 > $month);
  return timelocal($sec,$min,$hours,$day,$months{@t[0]},$year); 
}


sub mytime {
  my $time = shift(@_);
  my $hours = int($time/3600);
  my $minutes = int(($time -= $hours*3600)/60);
  my $seconds = $time-$minutes*60;
  return sprintf("%3d:%02d:%02d", $hours, $minutes, $seconds);
}


sub mywhich {
  my $name = @_[0];

  for my $path ( split /:/, $ENV{PATH} ) {
    if ( -f "$path/$name" && -x _ ) { return "$path/$name"; }
  }
  return "";
}


sub myexec {
  return mywhich(@_[0]) ne "" ? 1 : 0;
}


sub convert2seconds {
  my @t = split(":", @_[0]);
  return @t[2]+60*(@t[1]+60*@t[0]);
}


sub extract {
  my @arg = split(" <", @_[0]);
  @arg[-1] =~ s/>//g;
  return @arg;
}


sub div {
  return @_[1] ? @_[0]/@_[1] : @_[0];
}


sub newest {
  my $dir = shift(@_);
  my $ext = shift(@_);

  opendir (my $dh, $dir);
  my @files = sort { $b->[10] <=> $a->[10] }
      map {[ $_, CORE::stat "$dir/$_" ]}
      grep (m/$ext+$/, readdir ($dh));
  closedir $dh;
  return @{$files[0]}[0];
}


sub set_progress {
  my $job = shift(@_);
  my $wd = $Jobs{$job}->{"wd"}; $wd =~ s/^~+/$Home\//g; 
  my $name = "$wd/".$Jobs{$job}->{"job_name"}.".dirs";

  if ($Jobs{$job}->{"status"} ne "RUN") {
    $Jobs{$job}->{"progress"} = ["-"];
    return;
  }
  my @dirs = -f $name ? split("\n", `cat $name`) : ($wd);
  $Jobs{$job}->{"progress"} = [];
  foreach(@dirs) {
    my @arg = ();
    $name = "$_/$ProgressName";
    $name = "$_/".newest($_, $ProgressName) if (! -f $name);
    if (-f $name) {
      my @line = split("\n", `tail -1 $name`);
      @arg = split(" ", @line[0]);
      while (scalar(@arg[0])) {
	last if (looks_like_number(@arg[0])); shift(@arg);
      }
    }
    push(@{$Jobs{$job}->{"progress"}}, scalar(@arg) ? @arg[0] : "-");
  }
}


sub set_workdir {
  my $job = shift(@_);
  my $wd = $Jobs{$job}->{"wd"}; $wd =~ s/^~+/$Home\//g; 
  my $name = "$wd/".$Jobs{$job}->{"job_name"}.".dirs";

  $Jobs{$job}->{"workdir"} = [];
  foreach (-f $name ? split("\n", `cat $name`) : $wd) {
    $_ =~ s/^$Home\/+/~/g;
    push(@{$Jobs{$job}->{"workdir"}}, $_);
  }
}


sub data2jobs {
  my %convert = (
    "Job" => "job",
    "Job Name" => "job_name",
    "User" => "user",
    "Project" => "project",
    "Status" => "status",
    "Queue" => "queue",
    "Command" => "command",
    "Submitted" => "submit_time",
    "Submitted from host" => "host",
    "CWD" => "wd",
    "Eligible" => "eligible_time",
    "Started" => "start_time",
    "Estimated" => "start_time",
    "Pending" => "pend_time",
    "Execution Home" => "exec_home",
    "Execution CWD" => "exec_wd",
    "Resource" => "resource_time",
    "Elapsed" => "cpu_time",
    "Limit" => "limit_time",
    "Dependency Condition" => "dependency",
    "Depend" => "dependency",
    "Array" => "array",
    "Total" => "total",
    "Expired" => "expired"
  );
  my $job = -1;
  my $user = "";

  foreach (@_) {
    my @arg = extract($_);
    
    if (@arg[0] eq "Job") {
      $job = @arg[1]; 
    } elsif (@arg[0] eq "User") {
      $user = @arg[1];
    }
  }
  return if ($job<0);
  $Jobs{$job}->{"processors"} = 1;
  foreach (@_) {
    my @arg = extract($_);
    if ($convert{@arg[0]} ne "") {
      if (@arg[0] eq "CWD") {
	@arg[1] =~ s/^$Home\/$user+/~$user/ if ($Home ne "");
      }
      next if (@arg[0] eq "Estimated" && defined($Jobs{$job}->{"start_time"}));
      $Jobs{$job}->{$convert{@arg[0]}} = @arg[1];
    } else {
      @arg = split(" ", $_);
      if (join(" ", @arg[1,2]) eq "Processors Requested") {
	$Jobs{$job}->{"processors"} = @arg[0];
      }
    }
  }
  if ($Jobs{$job}->{"status"} eq "BATCH") {
    $Jobs{$job}->{"cpu_time"} = "";
    $Jobs{$job}->{"processors"} = $Jobs{$job}->{"array"};
    $Jobs{$job}->{"efficiency"} = int(div($Jobs{$job}->{"expired"}, $Jobs{$job}->{"total"})*1e4+0.5)/100;
  } elsif ($Jobs{$job}->{"status"} eq "RUN") {
    my $start = $Jobs{$job}->{"start_time"};
    my $eligible = $Jobs{$job}->{"eligible_time"};
    my $runtime = $Time-myseconds($start eq "" ? $eligible : $start);
    $runtime = 0 if ($runtime<0);
    my $cputime = $Jobs{$job}->{"cpu_time"}/$Jobs{$job}->{"processors"};
    $Jobs{$job}->{"run_time"} = mytime($runtime);
    $Jobs{$job}->{"efficiency"} = $runtime>0 ? int($cputime/$runtime*1e4+0.5)/100:0;
    if ($Jobs{$job}->{"cpu_time"} ne "") {
      $Jobs{$job}->{"cpu_time"} = mytime($cputime);
    }
  } else {
    $Jobs{$job}->{"cpu_time"} = "";
  }
  if ($Jobs{$job}->{"dependency"} ne "") {
    $Jobs{$job}->{"status"} = "CHAIN" if ($Jobs{$job}->{"status"} eq "PEND");
    $Jobs{$job}->{"status"} = "CHAIN" if ($Jobs{$job}->{"status"} eq "HOLD");
  }
  if ($Jobs{$job}->{"status"} eq "PEND") {
    if ($Jobs{$job}->{"pend_time"} ne "" ) {
      my $runtime = myseconds($Jobs{$job}->{"pend_time"})-$Time;
      $Jobs{$job}->{"run_time"} = mytime($runtime) if ($runtime>0);
    }
  }
  if ($FlagProgress) { set_progress($job); }
  set_workdir($job);
}


sub print_progress {
  return if (!scalar(keys(%Jobs)));
  foreach (sort({$a <=> $b} keys(%Jobs))) {
    my $job = $_;
    my $wd = $Jobs{$job}->{"wd"};
    my $name = "$wd/$ProgressName";
    $name =~ s/^$Home\/+/~/g; 
    printf("%s: %s\n", $name, $Jobs{$job}->{"progress"});
  }
}


sub print_jobs {
#  if ($FlagProgress) {
#    print_progress; return;
#  }

  my %format = (
    "job" => "%8.8s",
    "job_name" => "%8.8s",
    "user" => "%8.8s",
    "status" => "%6.6s",
    "queue" => "%10.10s",
    "start_time" => "%16.16s",
    "submit_time" => "%16.16s",
    "run_time" => "%10.10s ",
    "limit_time" => "%10.10s ",
    "cpu_time" => "%10.10s",
    "efficiency" => "%6.6s",
    "processors" => "%5.5s",
    "progress" => "%10.10s",
    "workdir" => "%s",
    "wd" => "%s"
  );
  my %header = (
    "job" => "job",
    "job_name" => "job_name",
    "user" => "user",
    "status" => "status",
    "queue" => "queue",
    "start_time" => "start/submit",
    "submit_time" => "submit",
    "limit_time" => "limit",
    "run_time" => "run/start",
    "cpu_time" => "cpu",
    "efficiency" => "effect",
    "processors" => "nproc",
    "progress" => "progress",
    "workdir" => "workdir",
    "wd" => "workdir"
  );
  my @index = (
    "job", "user", "status");
  my $separator = "  ";
  my $next = "";
  my %total = ("CHAIN" => 0, "PEND" => 0, "RUN" => 0);
 
  return if (!scalar(keys(%Jobs)));
  push(@index, "queue") if ($FlagQueue);
  push(@index, "job_name") if ($FlagName);
  push(@index, "start_time") if ($FlagStart);
  push(@index, "limit_time") if ($FlagLimit);
  push(@index, "run_time") if ($FlagRun);
  push(@index, ("cpu_time", "efficiency")) if ($FlagCpu);
  push(@index, "processors");
  push(@index, "progress") if ($FlagProgress);
  push(@index, "workdir") if ($FlagWD);
  foreach (@index) {
    printf($next.$format{$_}, uc($header{$_}));
    $next = $separator;
  }
  print("\n");
  foreach (sort({$a <=> $b} keys(%Jobs))) {
    my $job = $_;
    my $nlines = $FlagProgress||$FlagWD ? scalar(@{$Jobs{$job}->{"workdir"}}):1;
    my $i;

    next if ($FlagUser && $Jobs{$job}->{"user"} ne $User);
   
    for ($i=0; $i<$nlines; ++$i) {
      $next = "";
      foreach (@index) {
	my $id = $_;
	if ($_ eq "start_time") {
	  if ($Jobs{$job}->{"start_time"} eq "") {
	    $id = "submit_time";
	  }
	}
	my $text = $Jobs{$job}->{$id};
	if ($id eq "progress" || $id eq "workdir") {
	  $text = @{$text}[$i];
	} else {
	  $text = " " if ($i);
	}
	printf($next.$format{$_}, $text eq "" ? "-" : $text);
	$next = $separator;
      }
      print("\n");
    }
    $total{$Jobs{$job}->{"status"}} += $Jobs{$job}->{"processors"};
  }
  my @arg = ();
  foreach (sort(keys(%total))) {
    push(@arg, sprintf("%6.6s:\t%6d", $_, $total{$_}));
  }
  printf("\n%s\n", join("\t", @arg));
}


sub lsf_create_jobs {
  my $tmp;
  my $mode = 0;
  my $limit = 0;
  my $first = 1;
  my $empty = "                     ";
  my @data, $time, $rest;

  foreach (@_) {
    $_ =~ s/;//g;
    $_ =~ s/$empty//g if (($flag = (substr($_,0,length($empty)) eq $empty)));
    my @arg = split(", ");
    @arg[-1] .= "," if (substr($_,-2,2) eq ", ");
    if (!$flag) {
      my @id = split(" ", @arg[0]);
      if (@id[0] eq "Job") {
	next if (substr($_,0,1) eq " ");
	@data = @arg;
	$mode = 1; next;
      }
      if (scalar(@id = split(": ", @arg[0]))>1) {
	$time = substr($tmp = @id[0], 4);
	@id = split(" ", $rest = @id[1]); shift(@arg);
	if (@id[0] eq "Submitted") {
	  $mode = 2; push(@data, "Submitted <$time>", $rest, @arg); next;
	} elsif (@id[0] eq "Started") {
	  $mode = 3; push(@data, "Started <$time>", $rest, @arg); next;
	} elsif (@id[0] eq "Resource") {
	  $mode = 4; push(@data, "Resource <$time>", @arg); next;
	} elsif (join(" ", @id[0,1,2]) eq "Estimated job start" ||
		 join(" ", @id[0,1,2]) eq "Job will start") {
	  $mode = 4; push(@data, "Pending <$time>", @arg); next;
	}

      }
      @id = split(" ");
      if (@id[0] eq "RUNLIMIT") {
	$mode = 5; next;
      }
      if (@id[0] eq "SCHEDULING") {
	$first = 1;
	push(@data, sprintf("Limit <%s>", mytime(24*3600))) if (!$limit);
	data2jobs(@data);
	@data = (); $mode = 0; $limit = 0;
      }
      next if (!$mode);
    }
    if ($mode == 1 || $mode == 2 || $mode == 3) {
      if (substr(@data[-1],-1,1) eq ",") {
	@data[-1] =~ s/,//g;
      } else {
	@data[-1] .= (split($empty, shift(@arg)))[0];
      }
      while (substr(@arg[0],0,1) eq " ") {
	@arg[0] = substr(@arg[0],1,length(@arg[0]));
      }
      push(@data, @arg);
    } elsif ($mode == 4) {
      my @arg = split(" ");
      if (@arg[1] eq "CPU") {
	push(@data, sprintf("Elapsed <%s>", @arg[5]));
      }
      $mode = 0;
    } elsif ($mode == 5) {
      my @arg = split(" ");
      push(@data, sprintf("Limit <%s>", mytime($limit = @arg[0]*60)));
      $mode = 0;
    }
  }
  return 1;
}


sub pbs_create_jobs {
  my @data;
  my $value;
  my $id;
  my $tab;
  my $indent = "    ";
  my %ids = (
    "Job Id:" => "Job",
    "Job_Name" => "Job Name",
    "Account_Name" => "User",
    "project" => "Project",	# no eqv
    "job_state" => "Status",
    "queue" => "Queue",
    "Submit_arguments" => "Command",	# no eqv
    "qtime" => "Submitted",
    "PBS_O_HOST" => "Submitted from host",
    "PBS_O_WORKDIR" => "CWD",
    "stime" => "Started",
    "etime" => "Eligible",
    "estimated.start_time" => "Estimated",
    #"" => "Pending",
    #"" => "Execution Home",
    #"" => "Execution CWD",
    #"" => "Resource",
    "Variable_List" => "Environment",
    "resources_used.cput" => "Elapsed",
    "resources_used.ncpus" => "Processors Requested",
    "Resource_List.ncpus" => "Processors Requested",
    "Resource_List.walltime" => "Limit",
    "depend" => "Dependency Condition",
    "server" => "Server",
    "depend" => "Depend",
    "array_state_count" => "Array"
  );
  my %status = (
    "B" => "BATCH",
    "E" => "EXIT",
    "H" => "PEND",
    "Q" => "QUEUE",
    "R" => "RUN",
    "S" => "SUSPEND",
    "T" => "TRANSIT",
    "W" => "WAIT"
  );
  my $elapsed = -1;

  foreach (@_) {
    if ($_ eq "") {
      push(@data, "$id <$value>") if ($id ne "");
      #print("@data[0]\n"); foreach (@data) { print("  $_\n"); }
      push(@data, "Elapsed <0>") if ($elapsed<0);
      data2jobs(@data); @data = ();
      $elapsed = -1;
      next;
    }
    $tab = substr($_,0,1) eq "\t" ? 1 : 0;
    if (substr($_,0,4) ne $indent && !$tab) {
      my @a = split(" ");					# job id
      my $id = (split("\\.", @a[-1]))[0];
      push(@data, sprintf("Job <%s>", (split("\\[\\]", $id))[0]));
    } else {
      if (substr($_,4,4) ne $indent && !$tab) {
	if ($id ne "") {
	  if ($id ne "Environment") {
	    push(@data, "$id <$value>");			# all others
	  } else {
	    foreach(split(",", $value)) {			# environment
	      my @a = split("=");
	      next if (!defined($ids{@a[0]}));
	      push(@data, "$ids{@a[0]} <@a[1]>");
	    }
	  }
	}
	$id = $value = "";
	my @a = split(" = ");
	@a[0] =~ s/^\s+|\s+$//g;
	next if (!defined($ids{@a[0]}));
	$id = $ids{@a[0]};					# set id, value
	if ($id eq "Status") {
	  $value = $status{@a[1]};
	  $value = @a[1] if ($value eq "");
	} elsif ($id eq "Array") {
	  my @n = (0);
	  foreach (split(" ", @a[1])) {
	    push(@n, (split(":"))[1]);
	    @n[0] += @n[-1];
	  }
	  $value = @n[2];
	  push(@data, "Total <@n[0]>");
	  push(@data, "Expired <@n[-1]>");
	} elsif ($id eq "Elapsed") {
	  $value = $elapsed = convert2seconds(@a[1]);
	} elsif ($id eq "Processors Requested") {
	  push(@data, "@a[1] $id"); $id = $value = "";
	} else {
	  $value = @a[1];
	}
      } else {
	$value .= substr($_,$tab ? 1 : 8);			# append
      }
    }
  }
  push(@data, "$id <$value>") if ($id ne "");
  data2jobs(@data); @data = ();
  return 1;
}


sub create_jobs {
  if ($FlagFile) {
    return pbs_create_jobs(split("\n", `cat $FileName`));
  } elsif (myexec('bjobs')) {
    return lsf_create_jobs(split("\n", `bjobs -l @_`));
  } elsif (myexec('qstat')) {
    return $FlagUser ?
      pbs_create_jobs(split("\n", `qstat -f \$(qselect -u $User)`)) :
      pbs_create_jobs(split("\n", `qstat -f`));
  } else {
    print("Error: could not determine queuing system\n\n");
  }
  return 0;
}


$FlagCpu = 1;
$FlagFull = 0;
$FlagLimit = 1;
$FlagName = 0;
$FlagProgress = 0;
$FlagQueue = 0;
$FlagRun = 1;
$FlagStart = 0;
$FlagWD = 0;
$ProgressName = ".out";
$FlagFile = 0;
$FileName = "";
$FlagHome = 0;
$Home = "";

sub help {
  print("LSF/PBS job query v$Version ($Date), (c) $Copyright $Author\n\n");
  print("Usage:\n");
  print("  $Script [-option [#]] [bjobs or qstat options ...]\n\n");
  print("Options:\n");
  print("  -h[elp]\tthis message\n");
  print("  -cpu\t\tshow processor usage [$FlagCpu]\n");
  print("  -file\t\tuse file as input [$FileName]\n");
  print("  -f[ull]\tadd -name, -progress, and -wd [$FlagFull]\n");
  print("  -limit\tshow run time limit [$FlagLimit]\n");
  print("  -name\t\tshow job name [$FlagName]\n");
  print("  -p[rogress]\tshow progress in work directories [$ProgressName]\n");
  print("  -queue\tshow job queue [$FlagQueue]\n");
  print("  -run\t\tshow run time [$FlagRun]\n");
  print("  -start\tshow start time [$FlagStart]\n");
  print("  -u[ser]\tset a specific user; use 'all' for all users [$User]\n");
  print("  -v[ersion]\twrite out script version information\n");
  print("  -wd\t\tshow work directory [$FlagWD]\n");
  print("\nNotes:\n");
  print("  - Columns are omitted when option starts with 'no'\n");
  print("  - A file name or extension follows the progress option\n");
  print("  - Progress shows the first number in the last line of the indicated file\n");
  print("\n");
  exit;
}


sub init {
  my @args = @_;
  my @command = ();
  my $i;

  $FlagUser = 1;
  $User = $ENV{USER};
  $Home = $ENV{HOME};
  $Home =~ s/\/$User+$//;
  while (scalar(@args)) {
    my $arg = shift(@args);
    if ($arg eq "-h" || $arg eq "-help") { help; }
    elsif ($arg eq "-cpu") { $FlagCpu = 1; }
    elsif ($arg eq "-full" || $arg eq "-f") { 
      $FlagFull = $FlagName = $FlagProgress = $FlagWD = 1; }
    elsif ($arg eq "-file") {
      $FlagFile = 1; $FileName = shift(@args); }
    elsif ($arg eq "-h" || $arg eq "-home") {
      $FlagHome = 1; $Home = shift(@args); }
    elsif ($arg eq "-limit") { $FlagLimit = 1; }
    elsif ($arg eq "-name") { $FlagName = 1; }
    elsif ($arg eq "-nocpu") { $FlagCpu = 0; }
    elsif ($arg eq "-nolimit") { $FlagLimit = 0; }
    elsif ($arg eq "-noname") { $FlagName = 0; }
    elsif ($arg eq "-noqueue") { $FlagQueue = 0; }
    elsif ($arg eq "-norun") { $FlagRun = 0; }
    elsif ($arg eq "-nostart") { $FlagStart = 0; }
    elsif ($arg eq "-nowd") { $FlagWD = 0; }
    elsif ($arg eq "-p" || $arg eq "-progress") {
      $FlagProgress = 1; 
      if (length(@arg[0]) && substr(@arg[0],0,1) ne "-") {
	$ProgressName = shift(@args) 
      }; }
    elsif ($arg eq "-queue") { $FlagQueue = 1; }
    elsif ($arg eq "-run") { $FlagRun = 1; }
    elsif ($arg eq "-start") { $FlagStart = 1; }
    elsif ($arg eq "-u" || $arg eq "-user") { 
      $User = shift(@args); 
      $FlagUser = $User eq "all" ? 0 : 1;
    }
    elsif ($arg eq "-v" || $arg eq "-version") { 
      print("LSF/PBS job query wrapper, v$Version, $Date\n");
      print("Copyright (C) $Copyright $Author\n");
      exit();
    }
    elsif ($arg eq "-wd") { $FlagWD = 1; }
    else { push(@command, $arg); }
  }
  return @command;
}


# main

{
  print_jobs if (create_jobs(init(@ARGV)));
}

