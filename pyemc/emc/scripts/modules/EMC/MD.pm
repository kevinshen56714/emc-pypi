#!/usr/bin/env perl
#
#  module:	EMC::MD.pm
#  author:	Pieter J. in 't Veld
#  date:	September 3, 2022.
#  purpose:	MD structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "md_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#    modules		ARRAY	array of module names
#
#  notes:
#    20220903	Inception of v1.0
#

package EMC::MD;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::MD'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Chemistry;
use EMC::Common;
use EMC::GROMACS;
use EMC::LAMMPS;
use EMC::Math;
use EMC::NAMD;
use EMC::PDB;
use EMC::XYZ;


# defaults

$EMC::MD::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 3, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $parent = shift(@_);
  my $md = EMC::Common::hash(EMC::Common::element($parent));
  my $attr = EMC::Common::attributes(@_);
  my $modules = {
    gromacs => [\&EMC::GROMACS::construct, $attr],
    lammps => [\&EMC::LAMMPS::construct, $attr],
    namd => [\&EMC::NAMD::construct, $attr],
    pdb => [\&EMC::PDB::construct, $attr],
    xyz => [\&EMC::XYZ::construct, $attr]
  };
  
  $md->{write} = {};
  $md->{modules} = [];
  foreach (sort(keys(%{$modules}))) {
    my $ptr = $modules->{$_};
    $md->{$_} = EMC::Common::hash($md->{$_});
    $md->{$_}->{parent} = $parent;
    push(@{$md->{modules}}, $_);
    $md->{$_} = (scalar(@{$ptr})>1 ? defined($attr) : 0) ? 
		 $ptr->[0]->(\$md->{$_}, $ptr->[1]) : $ptr->[0]->(\$md->{$_});
    $md->{write}->{$_} = $md->{$_}->{write};
  }
  set_functions($md, $attr);
  set_defaults($md);
  set_commands($md);
  return $md;
}


# initialization

sub set_defaults {
  my $md = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $md->{context} = EMC::Common::attributes(
    EMC::Common::hash($md, "context"),
    {
      # E
      
      engine		=> undef,

      # R

      restart_dir	=> "..",

      # S
      
      shake		=> {
	iterations	=> 20,
	output		=> 0,
	tolerance	=> 0.0001
      },
      shear		=> {
	flag		=> 0,
	mode		=> "",
	ramp		=> 100000,
	rate		=> ""
      },

      # T

      timestep		=> undef
    }
  );
  $md->{flag} = EMC::Common::attributes(
    EMC::Common::hash($md, "flag"),
    {
      # R

      restart		=> 0,

      # T

      timestep		=> undef
    }
  );
  $md->{identity} = EMC::Common::attributes(
    EMC::Common::hash($md, "identity"),
    $EMC::MD::Identity
  );
  return $md;
}


sub set_commands {
  my $md = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($md, "set");
  my $flag = EMC::Common::element($md, "flag");
  my $context = EMC::Common::element($md, "context");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated = $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "md_" : "";
 
  $md->{commands} = EMC::Common::hash($md, "commands");
  while (1) {
    my $commands =  {

      # E

      $indicator."engine"	=> {
	comment		=> "set MD engine",
	default		=> $context->{engine}},

      # R

      $indicator."restart"	=> {
	comment		=> "create MD restart script",
	default		=> EMC::Math::boolean($flag->{restart}).
			   ",".$context->{restart_dir}},

      # S
		   
      $indicator."shake"	=> {
	comment		=> "set shake types",
	default		=> "",
	gui		=> ["list", "chemistry", "lammps", "advanced"]},
      $indicator."shake_iterations" => {
	comment		=> "set maximum number of shake iterations",
	default		=> $context->{shake}->{iterations},
	gui		=> ["integer", "chemistry", "lammps", "advanced"]},
      $indicator."shake_output"	=> {
	comment		=> "set shake output frequency",
	default		=> ($context->{shake}->{output} ? $context->{shake}->{output} : "never"),
	gui		=> ["integer", "chemistry", "lammps", "advanced"]},
      $indicator."shake_tolerance" => {
	comment		=> "set shake tolerance",
	default		=> $context->{shake}->{tolerance},
	gui		=> ["real", "chemistry", "lammps", "advanced"]},
      $indicator."shear"	=> {
	comment		=> "add shear paragraph to LAMMPS input script",
	default		=> $context->{shear}->{flag} ? 
			      EMC::Hash::text($context->{shear}, "string") :
			      "false",
	gui		=> ["list", "chemistry", "analysis", "ignore"]},

      # T 

      $indicator."timestep"	=> {
	comment		=> "set integration time step",
	default		=> $context->{timestep},
	gui		=> ["string", "chemistry", "lammps", "standard"]},
    };

    foreach (keys(%{$commands})) {
      my $ptr = $commands->{$_};
      if (!defined($ptr->{set})) {
	$ptr->{original} = $pre.$_ if ($flag_depricated);
	$ptr->{set} = \&EMC::MD::set_options;
      }
    }
    $md->{commands} = EMC::Common::attributes(
      $md->{commands}, $commands
    );
    last if ($indicator eq "" || !$depricated);
    $flag_depricated = 1;
    $indicator = "";
  }

  return $md;
}


