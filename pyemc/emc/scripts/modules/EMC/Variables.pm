#!/usr/bin/env perl
#
#  module:	EMC::Variables.pm
#  author:	Pieter J. in 't Veld
#  date:	September 25, 2022.
#  purpose:	Variables structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "variables_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#    variable		ARRAY of HASH
#      name		STRING	variable name
#      value		STRING	variable value
#      stage		STRING	stage in output script
#      spot		STRING	spot in stage
#
#  notes:
#    20220925	Inception of v1.0
#

package EMC::Variables;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Variables'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::Math;


# defaults

$EMC::Variables::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 25, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $variables = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($variables, $attr);
  set_defaults($variables);
  set_commands($variables);
  return $variables;
}


# initialization

sub set_defaults {
  my $variables = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $variables = EMC::Common::attributes(
    $variables,
    {
      variable		=> {}
    }
  );
  $variables->{identity} = EMC::Common::attributes(
    EMC::Common::hash($variables, "identity"),
    $EMC::Variables::Identity
  );
  return $variables;
}


sub set_commands {
  my $variables = EMC::Common::hash(shift(@_));

  EMC::Options::set_command(
    $variables->{items} = EMC::Common::attributes(
      EMC::Common::hash($variables, "items"),
      {
	# V
	
	variables	=> {
	  order		=> 100,
	  environment	=> 1
	}
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0,
      set		=> \&set_item_variables
    }
  );
  return $variables;
}



sub transfer {
  my $variables = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($variables, "flag");
  my $context = EMC::Common::element($variables, "context");
  
  EMC::Element::transfer(shift(@_),
    [\%::EMC::Variables,		\$variables->{variable}],
  );
}


sub set_functions {
  my $variables = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($variables, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{defaults} = \&EMC::Variables::set_defaults;
  $set->{commands} = \&EMC::Variables::set_commands;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $variables;
}


# set item

sub set_item_variables {
  my $struct = shift(@_);
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));
  my $root = EMC::Common::element($struct, "root");

  return $root if (EMC::Common::element($options, "comment"));
  
  my $option = EMC::Common::element($struct, "option");
  my $module = EMC::Common::element($struct, "module");

  $module->{item} = $item;
  return $root;
}


# functions

sub variable_replace {
  my $variables = shift(@_);
  my $var = shift(@_);
  my %h = ();
  my ($r, $v, $b, $f, $l);

  return $var if (!($var =~ m/\@/));
  
  foreach (@{$variables->{data}}) {
    my @v = EMC::Item::split_data($_);
    my $id = uc(shift(@v));
    $h{"\@{$id}"} = join(", ", @v);
  }
  foreach (split("", $var)) {
    if ($_ eq "@") {
      if ($v ne "") { 
	$v .= "}"; $r .= (defined($h{$v}) ? $h{$v} : $v);
      }
      $v = $_."{"; $f = 1; $b = 0;
    } elsif ($f) {
      if (($_ =~ /[a-zA-Z]/)||($_ =~ /[0-9]/)||($b && $_ ne "}")) {
	$v .= $_;
      } elsif ($_ eq "{" && $l eq "@") {
	$b = 1;
      } else {
	$v .= "}";
	$r .= (defined($h{$v}) ? $h{$v} : $v).($b && $_ eq "}" ? "" : $_);
	$v = ""; $f = $b = 0;
      }
    } else {
      $r .= $_;
    }
    $l = $_;
  }
  $v .= "}" if ($v ne "");
  $r .= (defined($h{$v}) ? $h{$v} : $v);
  return $r;
}

