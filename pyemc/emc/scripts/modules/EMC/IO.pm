#!/usr/bin/env perl
#
#  module:	EMC::IO.pm
#  author:	Pieter J. in 't Veld
#  date:	November 24, 2021, February 12, September 26, 2022.
#  purpose:	IO routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  general members:
#    commands		HASH	structure commands
#
#    identity		HASH
#      author		STRING	module author
#      date		STRING	latest modification date
#      version		STRING	module version
#
#    set		HASH
#      commands		FUNC	commands initialization
#      defaults		FUNC	defaults initialization
#      options		FUNC	options interpretation
#      flag		HASH	control flags
#        indicator	BOOLEAN	include "io_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20211124	Inception of v1.0
#    20220213	Addition of data routines
#    20220926	Addition of commands
#    20240324	Change to v2.0
#    		Addition of #include to preprocessing
#

package EMC::IO;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "2.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use File::Basename;
use File::Find;
use File::Path;
use IO::Compress::Gzip;
use IO::Uncompress::Gunzip;
use IPC::Open3;
use EMC::Common;
use EMC::Message;


# defaults

$EMC::IO::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "March 24, 2024",
  version	=> $VERSION
};


# construct

sub construct {
  my $io = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($io, $attr);
  set_defaults($io);
  set_commands($io);
  return $io;
}


# initialization

sub set_defaults {
  my $io = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $io->{context} = EMC::Common::attributes(
    EMC::Common::hash($io, "context"),
    {
      dummy		=> 0
    }
  );
  $io->{flag} = EMC::Common::attributes(
    EMC::Common::hash($io, "flag"),
    {
      dummy		=> 0
    }
  );
  $io->{identity} = EMC::Common::attributes(
    EMC::Common::hash($io, "identity"),
    $EMC::IO::Identity
  );
  return $io;
}


sub transfer {
  my $io = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($io, "flag");
  my $context = EMC::Common::element($io, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::IO{dummy},		\$context->{dummy}],
  );
}


sub set_context {
  my $io = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($io, "flag");
  my $context = EMC::Common::element($io, "context");
}