sub transfer {
  my $md = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($md, "flag");
  my $context = EMC::Common::element($md, "context");
  
  EMC::Element::transfer(
    [\$::EMC::MD{restart},		\$flag->{restart}],
    [\$::EMC::MD{restart_dir},		\$context->{restart_dir}],
    [\%::EMC::Shake,			\$context->{shake}],
    [\%::EMC::Shear,			\$context->{shear}],
    [\$::EMC::Timestep,			\$context->{timestep}]
  );
}


sub set_context {
  my $md = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($root, "global", "units");
  my $flag = EMC::Common::element($md, "flag");
  my $context = EMC::Common::element($md, "context");

  # E

  if (!defined($md->{engine})) {
    $context->{engine} = get_engine($md);
  }

  # S

  $global->{flag}->{shake} = (
    $field->{type} eq "charmm" ?
      defined($md->{shake}->{flag}) ? EMC::Math::flag($md->{shake}->{flag}) :
      0 : 0) if ($global->{flag}->{shake}<0);

  # T

  $context->{timestep} = (
    $field->{type} eq "dpd" ? 0.025 :
    $field->{type} eq "gauss" ? 0.025 :
    $field->{type} eq "standard" ? 0.005 :
    $field->{type} eq "charmm" ? 2 :
    $field->{type} eq "opls" ? 2 : 1) if (!defined($flag->{timestep}));
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $md = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($md, "flag");
  my $context = EMC::Common::hash($md, "context");
  my $shake = EMC::Common::element($context, "shake");
  my $shear = EMC::Common::element($context, "shear");
  my $set = EMC::Common::element($md, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;

  $indicator = $indicator ? "md_" : "";
  my $i; for ($i=0; $i<=$depricated; ++$i) {

    # E

    if ($option eq $indicator."engine") { 
      $context->{engine} = set_engine($line, $md, $args->[0]);
      return 1;
    }

    # R

    if ($option eq $indicator."restart") { 
      $flag->{restart_dir} = $args->[1] if ($args->[1] ne "");
      return $flag->{restart} = EMC::Math::flag($args->[0]);
    }

    # S

    if ($option eq $indicator."shake") {
      foreach (@{$args}) {
	my @arg = split("=");
	my $n = scalar(@arg);
	my $type = $n<2 ? "active" : shift(@arg);
	my %allowed = (
	  t => "t", type => "t", b => "b", bond => "b", a => "a", angle => "a",
	  m => "m", mass => "m", active => "f"
	);
	my %name = (
	  t => "type", b => "bond", a => "angle", m => "mass", f => "active");
	my %ntypes = (
	  type => 1, bond => 2, angle => 3, mass => 1, active => 1);

	if (!defined($allowed{$type})) {
	  EMC::Message::error_line($line,
	    "unallowed shake mode '$type'\n");
       	}
	@arg = split(":", @arg[0]);
	$type = $name{$allowed{$type}};
	if (scalar(@arg)!=$ntypes{$type}) {
	  EMC::Message::error_line($line,
	    "incorrect number of types for shake mode '$type'\n");
	}
	if ($type eq "active") {
	  $shake->{flag} = EMC::Math::flag($arg[0]); 
	} else {
	  if (!defined($shake->{$type})) { $shake->{$type} = []; }
	  @arg = reverse(@arg) if (@arg[-1] lt @arg[0]);
	  foreach (@arg) {
	    $_ = EMC::Chemistry::strtype($_) if ($type ne "mass");
	  }
	  push(@{$shake->{$type}}, [@arg]);
	  $shake->{flag} = 0;
	}
      }
      return $shake;
    }
    if ($option eq $indicator."shake_iterations") {
      return $shake->{iterations} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."shake_output") {
      return $shake->{output} =
	  $args->[0] eq "never" ? 0 : EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."shake_tolerance") {
      return $shake->{tolerance} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."shear") {
      my $value = EMC::Math::eval($args);
      $context->{shear}->{rate} = $value->[0];
      $context->{shear}->{flag} = EMC::Math::flag($args->[0]); 
      $context->{shear}->{mode} = $args->[1] if (defined($args->[1])); 
      $context->{shear}->{ramp} = $value->[2] if (defined($args->[2]));
      return $shear;
    }

    # T

    if ($option eq $indicator."timestep") {
      $flag->{timestep} = 1;
      return $context->{timestep} = EMC::Math::eval($args->[0])->[0]; }
  
    last if ($indicator eq "");
    $indicator = "";
  }
  return undef;
}


sub set_functions {
  my $md = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($md, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::MD::set_commands;
  $set->{context} = \&EMC::MD::set_context;
  $set->{defaults} = \&EMC::MD::set_defaults;
  $set->{options} = \&EMC::MD::set_options;

  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $md;
}


# EMC script additions

sub write_emc {
  my $stream = shift(@_);
  my $root = shift(@_);
  my $md = EMC::Common::element($root, "md");
  my $write = EMC::Common::element($md, "write");

  return if (!defined($write));

  foreach (sort(keys(%{$write}))) {
    $write->{$_}->{emc}->($stream, $root);
  }
}


# BASH workflow additions

sub write_job {
  my $stream = shift(@_);
  my $root = shift(@_);
  my $md = EMC::Common::element($root, "md");
  my $write = EMC::Common::element($md, "write");

  return if (!defined($write));

  foreach (sort(keys(%{$write}))) {
    $write->{$_}->{job}->($stream, $root);
  }
}


# MD script

sub write_script {
  my $root = shift(@_);
  my $name = shift(@_);
  my $md = EMC::Common::element($root, "md");
  my $write = EMC::Common::element($md, "write");

  return if (!defined($write));

  foreach (sort(keys(%{$write}))) {
    next if (!defined($write->{$_}->{script}));
    $write->{$_}->{script}->($root, $name);
  }
}


# functions

sub get_engines {
  my $md = shift(@_);
  my $modules = EMC::Common::element($md, "modules");
  my $engines = {};
  
  return undef if (!defined($modules));

  foreach (@{$modules}) {
    $engines->{$_} = 1 if (EMC::Common::element($md, $_, "flag", "engine"));
  }
  return $engines;
}


sub get_engine {
  my $md = shift(@_);
  my $engines = get_engines($md);

  foreach (keys(%{$engines})) {
    my $flag = EMC::Common::element($md, $_, "flag");

    next if (!EMC::Common::element($flag, "write"));
    return $_ eq "lammps" ? "$_:$md->{$_}->{context}->{version}" : $_;
  }
  return undef;
}


sub set_engine {
  my $line = shift(@_);
  my $md = shift(@_);
  my $engine = [split(":", shift(@_))];
  my $engines = get_engines($md);

  if (!defined($engines->{$engine->[0]})) {
    EMC::Message::error_line($line, "undefined MD engine '$engine->[0]'\n");
  }
  set_flags($md, "write", 0);
  $md->{$engine->[0]}->{flag}->{write} = 
    defined($engine->[1]) ? EMC::Math::boolean($engine->[1]) : 1;
  if ($engine->[0] eq "lammps" && $engine->[1]>2000) {
    $md->{lammps}->{context}->{version} = $engine->[1];
  }
  return $engine;
}


sub get_flags {					# 0: or, 1: and, 2: xor
  my $md = shift(@_);
  my $key = shift(@_);
  my $oper = shift(@_);
  my $engines = get_engines($md);

  return 0 if (!defined($engines));

  my $value = $oper==1 ? 1 : 0;

  foreach (sort(keys(%{$engines}))) {
    my $flag = EMC::Common::element($md, $_, "flag");
    next if (ref($flag) ne "HASH");
    next if (!defined($flag->{$key}));
    if ($oper == 0) {
      $value |= $flag->{$key};
    } elsif ($oper == 1) {
      $value &= $flag->{$key};
    } elsif ($oper == 2) {
      $value ^= $flag->{$key};
    }
  }
  return $value;
}


sub set_flags {					# <= set_md_flags
  my $md = shift(@_);
  my $key = shift(@_);
  my $value = shift(@_);
  my $engines = get_engines($md);

  return if (!defined($engines));

  foreach (sort(keys(%{$engines}))) {
    my $flag = EMC::Common::element($md, $_, "flag");
    $flag->{$key} = $value if (ref($flag) eq "HASH");
  }
}



