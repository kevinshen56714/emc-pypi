#!/usr/bin/env perl
#
#  module:	EMC::XYZ.pm
#  author:	Pieter J. in 't Veld
#  date:	February 15, 2025
#  purpose:	XYZ structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "xyz_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    flag		HASH	optional flags
#
#  notes:
#    20250215	Inception of v1.0
#

package EMC::XYZ;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::XYZ'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::EMC;
use EMC::Math;


# defaults

$EMC::XYZ::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "February 15, 2025",
  version	=> "1.0"
};


# construct

sub construct {
  my $xyz = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($xyz, $attr);
  set_defaults($xyz);
  set_commands($xyz);
  return $xyz;
}


# initialization

sub set_defaults {
  my $xyz = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $xyz->{flag} = EMC::Common::attributes(
    EMC::Common::hash($xyz, "flag"),
    {
      atom		=> "index",
      compress		=> 1,
      cut		=> 0,
      fixed		=> 0,
      hexadecimal	=> 0,
      pbc		=> 1,
      residue		=> "index",
      rigid		=> 0,
      segment		=> "index",
      unwrap		=> 1,
      write		=> 0
    }
  );
  $xyz->{identity} = EMC::Common::attributes(
    EMC::Common::hash($xyz, "identity"),
    $EMC::XYZ::Identity
  );
  return $xyz;
}


sub transfer {
  my $lammps = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($lammps, "flag");
  
}


sub set_commands {
  my $xyz = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($xyz, "set");
  my $flag = EMC::Common::element($xyz, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  
  $indicator = $indicator ? "xyz_" : "";
  my $commands = $xyz->{commands} = EMC::Common::attributes(
    EMC::Common::hash($xyz, "commands"),
    {
      xyz		=> {
	comment		=> "create XYZ output",
	default		=> EMC::Math::boolean($flag->{write}),
	gui		=> ["string", "chemistry", "top", "ignore"]},

      # C

      $indicator."compress"	=> {
	comment		=> "set XYZ and PSF compression",
	default		=> EMC::Math::boolean($flag->{compress}),
	gui		=> ["option", "chemistry", "emc", "advanced"]},
      $indicator."cut"		=> {
	comment		=> "cut bonds spanning simulation box",
	default		=> EMC::Math::boolean($flag->{cut}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},

      # P

      $indicator."pbc"	=> {
	comment		=> "apply periodic boundary conditions",
	default		=> EMC::Math::boolean($flag->{pbc}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},

      # R

      $indicator."residue"	=> {
	comment		=> "set residue name behavior",
	default		=> $flag->{residue},
	gui		=> ["option", "chemistry", "emc", "advanced", "detect,index,series"]},

      # S

      $indicator."segment"	=> {
	comment		=> "set segment name behavior",
	default		=> $flag->{segment},
	gui		=> ["option", "chemistry", "emc", "advanced", "detect,index,series"]},

      # U

      $indicator."unwrap"	=> {
	comment		=> "apply unwrapping",
	default		=> EMC::EMC::flag_unwrap($flag->{unwrap}),
	gui		=> ["boolean", "chemistry", "emc", "advanced"]}
    }
  );

  foreach (keys(%{$commands})) {
    my $ptr = $commands->{$_};
    if (!defined($ptr->{set})) {
      $ptr->{set} = \&EMC::XYZ::set_options;
    }
  }

  return $xyz;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $xyz = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($xyz, "flag");
  my $set = EMC::Common::element($xyz, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "xyz_" : "";
  if ($option eq "xyz") {
    return $flag->{write} = EMC::Math::flag($args->[0]); }

  # C

  if ($option eq $indicator."compress") {
    return $flag->{compress} = EMC::Math::flag($args->[0]); }
  if ($option eq $indicator."cut") {
    return $flag->{cut} = EMC::Math::flag($args->[0]); }

  # P

  if ($option eq $indicator."pbc") {
    return $flag->{pbc} = EMC::Math::flag($args->[0]); }

  # R

  if ($option eq $indicator."residue") {
    return $flag->{residue} = set_flag("residue", $args->[0], $line); }

  # S

  if ($option eq $indicator."segment") {
    return $flag->{segment} = set_flag("segment", $args->[0], $line); }

  # U

  if ($option eq $indicator."unwrap") {
    return $flag->{unwrap} = EMC::EMC::flag_unwrap($args->[0]); }

  return undef;
}


sub set_functions {
  my $xyz = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($xyz, "set");
  my $write = EMC::Common::hash($xyz, "write");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, indicator => 1, items => 1, md => 0};

  $set->{commands} = \&EMC::XYZ::set_commands;
  $set->{defaults} = \&EMC::XYZ::set_defaults;
  $set->{options} = \&EMC::XYZ::set_options;

  $write->{emc} = \&EMC::XYZ::write_emc;

  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $xyz;
}


# option functions

sub set_flag {					# <= set_xyz_flag
  my $type = shift(@_);
  my $mode = shift(@_);
  my $line = shift(@_);
  my %allow = (detect => 1, index => 1, series => 1);

  if (!$allow{$mode}) {
    EMC::Message::error_line($line, "illegal XYZ $type flag '$mode'\n");
  }
  return $mode;
}


# EMC script additions

sub write_emc {
  my $xyz = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $emc_flag = EMC::Common::element($root, "emc", "flag");
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $flag = EMC::Common::element($xyz, "flag");

  return if ($emc_flag->{test});
  return if (!(defined($flag) && $flag->{write}));
  return if ($emc_flag->{exclude}->{build});

  printf($stream "\nxyz\t\t= {name -> output,");
  printf($stream " compress -> ".EMC::Math::boolean($flag->{compress}).",");
  printf($stream " forcefield -> $field->{type},");
  printf($stream "\n\t\t  ");
  printf($stream " unwrap -> ".EMC::Math::boolean($flag->{unwrap}).",");
  printf($stream " pbc -> ".EMC::Math::boolean($flag->{pbc}).",");
  printf($stream " residue -> $flag->{residue},");
  printf($stream "\n\t\t  ");
  printf($stream " segment -> $flag->{segment},");
  printf($stream " cut -> ".EMC::Math::boolean($flag->{cut}).",");
  printf($stream "\n\t\t  ");
  printf($stream " connectivity -> ".EMC::Math::boolean($flag->{connect}));
  printf($stream "};\n");
}

