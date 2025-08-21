#!/usr/bin/env perl
#
#  module:	EMC::Script.pm
#  author:	Pieter J. in 't Veld
#  date:	September 30, 2022.
#  purpose:	Script structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "script_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20220930	Inception of v1.0
#

package EMC::Script;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Script'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::Math;


# defaults

$EMC::Script::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 30, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $script = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($script, $attr);
  set_defaults($script);
  set_commands($script);
  return $script;
}


# initialization

sub set_defaults {
  my $script = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $script->{context} = EMC::Common::attributes(
    EMC::Common::hash($script, "context"),
    {
      dummy		=> 0
    }
  );
  $script->{flag} = EMC::Common::attributes(
    EMC::Common::hash($script, "flag"),
    {
      dummy		=> 0
    }
  );
  $script->{identity} = EMC::Common::attributes(
    EMC::Common::hash($script, "identity"),
    $EMC::Script::Identity
  );
  return $script;
}


sub transfer {
  my $script = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($script, "flag");
  my $context = EMC::Common::element($script, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Script{dummy},		\$context->{dummy}],
  );
}


sub set_context {
  my $script = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($script, "flag");
  my $context = EMC::Common::element($script, "context");
}


sub set_commands {
  my $script = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($script, "set");
  my $context = EMC::Common::element($script, "context");
  my $flag = EMC::Common::element($script, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated = $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "script_" : "";

  EMC::Options::set_command(
    $script->{commands} = EMC::Common::attributes(
      EMC::Common::hash($script, "commands"),
      {
      }
    ),
    {
      set		=> \&EMC::Script::set_options
    }
  );
  EMC::Options::set_command(
    $script->{items} = EMC::Common::attributes(
      EMC::Common::hash($script, "items"),
      {
	# A

	#analyze	=> {},				# => Analyze.pm (v)
	#angles		=> {},				# => Types.pm (v)

	# B

	#bonds		=> {},				# => Types.pm (v)

	# C
	
	#clusters	=> {},				# => Clusters.pm (v)
	comments	=> {				# => stages etc. (v)
	  environment	=> 1
	},

	# E

	#emc		=> {},				# => EMC.pm (v)
	#environment	=> {},				# => Environment.pm (v)

	# F

	#field		=> {},				# => Types.pm (v)

	# G

	#groups		=> {},				# => Groups.pm (v)

	# I

	#impropers	=> {},				# => Types.pm (v)

	# L

	#lammps		=> {},				# => LAMMPS.pm (v)
	#loops		=> {},				# => Environment.pm (v)

	# M

	#masses		=> {},				# => References.pm (v)

	# N

	#namd		=> {},				# => NAMD.pm (v)
	#nonbonds	=> {},				# => Parameters.pm (v)

	# O

	options		=> {				# (v)
	  chemistry	=> 1,
	  environment	=> 0,
	  order		=> 100,
	  set		=> \&set_item_options
	},

	# P

	#parameters	=> {},				# => Parameters.pm (v)
	#polymers	=> {},				# => Polymers.pm (v)
	#profiles	=> {},				# => Profiles.pm (v)

	# R

	#references	=> {},				# => References.pm (v)
	#replicas	=> {},				# => Types.pm (v)

	# S

	#shorthand	=> {},				# => EMC.pm (v)
	#stages		=> {},				# => Environment.pm (v)
	structures	=> {				# => stages (v)
	  chemistry	=> 0,
	  environment	=> 1
	},

	# T

	template	=> {				# => stages (v)
	  chemistry	=> 0,
	  environment	=> 1
	},
	#torsions	=> {},				# => Types.pm (v)

	# V
	
	#variables	=> {},				# => Variables.pm (v)
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0,
      set		=> \&set_item_dummy
    }
  );
  return $script;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $script = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($script, "flag");
  my $set = EMC::Common::element($script, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "script_" : "";
  if ($option eq $indicator."dummy") {
    return $flag->{dummy} = EMC::Math::flag($args->[0]);
  }
  return undef;
}


sub set_functions {
  my $script = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($script, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Script::set_commands;
  $set->{context} = \&EMC::Script::set_context;
  $set->{defaults} = \&EMC::Script::set_defaults;
  $set->{options} = \&EMC::Script::set_options;
  $set->{items} = \&EMC::Script::set_items;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $script;
}


sub set_items {
  my $struct = shift(@_);
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return if (EMC::Common::element($options, "comment"));
  
  my $root = EMC::Common::element($struct, "root");
  my $option = EMC::Common::element($struct, "option");
  my $module = EMC::Common::element($struct, "module");
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $i = 0;

  foreach (@{$data}) {
    my @args = @{$_};
    my $line = $lines->[$i++];

  }
  return $root;
}


sub check_items {
  my $root = shift(@_);
  my $items = EMC::Common::element($root, "items");
  my $allowed = EMC::Common::element($root, "options", "items");

  return if (!(defined($items) && defined($allowed)));

  my $flag_env = EMC::Common::element($root, "environment", "flag", "active");

  foreach (sort(keys(%{$items}))) {
    my $item = $items->{$_};
    my $key = $_;

    next if ($key eq "index");
    if (defined($allowed->{$key})) {
      my $flag = $allowed->{$key};
      next if ($flag_env ? $flag->{environment} : $flag->{chemistry});
      EMC::Message::spot("{$flag_env, $flag->{environment}, $flag->{chemistry}}\n");
      EMC::Message::keys("flag = ", $flag);
      EMC::Message::error_line(
	$item->{flag}->{line}, "incorrect mode for item '$key'\n");
    }
    if (EMC::Common::element($item, "flag", "line")) {
      EMC::Message::error_line(
	$item->{flag}->{line}, "unallowed item '$key'\n");
    } else {
      EMC::Message::trace();
      EMC::Message::keys("allowed = ", $allowed);
      EMC::Message::error("unallowed item '$key'\n");
    }
  }
  return $root if (!$flag_env);

  my $stages = $items->{stages};			# check stages

  foreach (sort(keys(%{$stages}))) {
    my $stage_ptr = $stages->{$_};
    my $stage = $_;
    foreach (sort(keys(%{$stage_ptr}))) {
      my $trial_ptr = $stage_ptr->{$_};
      my $trial = $_;
      foreach (sort(keys(%{$trial_ptr}))) {
	next if ($_ eq "index");
	my $item = $trial_ptr->{$_};
	my $key = $_;

	if (!defined($allowed->{$key})) {
	  EMC::Message::error_line(
	    $item->{flag}->{line}, "unallowed item '$key'\n");
	}
	if (!$allowed->{$key}->{environment}) {
	  EMC::Message::error_line(
	    $item->{flag}->{line}, "unallowed item '$key' in environment\n");
	}
      }
    }
  }
  return $root;
}


# options->{items} members
#
#   chemistry	flag if applicable for chemistry mode
#   environment	flag if applicable for environment mode
#   module	pointer to module in root as set by EMC::Options::transcribe()
#   order	execution order: higher numbers are executed sooner
#   set		item interpretation function

sub interpret {
  my $root = shift(@_);
  my $items = EMC::Common::element($root, "items");
  my $list = EMC::Common::element($root, "options", "list", "items");

  return if (!(defined($items) && defined($list)));

  my $flag = EMC::Common::element($root, "global", "flag");
  my $extension = EMC::Common::element($root, "global", "script", "extension");
  my $ignore = {comments => 1, environment => 1, options => 1};
  
  check_items($root);
  $list = [sort({
      $b->[1]->{order} <=> $a->[1]->{order} || 
      $a->[0] <=> $b->[0]} @{$list})];
  #EMC::Message::list("keys = ", [map({$_->[0]} @{$list})]);
  foreach (@{$list}) {
    my $key = $_->[0];
    my $item = $_->[1];

    next if (defined($ignore->{$key}));
    #EMC::Message::spot("key = $key => ".(defined($items->{$key}) ? "" : "un")."defined\n");
    next if (!(defined($item->{set}) && defined($items->{$key})));

    my $options = EMC::Hash::arguments(
      EMC::Common::element($items, $key, "options"));
    my $module = EMC::Common::element($item->{module});
    
    if (!EMC::Common::element($options, "comment")) {
      $item->{set}->({root => $root, 
	  module => $module, option => $key, item => $items->{$key}});
    }
  }
  return $root;
}


# set item

sub set_item {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $option = EMC::Common::element($struct, "option");
  my $module = EMC::Common::element($struct, "module");
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $iline = 0;

  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$iline++];

    # execution
  }
  return $root;
}


sub set_item_dummy {
  my $struct = shift(@_);

  return EMC::Common::element($struct, "root");
}


sub set_item_options {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $variables = EMC::Common::element($root, "emc", "variables", "item");
  my $option = EMC::Common::element($struct, "option");
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $fenv = EMC::Common::element($root, "environment", "flag", "active");
  my $i = 0;

  foreach (@{$data}) {
    my @arg = @{$_};
    #EMC::Message::list("arg = ", $_);
    foreach (@arg) {
      $_ = EMC::Variables::variable_replace($variables, $_) if (!$fenv);
    }
    my $struct = {root => $root,
      line => $lines->[$i++], option => shift(@arg), args => [@arg]};
    my $result = EMC::Options::set_options($root->{options}, $struct);

    if (!defined($result)) {
      EMC::Message::error_line(
	$struct->{line}, "illegal option '$struct->{option}'\n");
    }
  }
  return $root;
}


sub set_item_verbatim {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $module = EMC::Common::element($struct, "module");
  my $option = EMC::Common::element($struct, "option");
  my $data = EMC::Common::element($item, "data");

  $module->{verbatim} = $item;
  return $root;
}


# functions

sub set {
  my $root = shift(@_);
  my $items = shift(@_);
  my $option = shift(@_);

  my $item = EMC::Common::element($items, $option);
  my $set = EMC::Common::element($root, "options", "items", $option, "set");
  
  return 0 if (!(defined($item) && defined($set)));
  $set->({root => $root, option => $option, item => $item});
  return 1;
}


sub read {					# <= read_script
  my $root = shift(@_);
  my $name = shift(@_);
  my $suffix = shift(@_);

  my $emc = EMC::Common::hash($root, "emc");
  my $md = EMC::Common::hash($root, "md");

  return if (!($emc->{flag}->{write}||
	       EMC::MD::get_flags($md, "write", 0)) && !(-e $name));

  my $preprocess = EMC::Common::element($root, "global", "flag", "preprocess");
  my ($stream, $name) = EMC::IO::open($name, "r", $suffix);
  my $data = $preprocess ?
	     EMC::IO::get_preprocess($stream) : EMC::IO::get($stream);
  
  EMC::IO::close($stream, $name);
  EMC::Message::info("reading script from \"$name\"\n");
  
  my $default = $root->{global}->{default};
  my $attr = {
      name => $name, data => $data, stage => $default, trial => $default,
      flag => {
	split => 1, header => 0}, 
      convert => {
	analysis => "analyze", verbatim => "emc"},
      endless => [
	"include", "stage", "trial", "write"], 
      environment => [
	"analyze", "environment", "loops", "variables"],
      env_verbatim => [
	"clusters", "groups", "polymers"],
      env_only => [
	"analyze", "loops", "stage", "trial"],
      locate => [
	"emc", "gromacs", "lammps", "namd", "variables"],
      stage_only => [
	"structures"],
      verbatim => [
	"emc", "field", "gromacs", "lammps", "namd", "template"],
      ignore => [
	"variables"]
    };
  my $items = EMC::Item::read(undef, $attr);

  #EMC::Script::set($root, $items, "variables");
  foreach ("environment", "options") {
    next if (!EMC::Script::set($root, $items, $_));
    if ($_ eq "environment") {
      push(@{$attr->{verbatim}}, "variables");
    } elsif (@{$attr->{env_only}}[-1] eq "variables") {
      pop(@{$attr->{env_only}});
    }
    $items = EMC::Item::read(
      EMC::Common::attributes($attr, {
	  include => [".", @{$root->{global}->{location}->{include}}],
	  flag => EMC::Common::attributes($attr->{flag}, {
	    environment => $root->{environment}->{flag}->{active},
	    preprocess => $root->{global}->{flag}->{preprocess}
	  })
	}
      )
    );
    last;
  }

  $root->{items} = $items;
  return $root;
}

