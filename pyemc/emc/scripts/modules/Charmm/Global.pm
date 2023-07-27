#!/usr/bin/env perl
#
#  module:	EMC::Global.pm
#  author:	Pieter J. in 't Veld
#  date:	January 18, 2023.
#  purpose:	Global structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
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
#        indicator	BOOLEAN	include "global_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20230118	Inception of v1.0
#

package Charmm::Global;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Global'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use lib Core;
use EMC::Common;
use EMC::Element;
use EMC::Math;


# defaults

$EMC::Global::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "January 18, 2023",
  version	=> "1.0"
};


# construct

sub construct {
  my $global = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($global, $attr);
  set_defaults($global);
  set_commands($global);
  return $global;
}


# initialization

sub set_defaults {
  my $global = EMC::Common::hash(shift(@_));

  $global->{context} = EMC::Common::attributes(
    EMC::Common::hash($global, "context"),
    {
      dummy		=> 0
    }
  );
  $global->{flag} = EMC::Common::attributes(
    EMC::Common::hash($global, "flag"),
    {
      dummy		=> 0
    }
  );
  $global->{identity} = EMC::Common::attributes(
    EMC::Common::hash($global, "identity"),
    $EMC::Global::Identity
  );
  return $global;
}


sub transfer {
  my $global = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($global, "flag");
  my $context = EMC::Common::element($global, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Global{dummy},		\$context->{dummy}],
  );
}


sub set_context {
  my $global = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "types", "field");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($global, "flag");
  my $context = EMC::Common::element($global, "context");
}


sub set_commands {
  my $global = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($global, "set");
  my $context = EMC::Common::element($global, "context");
  my $flag = EMC::Common::element($global, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated = $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "global_" : "";

  $global->{commands} = EMC::Common::hash($global, "commands");
  while (1) {
    my $commands = {
      $indicator."dummy"	=> {
	comment		=> "dummy description",
	set		=> \&EMC::Global::set_options,
	default		=> $global->{flag}->{dummy}
      }
    };

    if ($flag_depricated) {
      foreach (keys(%{$commands})) {
	$commands->{$_}->{original} = $pre.$_;
      }
    }
    EMC::Options::set_command(
      $global->{commands} = EMC::Common::attributes(
	$global->{commands}, $commands
      ),
      {
	set		=> \&EMC::Global::set_options
      }
    );
    last if ($indicator eq "" || !$depricated);
    $flag_depricated = 1;
    $indicator = "";
  }
  
  EMC::Options::set_command(
    $global->{items} = EMC::Common::attributes(
      $global->{items},
      {
      }
    ),
    {
      set		=> \&EMC::Global::set_items
    }
  );

  return $global;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $global = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($global, "flag");
  my $set = EMC::Common::element($global, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "global_" : "";
  while (1) {
    if ($option eq $indicator."dummy") {
      return $flag->{dummy} = EMC::Math::flag($args->[0]);
    }
    last if ($indicator eq "");
    $indicator = "";
  }
  return undef;
}


sub set_items {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $data = EMC::Common::element($struct, "data");
  my $global = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($global, "flag");

  if ($option eq $indicator."dummy") {
    return $flag->{dummy} = EMC::Math::flag($args->[0]);
  }
  return undef;
}


sub set_functions {
  my $global = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($global, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Global::set_commands;
  $set->{context} = \&EMC::Global::set_context;
  $set->{defaults} = \&EMC::Global::set_defaults;
  $set->{options} = \&EMC::Global::set_options;
  $set->{items} = \&EMC::Global::set_items;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $global;
}


# functions

