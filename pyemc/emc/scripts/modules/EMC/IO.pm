#!/usr/bin/env perl
#
#  module:	EMC::IO.pm
#  author:	Pieter J. in 't Veld
#  date:	November 24, 2021, February 12, 2022.
#  purpose:	IO routines; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211124	Inception of v1.0
#    20220213	Addition of data routines
#

package EMC::IO;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use File::Basename;
use File::Find;
use File::Path;
use IO::Compress::Gzip;
use IO::Uncompress::Gunzip;
use EMC::Message;


# functions

sub expand {
  return @_[0] if (substr(@_[0],0,1) ne "~");
  return $ENV{HOME}.substr(@_[0],1) if (substr(@_[0],1,1) eq "/");
  return $ENV{HOME}."/../".substr(@_[0],1);
}


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


sub path_append {
  my $array = shift(@_);
  my @set = @_;
  my %exist;

  foreach (@{$array}) {
    $_ = scrub_dir($_);
    $exist{$_} = 1;
  }
  foreach (@set) {
    $_ = scrub_dir($_);
    next if (defined($exist{$_}));
    push(@{$array}, $_) if (-d fexpand($_));
  }
}


sub path_prepend {
  my $array = shift(@_);
  my @set = @_;
  my %exist;

  foreach (@{$array}) {
    $_ = scrub_dir($_);
    $exist{$_} = 1;
  }
  foreach (@set) {
    $_ = scrub_dir($_);
    next if (defined($exist{$_}));
    unshift(@{$array}, $_) if (-d fexpand($_));
  }
}


# i/o routines

sub exist {
  my $name = expand(shift(@_));

  return 1 if (-f $name);
  foreach (@_) { return 1 if (-f $name.$_); }
  return 0;
}


sub locate {
  my $name = shift(@_);
  my @ext = ("", shift(@_));

  foreach ("", @_) {
    my $root = ($_ eq "" ? "" : $_."/").$name;
    foreach (@ext) {
      my $file = $root.$_;
      return $file if (-f fexpand($file));
    }
  }
  return "";
}


