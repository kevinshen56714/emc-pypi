#!/usr/bin/env perl
#
#  module:	EMC::Polymers.pm
#  author:	Pieter J. in 't Veld
#  date:	September 21, 2022.
#  purpose:	Polymers structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
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
#        indicator	BOOLEAN	include "polymers_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#    id			HASH	reference to cluster ID
#    index		ARRAY	list of polymer IDs
#    
#    polymer		HASH of ARRAY
#      0		VALUE	fraction
#      1		VALUE	nrepeats
#      2		ARRAY	contributing groups
#      3		ARRAY	weights of groups
#      4		STRING	either 'cluster' or 'group'
#
#  notes:
#    20220921	Inception of v1.0
#

package EMC::Polymers;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Polymers'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::Math;


# defaults

$EMC::Polymers::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 21, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $polymers = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($polymers, $attr);
  set_defaults($polymers);
  set_commands($polymers);
  return $polymers;
}


# initialization

sub set_defaults {
  my $polymers = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $polymers = EMC::Common::attributes(
    $polymers,
    {
      id		=> {},
      index		=> [],
      polymer		=> {}
    }
  );
  $polymers->{flag} = EMC::Common::attributes(
    EMC::Common::hash($polymers, "flag"),
    {
      bias		=> "none",
      cluster		=> undef,
      connect		=> [],
      fraction		=> "number",
      niterations	=> -1,
      order		=> "list",
      polymer		=> undef,
      type		=> undef,
      ignore		=> ["cluster", "polymer", "type"]
    }
  );
  $polymers->{identity} = EMC::Common::attributes(
    EMC::Common::hash($polymers, "identity"),
    $EMC::Polymers::Identity
  );
  return $polymers;
}


sub transfer {
  my $polymers = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($polymers, "flag");
  my $context = EMC::Common::element($polymers, "context");
  
  EMC::Element::transfer(shift(@_),
    [\%::EMC::Polymer,			\$polymers->{polymer}],
    [\%::EMC::PolymerFlag,		\$polymers->{flag}],
    [\%::EMC::Polymers,			\$polymers->{id}],
  );
}


sub set_context {
  my $polymers = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $units = EMC::Common::element($root, "global", "units");
  my $flag = EMC::Common::element($polymers, "flag");
  my $context = EMC::Common::element($polymers, "context");
}


