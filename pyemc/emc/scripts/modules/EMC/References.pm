#!/usr/bin/env perl
#
#  module:	EMC::References.pm
#  author:	Pieter J. in 't Veld
#  date:	September 27, 2022.
#  purpose:	References structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "references_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    data		ARRAY of HASH
#      data		ARRAY	values for comma separated input
#      line		VALUE	line number in input file
#      verbatim		STRING	verbatim input line
#
#    name		STRING	input file name
#
#    verbatim		ARRAY of HASH
#      data		ARRAY	values from .esh
#      line		VALUE	line number in input .esh
#      verbatim		STRING	verbatim input
#
#  notes:
#    20220927	Inception of v1.0
#

package EMC::References;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::References'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::IO;
use EMC::Math;
use EMC::Types;


# defaults

$EMC::References::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 27, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $references = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($references, $attr);
  set_defaults($references);
  set_commands($references);
  return $references;
}


# initialization

sub set_defaults {
  my $references = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $references = EMC::Common::attributes(
    $references,
    {
      # D

      data		=> {},

      # F

      flag		=> 0,

      # L

      length		=> -1,

      # M

      mass		=> -1,

      # N

      name		=> "references",

      # S

      suffix		=> "_ref",

      # T

      type		=> undef,

      # V

      verbatim		=> undef,
      volume		=> -1
    }
  );
  $references->{identity} = EMC::Common::attributes(
    EMC::Common::hash($references, "identity"),
    $EMC::References::Identity
  );
  EMC::Options::set_command(
    $references->{items} = EMC::Common::attributes(
      EMC::Common::hash($references, "items"),
      {
	# M

	masses		=> {
	  set		=> \&set_item_masses
	},

	# R

	references	=> {
	  environment	=> 1,
	  set		=> \&set_item_references
	}
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0
    }

  );
  return $references;
}


sub transfer {
  my $references = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($references, "flag");
  my $context = EMC::Common::element($references, "context");
  
  EMC::Element::transfer(shift(@_),
    [\%::EMC::Reference,		\$references],
    [\$::EMC::Reference{data},		\$references->{data}],
    [\$::EMC::Reference{flag},		\$references->{flag}],
    [\$::EMC::Reference{length},	\$references->{length}],
    [\$::EMC::Reference{name},		\$references->{name}],
    [\$::EMC::Reference{mass},		\$references->{mass}],
    [\$::EMC::Reference{suffix},	\$references->{suffix}],
    [\$::EMC::Reference{type},		\$references->{type}],
    [\$::EMC::Reference{volume},	\$references->{volume}],
    [\$::EMC::Verbatim{references},	\$references->{verbatim}],
  );
}


sub set_context {
  my $references = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($references, "flag");
  my $context = EMC::Common::element($references, "context");

  # R

  $references->{volume} = (
    $field->{type} eq "dpd" ? 0.1 :
    $field->{type} eq "gauss" ? 0.1 : -1) if ($references->{volume}<0);
  $references->{flag} = (
    $field->{type} eq "dpd" ? 0 :
    $field->{type} eq "gauss" ? 0 : 1);  
}


sub set_commands {
  my $references = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($references, "set");
  my $context = EMC::Common::element($references, "context");
  my $flag = EMC::Common::element($references, "flag");

  $references->{commands} = EMC::Common::attributes(
    EMC::Common::hash($references, "commands"),
    {
      # R

      references	=> {
	comment		=> "set references file name",
	default		=> $references->{name},
	gui		=> ["browse", "chemistry", "field", "advanced"]},
      rlength		=> {
	comment		=> "set reference length",
	default		=> strref($references->{length}),
	gui		=> ["real", "chemistry", "field", "advanced", "dpd"]},
      rmass		=> {
	comment		=> "set reference mass",
	default		=> strref($references->{mass}),
	gui		=> ["real", "chemistry", "field", "advanced", "dpd"]},
      rtype		=> {
	comment		=> "set reference type",
	default		=> $references->{type},
	gui		=> ["string", "chemistry", "field", "advanced", "dpd"]},

    }
  );

  foreach (keys(%{$references->{commands}})) {
    my $ptr = $references->{commands}->{$_};
    $ptr->{set} = \&EMC::References::set_options if (!defined($ptr->{set}));
  }
  return $references;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $references = EMC::Common::element($struct, "module");

  # R

  if ($option eq "references") {
    return $references->{name} = $args->[0]; }
  if ($option eq "rlength") { 
    return $references->{length} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "rmass") { 
    return $references->{mass} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "rtype") {
    return $references->{type} = EMC::Math::eval($args->[0])->[0]; }
  
  return undef;
}


sub set_functions {
  my $references = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($references, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::References::set_commands;
  $set->{context} = \&EMC::References::set_context;
  $set->{defaults} = \&EMC::References::set_defaults;
  $set->{options} = \&EMC::References::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $references;
}


# set item

sub set_item_masses {
  my $struct = shift(@_);
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return if (EMC::Common::element($options, "comment"));
  
  my $root = EMC::Common::element($struct, "root");
  my $option = EMC::Common::element($struct, "option");
  my $references = EMC::Common::element($struct, "module");
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $iline = 0;

  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$iline++];
    my @p = (@arg[0]);
    my $i;

    info("defining reference for @arg[0]\n");

    for ($i=0; $i<5; ++$i) { push(@p, shift(@arg)); }
    push(@p, join(" ", @arg));
    $references->{data}->{@p[0]} = [@p];
  }
  return $root;
}