sub find {
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


sub open {
  my $name = expand(shift(@_));
  my $mode = shift(@_);
  my @modes = split("", $mode);
  my @ext = @_;
  my $compress = 0;
  my $error = 0;
  my $stream;
  
  if (substr($name,-3) eq ".gz") {
    $name = substr($name, 0, length($name)-3);
    push(@modes, "z");
  }
  my %tmp; foreach (@modes) { $tmp{$_} = 1; }
  $mode = join("", sort(keys(%tmp)));
  if ($mode eq "r") {
    if ($name eq "-") {
      $stream = *STDIN;
    } else {
      open($stream, "<", $name);
      if (!scalar(stat($stream))) {
	foreach (@ext) {
	  next if (! -f $name.$_);
	  open($stream, "<", $name .= $_);
	  last;
	}
      }
    }
  } elsif ($mode eq "w") {
    if ($name eq "-") {
      $stream = *STDOUT;
    } else {
      open($stream, ">", $name);
    }
  } elsif ($mode eq "a") {
    if ($name eq "-") {
      $stream = *STDOUT;
    } else {
      open($stream, ">>", $name);
    }
  } elsif ($mode eq "rz") {
    $compress = 1;
    $name = $name.".gz" if (-e $name.".gz");
    $stream = new IO::Uncompress::Gunzip($name) or $error = 1;
  } elsif ($mode eq "wz") {
    $compress = 1;
    $name = $name.".gz";
    $stream = new IO::Compress::Gzip($name) or $error = 1;
  } else {
    EMC::Message::error("unsupported mode \"$mode\"\n");
  }
  if ($compress ? $error : !scalar(stat($stream))) {
    EMC::Message::error("cannot open \"$name\"\n");
  }
  return scalar(@ext) ? ($stream, $name) : $stream;
}


sub close {
  my $stream = shift(@_);
  my $name = shift(@_);

  if (defined($name)) {
    return if ($name eq "-");
  }
  close($stream);
}


# import

sub get_data_quick {
  my $stream = shift(@_);
  my $data = shift(@_);
  my $line = 0;
  my $verbatim;

  @{$data} = ();
  foreach(<$stream>) {
    chomp();
    my @arg = split("\r");
    ++$line if (!scalar(@arg));
    foreach(@arg) {
      ++$line;
      chomp();

      my @a = split("\t");
      @a = split(",") if (scalar(@a)<2);
      push(@{$data}, {line => $line, verbatim => $_, data => [@a]})
    }
  }
  return $data;
}


sub get_data {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(@_);
  my $data = EMC::Common::element($attr, "data");
  my $preprocess = EMC::Common::element($attr, "preprocess");
  my $comment = EMC::Common::element($attr, "comment");
  my $ncomment = 0;
  my $line = 0;
  my $verbatim;
  my $first;
  my @last;
  my @a;
  my $i;

  $comment = 0 if ($preprocess);
  if (defined($data)) {
    @{$data} = ();
  } else {
    $data = [];
  }
  foreach(<$stream>) {
    chomp();
    my @arg = split("\r");
    ++$line if (!scalar(@arg));
    foreach(@arg) {
      ++$line;

      # commenting with /* */

      my $h = $_;
      my $fh = 0;
      my $lcomment = $ncomment;
      while (($i = rindex($h, "/*"))>=0) {
	$h = substr($h, 0, $i); ++$ncomment; $fh = 1;
      }

      my $t = $_;
      my $ft = 0;
      while (($i = index($t, "*/"))>=0) {
	$t = substr($t, $i+2); --$ncomment; $ft = 1;
      };
      error_line($line, "unmatched comment delimitor\n") if ($ncomment<0);
      
      if ($fh || $ft) {
	if ($lcomment) { $_ = ""; }
	elsif ($fh) { $_ = $h; }
	$_ .= $t if ($ft);
      }
      if ($comment) {
	next if (($_ = EMC::Common::trim($_)) eq "");
	next if (substr($_,0,1) eq "#");
      }
      next if ($lcomment==$ncomment ? $ncomment : 0);

      # record

      $verbatim .= (length($verbatim) ? "\n" : "").$_;
      if (!$comment && substr(EMC::Common::trim($_),0,1) eq "#") {
	@a = ($_);
      } else {
	@a = split_data($_); next if (!scalar(@a));
      }
      if (substr(@a[-1],-1) eq "&" || substr(@a[-1],-1) eq "\\") {
	if (length(@a[-1])==1) {
	  delete(@a[-1]);
       	}
	else { 
	  @a[-1] = substr(@a[-1],0,length(@a[-1])-1);
       	}
	@a[-1] = EMC::Common::trim(@a[-1]);
	$first = $line if (!defined($first));
	push(@last, @a); next;
      }
      push(@{$data}, {
	  line => defined($first) ? $first : $line,
	  verbatim => $verbatim, data => [@last, @a]});
      undef($verbatim);
      undef($first);
      undef(@last)
    }
  }
  $data = preprocess_data($data) if ($preprocess);
  #$::EMC::Flag{comment} = $ncomment;
  return $data;
}


sub split_data {
  my $s = @_[0]; $s =~ s/^\s+|\s+$//g;
  my @arg = split(",", $s);
  my @result = ();
  my @i = map({index(@arg[0],$_)} (":","="));

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


sub preprocess_data {
  my $data = shift(@_);
  my $command = "gcc -x c -E -o - -";
  my %allow = (if => 1, elif => 1, else => 1, define => 1, endif => 1);
  my ($child_in, $child_out, $child_err);
  my $pid = open3($child_in, $child_out, $child_err, $command);

  if (!$pid) {
    EMC::Message::warning("could not open gcc for preprocessing\n");
    return $data;
  }
  my $result = [];
  my $last = 1;
  my $line = 0;
  my @stored;

  # pipe into gcc

  foreach (@{$data}) {
    my $s = $_->{verbatim}; $s =~ s/&\n/\\\n/g;
    my $l = $_->{line};
    my @a = split(" ", $s);

    @stored[$l] = $_;
    for (my $i=$last+1; $i<$l; ++$i) {
      print($child_in "\n");
    }
    $s = "" if (substr($s,0,1) eq "#" && !defined($allow{substr(@a[0],1)}));
    print($child_in "$s\n");
    $last = $l+($s =~ tr/\n//);
  }
  close($child_in);

  # collect from pipe

  foreach (<$child_out>) {
    chomp();
    if (substr($_,0,1) eq "#") {
      $line = (split(" "))[1]-1;
      next;
    } else {
      ++$line;
    }
    if ($_ =~ m/\<stdin\>/) {
      error($_);
    }
    next if ($_ eq "");
    my $h = @stored[$line];
    my $d = $_;
    my $v = $h->{verbatim}; $v =~ s/&\n/\n/g; $v =~ s/\\\n/\n/g;
    my $sd = $h->{data};
    if (join(" ", split(" ", $v)) ne join(" ", split(" ", $d))) {
      push(
	@{$result}, {line => $line, verbatim => $d, data => [split_data($d)]});
    } else {
      push(
	@{$result}, {line => $line, verbatim => $h->{verbatim}, data => $sd});
    }
  }

  # close resources

  close($child_out);
  return $result;
}