sub set_commands {
  my $polymers = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($polymers, "set");
  my $context = EMC::Common::element($polymers, "context");
  my $flag = EMC::Common::element($polymers, "flag");

  $flag->{cluster} = EMC::Math::boolean($flag->{cluster});
  EMC::Options::set_command(
    $polymers->{commands} = EMC::Common::attributes(
      EMC::Common::hash($polymers, "commands"),
      {
	# P

	polymer		=> {
	  comment	=> "default polymer settings for groups",
	  default	=> EMC::Hash::text($flag, "string"),
	  gui		=> ["list", "chemistry", "top", "ignore"]},
	polymer_niters	=> {
	  comment	=> "number of iterations for polymer construction",
	  default	=> $flag->{niterations},
	  gui		=> ["list", "chemistry", "top", "ignore"]},
      }
    ),
    {
      set		=> \&EMC::Polymers::set_options
    }
  );
  $polymers->{items} = EMC::Common::attributes(
    EMC::Common::hash($polymers, "items"),
    {
      polymers	=> {
	chemistry	=> 1,
	enviroment	=> 1,
	order		=> 1,
	set		=> \&set_item_polymers
      }
    }
  );  
  return $polymers;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $polymers = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($polymers, "flag");
  my $set = EMC::Common::element($polymers, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  # P

  if ($option eq "polymer") {
    return EMC::Polymers::set_list($line, $flag, @{$args}); }
  if ($option eq "polymer_niters") {
    return $flag->{niterations} = EMC::Math::eval($args->[0])->[0]; }
  return undef;
}


sub set_functions {
  my $polymers = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($polymers, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Polymers::set_commands;
  $set->{context} = \&EMC::Polymers::set_context;
  $set->{defaults} = \&EMC::Polymers::set_defaults;
  $set->{options} = \&EMC::Polymers::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $polymers;
}


sub set_list {					# <= set_list_polymer
  my $line = shift(@_);
  my $hash = shift(@_);
  my %allowed = (
    bias => {none => 1, binary => 1, accumulative => 1},
    fraction => {number => 1, mass => 1},
    order => {list => 1, random => 1}
  );

  EMC::Hash::set($line, $hash, "string", "", [], @_);
  foreach (sort(keys(%allowed))) {
    if (!defined($allowed{$_}->{$hash->{$_}})) {
      EMC::Message::error_line($line, "illegal option for keyword '$_'\n");
    }
  }
  $hash->{cluster} = EMC::Math::flag($hash->{cluster});
  return $hash;
}


# functions

sub is_polymer {
  my $text = shift(@_);
  my $allowed = {
    alternate => 1, block => 2, random => 3, sequence => 4};

  return defined($allowed->{$text}) ? $allowed->{$text} : 0;
}


# ITEM POLYMERS
#   line 1: 	name,fraction[,mass[,volume]]
#   fraction -> mole, mass, or volume fraction
#   line 2:	fraction,group,n[,group,n[,...]]
#   fraction -> mole fraction
#   line ...:	same as line 2

sub set_item_polymers {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $option = EMC::Common::element($struct, "option");
  my $polymers = EMC::Common::element($struct, "module");
  my $emc = EMC::Common::element($polymers, "parent");
  my $cluster = EMC::Common::element($emc, "clusters", "cluster");
  my $flag = EMC::Common::element($root, "global", "flag");

  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $options = {};
  my $iline = 0;
  my $polymer_data;
  my $polymer;
  my $name;

  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$iline++];

    if (scalar(@arg)==1||				# first line
        defined($polymers->{polymer}->{@arg[0]})) {
      
      $options = EMC::Element::deep_copy($polymers->{flag});
      $name = EMC::EMC::check_name($emc, shift(@arg), $line, 2);
      EMC::Polymers::set_list($line, $options, @arg);
      if (ref($options->{connect}) eq "") {
	$options->{connect} = [sort(split(":", $options->{connect}))];
      }
      $polymer = EMC::Common::hash($polymers, "polymer", $name);
      if (!defined($polymer->{options}->{type})) {
	EMC::Message::error_line(
	  $line, "undefined polymer \'$name\'\n") if (!$flag->{expert});
      } elsif (!$polymer->{options}->{type}) {
	EMC::Message::expert_line($line, "\'$name\' is not a polymer\n");
	undef($polymer);
      } else {
	$polymer->{data} = $polymer_data = [];
	$polymer->{options} = EMC::Common::attributes(
	  $options, $polymer->{options});
	if (defined($cluster->{$name})) {
	  $polymer->{cluster} = $cluster->{$name};
	}
      }
    } elsif (defined($polymer)) {			# subsequent lines
      my $fraction = shift(@arg);
      my $groups = [];
      my $nrepeats = [];
      my $weights = [];

      push(
	@{$polymer->{data}}, {
	  fraction => $fraction,
	  groups => $groups,
	  nrepeats => $nrepeats,
	  weights => $weights
	}
      );
      while (scalar(@arg)) {
	my $name = shift(@arg);
	my $n = shift(@arg);
	my @a = split("=", $name);
	my @t = split(":", @a[0]);
	foreach(@t[0]) {
	  EMC::EMC::check_name($emc, $_, $line, 0);
	}
	push(@{$nrepeats}, $flag->{expert} ? $n : EMC::Math::eval($n)->[0]);
	push(@{$groups}, @a[0]);
	if (!$flag->{expert} && !(substr($n,0,1) =~ m/[0-9]/)) {
	  EMC::Message::error_line($line, "number expected\n");
	}
	$n = scalar(@t);
	if (scalar(@a)>1) {
	  @t = split(":", @a[1]);
	  if (scalar(@t)!=$n) {
	    EMC::Message::error_line(
	      $line, "number of groups and weights are not equal\n");
	  }
	} else {
	  foreach(@t) { $_ = 1; }
	}
	push(@{$weights}, join(":", @t));
      }
    }
  }
  return $root;
}

