#!/usr/bin/env perl
#
#  module:	EMC::Empty.pm
#  author:	Pieter J. in 't Veld
#  date:	@{DATE}.
#  purpose:	Empty structure routines; part of EMC distribution
#
#  Copyright (c) 2004-@{YEAR} Pieter J. in 't Veld
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
#        indicator	BOOLEAN	include "empty_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    flag		HASH	optional flags
#
#  notes:
#    @{YEAR}@{MONTH}@{DAY}	Inception of v1.0
#

package EMC::Empty;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Empty'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Math;


# defaults

$EMC::Empty::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "@{DATE}",
  version	=> "1.0"
};


# construct

sub construct {
  my $emtpy = EMC::Common::obtain_hash(shift(@_));
  
  set_functions($empty);
  set_defaults($empty);
  set_commands($empty);
  return $empty;
}


# initialization

sub set_defaults {
  my $empty = EMC::Common::obtain_hash(shift(@_));

  $empty->{flag} = EMC::Common::attributes(
    EMC::Common::obtain_hash($empty, "flag"),
    {
      dummy		=> 0
    }
  );
  $empty->{identity} = EMC::Common::attributes(
    EMC::Common::obtain_hash($empty, "identity"),
    $EMC::Empty::Identity
  );
  return $emc;
}


sub set_commands {
  my $empty = EMC::Common::obtain_hash(shift(@_));
  my $set = EMC::Common::element($empty, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  
  $indicator = $indicator ? "empty_" : "";
  $empty->{commands} = EMC::Common::attributes(
    EMC::Common::obtain_hash($empty, "commands"),
    {
      $indicator."dummy"	=> {
	comment		=> "dummy description",
	set		=> \&EMC::Empty::set_options,
	default		=> $empty->{flag}->{dummy}
      }
    }
  );
  return $empty;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $emc = EMC::Common::element($struct, "emc");
  my $empty = EMC::Common::obtain_hash($emc, "empty");
  my $flag = EMC::Common::obtain_hash($empty, "flag");
  my $set = EMC::Common::element($empty, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "empty_" : "";
  if ($option eq $indicator."dummy") {
    return $flag->{dummy} = EMC::Math::flag($args->[0]);
  }
  return undef;
}


sub set_functions {
  my $emtpy = EMC::Common::obtain_hash(shift(@_));
  my $set = EMC::Common::obtain_hash($empty, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {"commands" => 1, "indicator" => 1};

  $set->{commands} = \&EMC::Empty::set_commands;
  $set->{defaults} = \&EMC::Empty::set_defaults;
  $set->{options} = \&EMC::Empty::set_options;
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $empty;
}


# functions