sub set_item_references {
  my $struct = shift(@_);
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return if (EMC::Common::element($options, "comment"));
  
  my $root = EMC::Common::element($struct, "root");
  my $module = EMC::Common::element($struct, "module");
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");

  $module->{verbatim} = {data => $data, line => $lines};

  return $root;
}


# general functions

sub strref {
  return @_[0]<0 ? "" : length(@_[0])<1 ? "" : round(@_[0]);
}


# functions

sub define {					# <= define_reference
  my $references = shift(@_);

  my $types = EMC::Common::element($references, "parent");
  my $cutoff = EMC::Common::hash($types, "cutoff");
  my $inverse = EMC::Common::hash($types, "inverse");
  my $mass = EMC::Common::hash($types, "mass");
  my $type = EMC::Common::hash($types, "type");
  my $cut = $references->{length}>0 ? $references->{length} : 1.0;

  foreach (@_) {
    next if (!length($_));
    next if ($_ =~ m/\*/);
    next if (defined($type->{$_}));
    next if (defined($references->{data}->{$_}));

    ($inverse->{$_}, $type->{$_},
      $mass->{$_}, $cutoff->{$_}) = ($_, $_, 1, $cut);
    @{$references->{data}->{$_}} = ($_, $_, 1, 1, 2, 0, 1, $_);
  }
}


sub read {					# <= read_references
  my $references = shift(@_);
  my $name = shift(@_);
  my $suffix = shift(@_);

  my $verbatim = EMC::Common::element($references, "verbatim");
  my $types = EMC::Common::element($references, "parent");
  my $cutoff = EMC::Common::element($types, "cutoff");
  my $field = EMC::Common::element($types, "root", "fields", "field");
  my $inverse = EMC::Common::element($types, "inverse");
  my $mass = EMC::Common::element($types, "mass");
  my $type = EMC::Common::element($types, "type");

  my $stream;
  my @input;
  my %exist;
  my $data;

  return if (!EMC::IO::exist($name, $suffix) && !defined($verbatim));

  $references->{flag} = 1;

  if (defined($verbatim)) {
    $data = $verbatim;
    EMC::Message::info("reading references from input\n", $name);
  } else {
    ($stream, $name) = EMC::IO::open($name, "r", $suffix);
    EMC::Message::info("reading references from \"%s\"\n", $name);
    $data = EMC::IO::get_data_quick($stream, \@input, 0);
  }
  
  my ($name, $iline) = split(":", $data->{lines}->[0]);
  my $fline = scalar(@{$data->{lines}})>1 ? 1 : 0;
  
  $iline = 0 if ($fline);
  foreach (keys(%{$references->{data}})) {
    $exist{$_} = 1;
  }
  foreach (@{$data->{data}}) {
    my @arg = @{$_};
    my $line = $fline ? $data->{lines}->[$iline++] : "$name:".$iline++;
    
    next if (substr(@arg[0],0,1) eq "#");
    @arg = split(",", @arg[0]) if (scalar(@arg)<2);
    if ((scalar(@arg)<8)||(scalar(@arg)>9)) {
      EMC::Message::error_line($line, "incorrect number of entries\n");
    }
    @arg[3] = @arg[3]**(1/3);
    for (my $i=0; $i<1; ++$i) {
      next if ($exist{@arg[$i]});
      ($inverse->{@arg[($i+1)%2]}, $type->{@arg[$i]},
	$mass->{@arg[$i]}, $cutoff->{@arg[$i]}) = @arg[$i,1,2,3];
      $references->{data}->{@arg[$i]} = [@arg];
    }
  }
  foreach (sort(keys(%exist))) {
    my $ref = ${$references->{data}}{$_};
    my $mass = $ref->[2];
    my $mtotal = 0;
    foreach (split("\\\+", $mass)) {
      my $f = 1;
      foreach (split("\\\*", $_)) {
	$f *= defined($mass->{$_}) ? $mass->{$_} : eval($_);
      }
      $mtotal += $f;
    }
    $inverse->{$_} = $type->{$_} = $_;
    $mass->{$_} = $ref->[2] = $mtotal;
  }
  if (defined($inverse->{$references->{type}})) {
    my @arg = @{${$references->{data}}{$inverse->{$references->{type}}}};
    ($references->{mass}, $references->{length}) = @arg[2,3];
  }
  EMC::Message::info(
    "references: mass = %g, length = %g\n",
    $references->{mass}, $references->{length});
  if ($field->{type} eq "dpd") {
    EMC::Message::info("rescaling references\n");
    foreach (keys(%{$references->{data}})) {
      my @arg = @{${$references->{data}}{$_}};
      @arg[2,3] = (
	$references->{mass}>0 ? @arg[2]/$references->{mass} : 1,
	$references->{length}>0 ? @arg[3]/$references->{length} : 1);
      @{${$references->{data}}{$_}} = @arg;
    }
  }
  close($stream) if (scalar($stream));
  EMC::Types::create_replicas($types);
}