sub set_commands {
  my $io = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($io, "set");
  my $context = EMC::Common::element($io, "context");
  my $flag = EMC::Common::element($io, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated = $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "io_" : "";

  $io->{commands} = EMC::Common::hash($io, "commands");
  while (0) {
    my $commands = {
      $indicator."dummy"	=> {
	comment		=> "dummy description",
	set		=> \&EMC::IO::set_options,
	default		=> $io->{flag}->{dummy}
      }
    };

    if ($flag_depricated) {
      foreach (keys(%{$commands})) {
	$commands->{$_}->{original} = $pre.$_;
      }
    }
    $io->{commands} = EMC::Common::attributes(
      $io->{commands}, $commands
    );
    last if ($indicator eq "" || !$depricated);
    $flag_depricated = 1;
    $indicator = "";
  }

  foreach (keys(%{$io->{commands}})) {
    my $ptr = $io->{commands}->{$_};
    $ptr->{set} = \&EMC::IO::set_options if (!defined($ptr->{set}));
  }
  return $io;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $io = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($io, "flag");
  my $set = EMC::Common::element($io, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "io_" : "";
  if ($option eq $indicator."dummy") {
    return $flag->{dummy} = EMC::Math::flag($args->[0]);
  }
  return undef;
}


sub set_functions {
  my $io = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($io, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 0, items => 1};

  $set->{commands} = \&EMC::IO::set_commands;
  $set->{context} = \&EMC::IO::set_context;
  $set->{defaults} = \&EMC::IO::set_defaults;
  $set->{options} = \&EMC::IO::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $io;
}


# functions

sub expand {					# <= fexpand
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


sub strip {					# <= my_strip
  my $sep = $^O eq "MSWin32" ? "\\" : "/";
  my $name = shift(@_);
  my $dir = defined($name) ? dirname($name) : undef;

  foreach(@_) {
    $name = basename($name, $_) if (defined($_));
  }
  return defined($dir) ? $dir.$sep.$name : $name;
}


sub emc_root {					# <= set_origin
  my $root = "";
  my $split = ($^O eq "MSWin32" ? "\\\\" : "/");
  my @arg = split($split, $0);
  
  @arg = (split($split, $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  if (defined($ENV{EMC_ROOT})) {
    $root = $ENV{EMC_ROOT};
    $root =~ s/~/$ENV{HOME}/g if ($^O ne "MSWin32");
  } else {
    pop(@arg); pop(@arg);
    pop(@arg) if (@arg[-1] eq "");
    $root = join("/", @arg);
  }
  return scrub_dir($root);
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
    push(@{$array}, $_) if (-d EMC::IO::expand($_));
  }
}


sub path_prepend {
  my $array = shift(@_);
  my @result;
  my %exist;
  my @list;
  my $s;

  foreach (@_) {
    next if (!defined($_));
    push(@list, $s = scrub_dir($_));
    $exist{$s} = 1;
  }
  foreach (@{$array}) {					# delete if exists
    $s = scrub_dir($_);
    push(@result, $s) if (!defined($exist{$s}));
  }
  foreach (@list) {					# prepend
    unshift(@result, $_) if (-d EMC::IO::expand($_));
  }
  @{$array} = @result;
}


sub path_append {
  my $array = shift(@_);
  my @result;
  my %exist;
  my @list;
  my $s;

  foreach (@_) {
    next if (!defined($_));
    push(@list, $s = scrub_dir($_));
    $exist{$s} = 1;
  }
  foreach (@{$array}) {					# delete if exists
    $s = scrub_dir($_);
    push(@result, $s) if (!defined($exist{$s}));
  }
  foreach (@list) {					# append
    push(@result, $_) if (-d EMC::IO::expand($_));
  }
  @{$array} = @result;
}


sub expand_tilde {
  my $dir = shift(@_);

  if (substr($dir,0,2) eq "~/") { $dir =~ s/~/\${HOME}/; }
  elsif (substr($dir,0,1) eq "~") { $dir =~ s/~/\${HOME}\/..\//; }
  return $dir;
}


# i/o routines

sub exist {					# <= fexist
  my $name = expand(shift(@_));
  my $suffix = ref(@_[0]) eq "ARRAY" ? shift(@_) : undef;

  foreach ($suffix ? ("", @{$suffix}) : ("")) {
    return 1 if (-f $name.$_);
  }
  return 0;
}


sub check_exist {
  my $root = shift(@_);
  my $type = shift(@_);
  my $name = EMC::IO::expand(shift(@_));
  my $global = $root->{global};

  if (!$global->{replace}->{flag} && -e $name) {
    EMC::Message::warning("\"$name\" exists; use -replace flag to overwrite\n");
  } elsif (!defined($global->{check_exist}->{$type})) {
    $global->{check_exist}->{$type}->{$name} = 1; return 0;
  } elsif (!defined($global->{check_exist}->{$type}->{$name})) {
    $global->{check_exist}->{$type}->{$name} = 1; return 0;
  }
  return 1;
}


sub close {
  my $stream = shift(@_);
  my $name = shift(@_);
  
  undef($EMC::IO::stream);
  delete($EMC::IO::name{fileno($stream)}) if (defined($stream));
  if (defined($name)) {
    return if ($name eq "-");
  }
  close($stream) if (defined($stream));
  return undef;
}


sub find {					# <= ffind
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


sub locate {					# <= flocate
  my $name = shift(@_);
  my @ext = ("", shift(@_));

  foreach ("", @_) {
    my $root = ($_ eq "" ? "" : $_."/").$name;
    foreach (@ext) {
      my $file = $root.$_;
      return $file if (-f EMC::IO::expand($file));
    }
  }
  return undef;
}


sub open {					# <= fopen
  my $name = expand(shift(@_));
  my $mode = shift(@_);
  my @modes = split("", $mode);
  my $suffix = ref(@_[0]) eq "ARRAY" ? shift(@_) : undef;
  my $attr = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $compress = 0;
  my $error = 0;
  my $local = undef;
  my $stream = \$local;

  if (substr($name,-3) eq ".gz") {
    $name = substr($name, 0, length($name)-3);
    push(@modes, "z");
  }
  my %tmp; foreach (@modes) { $tmp{$_} = 1; }
  $mode = join("", sort(keys(%tmp)));
  if ($mode eq "r") {
    if ($name eq "-") {
      ${$stream} = *STDIN;
    } else {
      foreach ($suffix ? ("", @{$suffix}) : ("")) {
	next if (! -f $name.$_);
	open(${$stream}, "<", $name .= $_);
	last;
      }
    }
  } elsif ($mode eq "w") {
    if ($name eq "-") {
      ${$stream} = *STDOUT;
    } else {
      open(${$stream}, ">", $name);
    }
  } elsif ($mode eq "a") {
    if ($name eq "-") {
      ${$stream} = *STDOUT;
    } else {
      open(${$stream}, ">>", $name);
    }
  } elsif ($mode eq "rz") {
    $compress = 1;
    $name = $name.".gz" if (-e $name.".gz");
    ${$stream} = new IO::Uncompress::Gunzip($name) or $error = 1;
  } elsif ($mode eq "wz") {
    $compress = 1;
    $name = $name.".gz";
    ${$stream} = new IO::Compress::Gzip($name) or $error = 1;
  } else {
    EMC::Message::error("unsupported mode \"$mode\"\n");
  }
  if ($compress ? $error : !scalar(stat(${$stream}))) {
    EMC::Message::error("cannot open \"$name\"\n");
  }
  $EMC::IO::stream = $stream;
  $EMC::IO::name{fileno(${$stream})} = $name;
  return $suffix ? (${$stream}, $name) : ${$stream};
}


sub rewind {
  my $stream = shift(@_);

  seek($stream, 0, 0);
  return $stream;
}


sub touch {
  EMC::IO::close(EMC::IO::open(shift(@_), "w"));
}


# export

sub put {
  my $stream = shift(@_);

  foreach (@_) {
    if (ref($_) eq "ARRAY") {
      foreach (@{$_}) {
	printf($stream "%s\n", $_);
      }
    } else {
      printf($stream "%s\n", $_);
    }
  }
}


# import

sub get {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $name = EMC::Common::element($attr, "name");
  my $data = EMC::Common::list($attr, "data");

  if (!defined($name)) {
    $attr->{name} = $name = EMC::IO::get_name($stream);
    $attr->{name} = $name = "<stdin>" if (!defined($name));
  }

  @{$data} = ();
  foreach(ref($stream) eq "" ? split("\n", $stream) : <$stream>) {
    chomp();
    my @arg = split("\r");
    if (@arg) {
      foreach(@arg) {
	chomp();
	push(@{$data}, $_);
      }
    } else {
      push(@{$data}, "");
    }
  }
  return {data => $data, lines => {0 => {name => $name, line => 1}}};
}


sub get_name {
  my $stream = shift(@_);

  return 
    undef if(defined($stream) ? ref($stream) eq "" ? 1 : 0 : 1);
  return 
    defined($EMC::IO::name{fileno($stream)}) ? 
    $EMC::IO::name{fileno($stream)} : undef;
}


sub get_preprocess {
  my $stream = shift(@_);
  my $attr = EMC::Common::hash(shift(@_));
  my $data = EMC::Common::list($attr, "data");
  my $raw = get($stream, $attr);
  my $name = EMC::Common::element($attr, "name");
  my %allow = (
    define => 1, elif => 1, else => 1, endif => 1, if => 1, ifdef => 1,
    include => 1
  );
  
  my $command = "gcc -x c -E -o - -";
  my ($child_in, $child_out, $child_err);
  my $pid = open3($child_in, $child_out, $child_err, $command);

  if (!$pid) {
    EMC::Message::warning("could not open gcc for preprocessing\n");
    return $raw;
  }

  foreach (@{$raw->{data}}) {				# pipe to gcc
    my $s = $_;

    $s =~ s/^\s+|\s+$//g;
    if (substr($s,0,1) eq "#") {
      my @a = split(" ", $s);
      $s = "" if (!defined($allow{substr(@a[0],1)}));
    }
    print($child_in "$s\n");
  }
  close($child_in);
  
  my $i = 0;						# collect from pipe
  my $lines = {};
  my $errors;

  @{$data} = ();
  foreach (@{EMC::IO::get($child_out)->{data}}) {
    if (substr($_,0,1) eq "#") {
      my ($line, $iname) = (split(" "))[1,2];
      $iname = substr($iname,1,-1);
      if (substr($iname,0,1) eq "<") {
      	next if ($iname ne "<stdin>");
      	$iname = $name;
      }
      $lines->{$i} = {name => $iname, line => $line};
      next;
    } elsif (substr($_,0,7) eq "<stdin>") {
      $errors = [] if (!defined($errors));
      my @a = split(":");
      push(@{$errors}, {name => $name, line => @a[1], error => EMC::Common::trim(@a[-1])});
    }
    $data->[$i++] = $_;
  }
  close($child_out);
  
  if (defined($errors)) {
    print("Error: ");
    EMC::Message::spot("\n");
    print("       Preprocessing errors in '$name'.\n\n");
    foreach (@{$errors}) {
      print($_->{name}, ":", $_->{line}, ": ", $_->{error}, "\n");
    }
    print("\n");
    exit(-1);
  }
  
  return {data => $data, lines => $lines};
}


sub get_data_quick {
  my $stream = shift(@_);
  my $data = ref(@_) eq "ARRAY" ? shift(@_) : [];
  my $name = shift(@_);
  my $data = [];
  my $lines = [];
  my $line = 0;
  my $verbatim;

  foreach(<$stream>) {
    chomp();
    my @arg = split("\r");
    ++$line if (!scalar(@arg));
    foreach(@arg) {
      ++$line;
      chomp();

      my @a = split("\t");
      @a = split(",") if (scalar(@a)<2);
      push(@{$data}, [@a]);
      push(@{$lines}, "$name:$line");
    }
  }
  return {data => $data, lines => $lines};
}


sub spool {
  my $stream = shift(@_);
  my @data;

  foreach (<$stream>) {
    push(@data, $_);
  }
  return @data;
}

