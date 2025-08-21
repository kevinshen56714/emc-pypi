#!/usr/bin/env perl
#
#  module:	EMC::GROMACS.pm
#  author:	Pieter J. in 't Veld
#  date:	May 2, 2024.
#  purpose:	GROMACS structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "gromacs_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20240502	Inception of v1.0
#

package EMC::GROMACS;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::GROMACS'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::Math;
use EMC::Options;
use EMC::PDB;


# defaults

$EMC::GROMACS::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "May 2, 2024",
  version	=> "1.0"
};


# construct

sub construct {
  my $gromacs = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($gromacs, $attr);
  set_identity($gromacs);
  set_defaults($gromacs);
  set_commands($gromacs);
  return $gromacs;
}


# initialization

sub set_identity {
  my $gromacs = EMC::Common::hash(shift(@_));
  
  EMC::Common::attributes(
    EMC::Common::hash($gromacs), {
      identity => $EMC::GROMACS::Identity
    }
  );
  return $gromacs;
}


sub set_defaults {
  my $gromacs = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $gromacs->{defined} = {};
  $gromacs->{context} = EMC::Common::attributes(
    EMC::Common::hash($gromacs, "context"),
    {
      tau_p		=> 2.0,
      tau_t		=> 0.2,
      tequil		=> 1e6,
      trun		=> 1e8,
      timestep		=> 0.002,
      verbatim		=> undef,
      virtual		=> {
	mass		=> 36
      }
    }
  );
  $gromacs->{settings} = EMC::Common::attributes(
    EMC::Common::hash($gromacs, "settings"),
    {
      defaults		=> {
	'acc-grps'		=> '',
	accelerate		=> '',
	adress			=> 'no',
	annealing		=> '',
	'annealing-npoints'	=> '',
	'annealing-temp'	=> '',
	'annealing-time'	=> '',
	awh			=> 'no',
	'bd-fric'		=> 0,
	'bonded-lambdas'	=> '',
	'calc-lambda-neighbors'	=> 1,
	'colvars-active'	=> 'false',
	'comm-grps'		=> '',
	'comm-mode'		=> 'linear',
	'compressed-x-grps'	=> 'system',
	'compressed-x-precision' => 10000,
	compressibility		=> 3e-4,
	'constraint-algorithm'	=> 'lincs',
	constraints		=> 'none',
	continuation		=> 'no',
	'cos-acceleration'	=> 0,
	'coul-lambdas'		=> '',
	'coulomb-modifier'	=> 'potential-shift-verlet',
	coulombtype		=> 'cutoff',
	'couple-intramol'	=> 'no',
	'couple-lambda0'	=> 'vdw-q',
	'couple-lambda1'	=> 'vdw-q',
	'couple-moltype'	=> '',
	'cutoff-scheme'		=> 'Verlet',
	define			=> '',
	deform			=> '',
	'deform-init-flow'	=> 'no',
	'delta-lambda'		=> 0,
	'density-guided-simulation-active' => 'false',
	dh_hist_size		=> 0,
	dh_hist_spacing		=> 0.1,
	'dhdl-derivatives'	=> 'yes',
	'dhdl-print-energy'	=> 'no',
	dispcorr		=> 'no',
	disre			=> 'no',
	'disre-fc'		=> 1000,
	'disre-mixed'		=> 'no',
	'disre-tau'		=> 0,
	'disre-weighting'	=> 'conservative',
	dt			=> 0.02,
	'electric-field-x'	=> '0 0 0 0',
	'electric-field-y'	=> '0 0 0 0',
	'electric-field-z'	=> '0 0 0 0',
	emstep			=> 0.01,
	emtol			=> 10,
	'energygrp-excl'	=> '',
	'energygrp-table'	=> '',
	energygrps		=> 'system',
	'ensemble-temperature'	=> -1,
	'ensemble-temperature-setting' => 'auto',
	'epsilon-rf'		=> 0,
	'epsilon-surface'	=> 0,
	epsilon_r		=> 15,
	'ewald-geometry'	=> '3d',
	'ewald-rtol'		=> 1e-05,
	'ewald-rtol-lj'		=> 0.001,
	fcstep			=> 0,
	'fep-lambdas'		=> '',
	'fourier-nx'		=> 0,
	'fourier-ny'		=> 0,
	'fourier-nz'		=> 0,
	fourierspacing		=> 0.125,
	'free-energy'		=> 'no',
	freezedim		=> '',
	freezegrps		=> '',
	gen_seed		=> "SEED",
	gen_temp		=> 298.15,
	gen_vel			=> 'no',
	'imd-group'		=> '',
	'implicit-solvent'	=> 'no',
	include			=> '',
	'init-lambda'		=> -1,
	'init-lambda-state'	=> -1,
	'init-lambda-weights'	=> '',
	'init-step'		=> 0,
	integrator		=> 'md',
	'ld-seed'		=> -1,
	'lincs-iter'		=> 1,
	'lincs-order'		=> 4,
	'lincs-warnangle'	=> 30,
	'lj-pme-comb-rule'	=> 'geometric',
	'mass-lambdas'		=> '',
	'mass-repartition-factor' => 1,
	morse			=> 'no',
	mts			=> 'no',
	nbfgscorr		=> 10,
	'nh-chain-length'	=> 10,
	niter			=> 20,
	nstcalcenergy		=> 100,
	nstcgsteep		=> 1000,
	nstcomm			=> 100,
	nstdhdl			=> 50,
	nstdisreout		=> 100,
	nstenergy		=> 10000,
	nsteps			=> 50000,
	nstfout			=> 0,
	nstlist			=> 20,
	nstlog			=> 10000,
	nstorireout		=> 100,
	nstpcouple		=> -1,
	nsttcouple		=> -1,
	nstvout			=> 0,
	nstxout			=> 0,
	'nstxout-compressed'	=> 10000,
	nwall			=> 0,
	orire			=> 'no',
	'orire-fc'		=> 0,
	'orire-fitgrp'		=> '',
	'orire-tau'		=> 0,
	pcoupl			=> 'c-rescale',
	pcoupltype		=> 'isotropic',
	pbc			=> 'xyz',
	'periodic-molecules'	=> 'no',
	'pme-order'		=> 4,
	'print-nose-hoover-chain-variables' => 'no',
	pull			=> 'no',
	qmmm			=> 'no',
	'qmmm-cp2k-active'	=> 'false',
	'qmmm-grps'		=> '',
	rcoulomb		=> 1.1,
	'rcoulomb-switch'	=> 0,
	ref_p			=> 1.0,
	ref_t			=> 298.15,
	'refcoord-scaling'	=> 'no',
	'restraint-lambdas'	=> '',
	rlist			=> 1,
	rotation		=> 'no',
	rtpi			=> 0.05,
	rvdw			=> 1.1,
	'rvdw-switch'		=> 0,
	'sc-alpha'		=> 0,
	'sc-coul'		=> 'no',
	'sc-function'		=> 'beutler',
	'sc-gapsys-scale-linpoint-lj' => 0.85,
	'sc-gapsys-scale-linpoint-q' => 0.3,
	'sc-gapsys-sigma-lj'	=> 0.3,
	'sc-power'		=> 1,
	'sc-r-power'		=> 6,
	'sc-sigma'		=> 0.3,
	'separate-dhdl-file'	=> 'yes',
	'shake-sor'		=> 'no',
	'shake-tol'		=> 0.0001,
	'sim-temp-high'		=> 300,
	'sim-temp-low'		=> 300,
	'simulated-tempering'	=> 'no',
	'simulated-tempering-scaling' => 'geometric',
	'simulation-part'	=> 1,
	swapcoords		=> 'no',
	'table-extension'	=> 1,
	tau_p			=> 4.0,
	tau_t			=> 1.0,
	'tc-grps'		=> 'system',
	tcoupl			=> 'v-rescale',
	'temperature-lambdas'	=> '',
	tinit			=> 0,
	'user1-grps'		=> '',
	'user2-grps'		=> '',
	userint1		=> 0,
	userint2		=> 0,
	userint3		=> 0,
	userint4		=> 0,
	userreal1		=> 0,
	userreal2		=> 0,
	userreal3		=> 0,
	userreal4		=> 0,
	'vdw-lambdas'		=> '',
	'vdw-modifier'		=> 'potential-shift-verlet',
	vdw_type		=> 'cutoff',
	'verlet-buffer-pressure-tolerance' => 0.5,
	'verlet-buffer-tolerance' => 0.005,
	'wall-atomtype'		=> '',
	'wall-density'		=> '',
	'wall-ewald-zfac'	=> 3,
	'wall-r-linpot'		=> -1,
	'wall-type'		=> '9-3'
      },
      equilibrate		=> {
	active			=> 1,
	#define			=> '-DPOSRES',
	integrator		=> 'md',
	nsteps			=> 0,
	dt			=> 0,
	nstxout			=> 5000000,
	'nstxout-compressed'	=> 2500,
	nstvout			=> 2500,
	nstenergy		=> 2500,
	nstlog			=> 2500,
	constraint_algorithm	=> 'lincs',
	constraints		=> 'h-bonds',
	lincs_iter		=> 1,
	lincs_order		=> 4,
	'cutoff-scheme'		=> 'verlet',
	nstlist			=> 20,
	rcoulomb		=> 1.0,
	rvdw			=> 1.0,
	dispcorr		=> 'enerpres',
	'vdw-modifier'		=> 'potential-shift-verlet',
	coulombtype		=> 'pme',
	pme_order		=> 4,
	fourierspacing		=> 0.125,
	tcoupl			=> 'v-rescale',
	'tc-grps'		=> 'protein non-protein',
	tau_t			=> 0.1,
	ref_t			=> 300,
	pcoupl			=> 'c-rescale',
	pcoupltype		=> 'isotropic',
	tau_p			=> 2.0,
	ref_p			=> 1.0,
	compressibility		=> 4.5e-5,
	pbc			=> 'xyz',
	continuation		=> 'no',
	gen_vel			=> 'yes',
	gen_temp		=> 300,
	gen_seed		=> "SEED"
      },
      minimize			=> {
	active			=> 1,
	integrator		=> 'steep',
	emtol			=> 1000.0,
	emstep			=> 0.01,
	nsteps			=> 50000,
	nstlist			=> 20,
	'cutoff-scheme'		=> 'verlet',
	coulombtype		=> 'pme',
	rcoulomb		=> 1.0,
	rvdw			=> 1.0,
	pbc			=> 'xyz'
      },
      run			=> {
	active			=> 1,
	integrator		=> 'md',
	nsteps			=> 0,
	dt			=> 0,
	nstxout			=> 0,
	'nstxout-compressed'	=> 5000,
	nstvout			=> 5000,
	nstenergy		=> 5000,
	nstlog			=> 5000,
	constraint_algorithm	=> 'lincs',
	constraints		=> 'h-bonds',
	lincs_iter		=> 1,
	lincs_order		=> 4,
	'cutoff-scheme'		=> 'verlet',
	nstlist			=> 20,
	rcoulomb		=> 1.0,
	rvdw			=> 1.0,
	dispcorr		=> 'EnerPres',
	'vdw-modifier'		=> 'potential-shift-verlet',
	coulombtype		=> 'PME',
	pme_order		=> 4,
	fourierspacing		=> 0.125,
	tcoupl			=> 'v-rescale',
	'tc-grps'		=> 'protein non-protein',
	tau_t			=> '0.1 0.1',
	ref_t			=> '300 300',
	pcoupl			=> 'parrinello-rahman',
	pcoupltype		=> 'isotropic',
	tau_p			=> 2.0,
	ref_p			=> 1.0,
	compressibility		=> 4.5e-5,
	pbc			=> 'xyz',
	continuation		=> 'yes',
	gen_vel			=> 'no'
      }
    }
  );
  $gromacs->{flag} = EMC::Common::attributes(
    EMC::Common::hash($gromacs, "flag"),
    {
      atom		=> "index",
      compress		=> 0,
      engine		=> 1,
      fixed		=> 1,
      hexadecimal	=> 0,
      modes		=> ["minimize", "equilibrate", "run"],
      parameters	=> 1,
      pbc		=> 1,
      residue		=> "index",
      rigid		=> 1,
      segment		=> "index",
      script		=> {
	equilibrate	=> 1,
	minimize	=> 1,
	run		=> 1
      },
      trun		=> 0,
      unwrap		=> 1,
      write		=> 0
    }
  );
  $gromacs->{script} = EMC::Common::attributes(
    EMC::Common::hash($gromacs, "script"),
    {
      spot		=> {
	head		=> 0,
	tail		=> 1,
	false		=> 0,
	true		=> 1,
	0		=> 0,
	1		=> 1,
	"-1"		=> 1
      }
    }
  );
  $gromacs->{identity} = EMC::Common::attributes(
    EMC::Common::hash($gromacs, "identity"),
    $EMC::GROMACS::Identity
  );
  return $gromacs;
}


sub transfer {
  my $gromacs = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($gromacs, "flag");
  my $context = EMC::Common::element($gromacs, "context");
}


sub set_context {
  my $gromacs = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($gromacs, "flag");
  my $context = EMC::Common::element($gromacs, "context");
}


sub set_commands {
  my $gromacs = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($gromacs, "set");
  my $context = EMC::Common::element($gromacs, "context");
  my $flag = EMC::Common::element($gromacs, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated = $indicator ? 0 : $depricated;
  my $pre = $indicator = "gromacs_";

  $gromacs->{commands} = EMC::Common::hash($gromacs, "commands");
   
  my $commands = {
    
    # C

    $indicator."compress"	=> {
      comment		=> "set compression",
      default		=> EMC::Math::boolean($flag->{compress}),
      gui		=> ["option", "chemistry", "emc", "advanced"]
    },

    # G

    gromacs		=> {
      comment		=> "create GROMACS input",
      default		=> EMC::Math::boolean($flag->{write}),
      gui		=> ["boolean", "chemistry", "gromacs", "ignore"],
    },

    # H

    $indicator."hexadecimal"	=> {
      comment		=> "set hexadecimal index output in coordinate file",
      default		=> EMC::Math::boolean($flag->{hexadecimal}),
      gui		=> ["boolean", "chemistry", "emc", "ignore"]},

    # M

    $indicator."modes"	=> {
      comment		=> "execution modes",
      default		=> EMC::List::string($flag->{modes}, {parens => 0}),
      gui		=> ["boolean", "chemistry", "emc", "ignore"]},

    # P

    $indicator."parameters"	=> {
      comment		=> "generate parameter file",
      default		=> EMC::Math::boolean($flag->{parameters}),
      gui		=> ["boolean", "chemistry", "emc", "ignore"]},
    $indicator."pbc"	=> {
      comment		=> "apply periodic boundary conditions to coordinates",
      default		=> EMC::Math::boolean($flag->{pbc}),
      gui		=> ["boolean", "chemistry", "emc", "ignore"]},
    $indicator."pdamp"	=> {
      comment		=> "set barostat damping constant",
      default		=> $context->{pdamp},
      gui		=> ["real", "chemistry", "gromacs", "advanced"]},

    # R

    $indicator."residue"	=> {
      comment		=> "set residue name behavior",
      default		=> $flag->{residue},
      gui		=> ["option", "chemistry", "emc", "advanced", "detect,index,series"]},
    $indicator."rigid"	=> {
      comment		=> "do not unwrap rigid sites",
      default		=> EMC::Math::boolean($flag->{rigid}),
      gui		=> ["boolean", "chemistry", "emc", "ignore"]},

    # S

    $indicator."script"	=> {
      comment		=> "set active execution",
      default		=> EMC::Hash::text($flag->{script}, "boolean"),
      gui		=> ["boolean", "chemistry", "emc", "ignore"]},
    $indicator."segment"	=> {
      comment		=> "set segment name behavior",
      default		=> $flag->{segment},
      gui		=> ["option", "chemistry", "emc", "advanced", "detect,index,series"]},
    $indicator."settings"	=> {
      comment		=> "control all settings in .mdp (see GROMACS manual)",
      default		=> "-",
      gui		=> ["boolean", "chemistry", "gromacs", "ignore"]},

    # U

    $indicator."unwrap"	=> {
      comment		=> "apply unwrapping",
      default		=> EMC::EMC::flag_unwrap($flag->{unwrap}),
      gui		=> ["boolean", "chemistry", "emc", "advanced"]},

    # T

    $indicator."tdamp"	=> {
      comment		=> "set thermostat damping constant",
      default		=> $context->{tdamp},
      gui		=> ["string", "chemistry", "gromacs", "advanced"]},
    $indicator."tequil"	=> {
      comment		=> "set equilibration time",
      default		=> $context->{tequil},
      gui		=> ["string", "chemistry", "gromacs", "advanced"]},
    $indicator."timestep" => {
      comment		=> "set global time step",
      default		=> $context->{timestep},
      gui		=> ["string", "chemistry", "gromacs", "advanced"]},
    $indicator."trun"	=> {
      comment		=> "set run time",
      default		=> $context->{trun},
      gui		=> ["string", "chemistry", "gromacs", "advanced"]}

    # V

    #$indicator."virtual"	=> {
    #  comment		=> "set virtual site defaults",
    #  default		=> EMC::Hash::text($context->{virtual}, "string"),
    #  gui		=> ["list", "chemistry", "gromacs", "ignore"]}   
  };

  EMC::Options::set_command(
    $gromacs->{commands} = EMC::Common::attributes(
      $gromacs->{commands}, $commands
    ),
    {
      set		=> \&EMC::GROMACS::set_options
    }
  );
  
  EMC::Options::set_command(
    $gromacs->{items} = EMC::Common::attributes(
      EMC::Common::hash($gromacs, "items"),
      {
	gromacs		=> {
	}
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0,
      set		=> \&EMC::Script::set_item_verbatim
    }
  );

  return $gromacs;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $gromacs = EMC::Common::element($struct, "module");
  my $global = EMC::Common::hash($root, "global");
  my $context = EMC::Common::hash($gromacs, "context");
  my $flag = EMC::Common::hash($gromacs, "flag");
  my $defined = EMC::Common::hash($gromacs, "defined");
  my $set = EMC::Common::element($gromacs, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "gromacs_" : "";

  # A

  if ($option eq $indicator."atom") {
    return $flag->{atom} = EMC::PDB::set_flag("atom", $args->[0], $line); }

  # C

  if ($option eq $indicator."compress") {
    return $flag->{compress} = EMC::Math::flag($args->[0]); }

  # F

  if ($option eq $indicator."fixed") {
    return $flag->{fixed} = EMC::Math::flag($args->[0]); }

  # H

  if ($option eq $indicator."hexadecimal") {
    return $flag->{hexadecimal} = EMC::Math::flag($args->[0]); }

  # G

  if ($option eq "gromacs") {
    my $result = EMC::Math::flag($args->[0]);
    if ($result) {
      EMC::MD::set_flags(
	EMC::Common::element($gromacs, "parent"), "write", 0);
      $flag->{write} = $result;
    }
    return $result;
  }

  # M

  if ($option eq $indicator."modes") {
    $flag->{modes} = [@{$args}];
    foreach (keys(%{$flag->{script}})) {
      $flag->{script}->{$_} = 0;
    };
    foreach (@{$args}) {
      $flag->{script}->{$_} = 1;
    }
    return $flag->{modes};
  }

  # P

  if ($option eq $indicator."parameters") {
    return $flag->{parameters} = EMC::Math::flag($args->[0]); }
  if ($option eq $indicator."pbc") {
    return $flag->{pbc} = EMC::Math::flag($args->[0]); }

  # R

  if ($option eq $indicator."rank") {
    return $flag->{rank} = EMC::Math::flag($args->[0]); }
  if ($option eq $indicator."residue") {
    return $flag->{residue} = EMC::PDB::set_flag("residue", $args->[0], $line); }
  if ($option eq $indicator."rigid") {
    return $flag->{rigid} = EMC::Math::flag($args->[0]); }

  # S

  if ($option eq $indicator."script") {
    EMC::Hash::set($line, $flag->{script}, "boolean", "", [], @{$args});
    return $flag->{script};
  }
  if ($option eq $indicator."segment") {
    return $flag->{segment} = EMC::PDB::set_flag("segment", $args->[0], $line); }

  # T

  if ($option eq $indicator."tau_p") {
    $defined->{tau_p} = 1;
    return $context->{tau_p} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."tau_t") {
    $defined->{tau_t} = 1;
    return $context->{tau_t} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."tequil") {
    $defined->{tequil} = 1;
    return $context->{tequil} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."timestep") {
    $defined->{timestep} = 1;
    return $context->{timestep} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."trun") {
    if (($flag->{trun} = $args->[0] eq "-" ? 0 : 1)) {
      my @s = @{$args};
      @s[0] = EMC::Math::eval(@s[0])->[0];
      $context->{trun} = scalar(@s)<2 ? @s[0] : "\"".join(" ", @s)."\"";
    }
    return $flag->{trun};
  }

  # U

  if ($option eq $indicator."unwrap") {
    return $flag->{unwrap} = EMC::EMC::flag_unwrap($args->[0]); }

  # V

  if ($option eq $indicator."virtual") {
    EMC::Hash::set($line, $context->{virtual}, "string", "", [], @{$args});
    return $context->{virtual};
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
  my $gromacs = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($gromacs, "flag");
  my $set = EMC::Common::element($gromacs, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "gromacs_" : "";
  if ($option eq $indicator."dummy") {
    return $flag->{dummy} = EMC::Math::flag($args->[0]);
  }
  return undef;
}


sub set_functions {
  my $gromacs = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($gromacs, "set");
  my $write = EMC::Common::hash($gromacs, "write");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&set_commands;
  $set->{context} = \&set_context;
  $set->{defaults} = \&set_defaults;
  $set->{options} = \&set_options;
  $set->{items} = \&set_items;
  
  $write->{emc} = \&EMC::GROMACS::write_emc;
  $write->{job} = \&EMC::GROMACS::write_job;
  $write->{script} = \&EMC::GROMACS::write_script;

  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $gromacs;
}


# GROMACS script

sub write_script {
  my $root = shift(@_);
  my $name = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $project = EMC::Common::element($global, "project", "name");
  
  my $gromacs = EMC::Common::element($root, "md", "gromacs");
  my $settings = EMC::Common::element($gromacs, "settings");
  my $flag = EMC::Common::element($gromacs, "flag");
  my $modes = EMC::Common::array($flag, "modes");
  
  my $identity = EMC::Common::element($root, "global", "identity");
  my $date = EMC::Common::date_full();

  return if (!defined($flag) || !$flag->{write});

  if ((-e "$name.in")&&!$global->{replace}->{flag}) {
    EMC::Message::warning(
      "\"$name.in\" exists; use -replace flag to overwrite\n");
    return;
  }

  my $name = "run_gromacs.sh";

  EMC::Message::info("creating GROMACS execution script \"$name\"\n");

  my $stream = EMC::IO::open($name, "w");
  my $id = "$identity->{script} v$identity->{version}, $identity->{date}";

  chmod(0700, $name);
  printf($stream "#!/bin/bash
#
#  script:	$name
#  author:	Created by $id
#  date:	$date
#  purpose:	GROMACS run workflow; this script is auto-generated.
#

# defaults

backup=-1;
build=\"../build\";
exec=\"gmx_mpi\";
mode=(0 0 0);
project=\"$project\";
restart=\".\";
seed=-1;

# functions

run() {
  echo \"\$@\";
  \"\$@\";
}

script_header() {
  echo \"Wrap-around for GROMACS; created by $id\";
  echo;
}

script_timestamp() {
  echo \"# $name \$1 at \$(date)\";
  echo;
}

script_help() {
  echo \"Usage:\";
  echo \"  $name -n nprocs [-option [value]]\";
  echo;
  echo \"Options:\";
  echo -e \"  -help\t\tthis message\";
  echo -e \"  -backup\tset backup frequency [\${backup}]\";
  echo -e \"  -build\tset build directory [\${build}]\";
  echo -e \"  -modes\tset run modes [\${modes}]\";
  echo -e \"  -exec\t\tset executable [\${exec}]\";
  echo -e \"  -n\t\tset number of processors\";
  echo -e \"  -nprocs\tset number of processors\";
  echo -e \"  -project\tset project name [\${project}]\";
  echo -e \"  -restart\tset restart source [\${restart}]\";
  echo -e \"  -seed\t\tset seed [\${seed}]\";
  echo -e \"\";
  echo -e \"Notes:\";
  echo -e \"  -run modes: minimize, equilibrate, and run\";
  echo;
  exit -1;
}

init() {
  local i modes command;

  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -*)	command=\$1;;
    esac;
    case \"\$1\" in
      -help)	script_help;;
      -backup)	shift; backup=\$1;;
      -build)	shift; build=\"\$1\";;
      -exec)	shift; exec=\"\$1\";;
      -modes)	shift; modes=\"\$1\";;
      -n)	shift; nprocs=\$1;;
      -nprocs)	shift; nprocs=\$1;;
      -project)	shift; project=\"\$1\";;
      -restart)	shift; restart=\"\$1\";;
      -seed)	shift; seed=\$1;;
      -*)	script_help;;
      *)	if [ \"\${command}\" == \"-modes\" ]; then
		  \${modes}=\"\${modes} \$1\";
		else
		  script_help;
		fi;;
    esac;
    shift;
  done;
  error=();
  if [ \"\${nprocs}\" == \"\" ]; then
    error=(\"\${error[@]}\" \"number of processors not set\");
  fi;
  for i in \$(echo \${modes}); do
    if [ \$i == minimize ]; then mode[0]=1;
    elif [ \$i == equilibrate ]; then mode[1]=1;
    elif [ \$i == run ]; then mode[2]=1;
    else error=(\"\${error[@]}\" \"illegal run mode \'\$i\'\"); fi;
  done;
  if [ \${#error[@]} != 0 ]; then
    for i in \"\${error[@]}\"; do
      echo \"ERROR: \$i\";
    done;
    echo;
    exit -1;
  fi;
  if [ \${seed} == -1 ]; then
    seed=\$(date +%%s);
  fi;
}

# main

{
  script_header;
  
  init \"\$@\";
  export GMX_MAXBACKUP=\$backup;
  dir=\$(dirname \$0);

  script_timestamp started;

  if [ \${mode[0]} == 1 ]; then
    echo \"# minimize\";
    echo;
    replace.pl SEED \${seed} \${dir}/equilibrate.mdp;
    run \${exec} grompp -f \${dir}/minimize.mdp \\
      -c \"\${build}/\${project}.gro\" \\
      -p \"\${build}/\${project}.top\" \\
      -o \${project}.tpr;
    run mpiexec -n \${nprocs} \\
      \${exec} mdrun -s \${project}.tpr -o \${project}.trr;
    run \${exec} grompp -f \${dir}/equilibrate.mdp \\
      -c confout.gro -p \"\${build}/\${project}.top\" -o \${project}.tpr;
    echo;
  fi;
  
  if [ \${mode[1]} == 1 ]; then
    echo \"# equilibrate\";
    echo;
    if [ \${mode[0]} != 1 ]; then
      replace.pl SEED \${seed} \${dir}/equilibrate.mdp;
      run \${exec} grompp -f \${dir}/equilibrate.mdp \\
	-c \"\${build}/\${project}.gro\" \\
	-p \"\${build}/\${project}.top\" \\
	-o \${project}.tpr;
    fi;
    run mpiexec -n \${nprocs} \\
      \${exec} mdrun -s \${project}.tpr -o \${project}.trr -cpo \${project}.cpt;
    echo
  fi;
  
  if [ \${mode[2]} == 1 ]; then
    echo \"# run\";
    echo;
    run \${exec} grompp -f \${dir}/run.mdp \\
      -c \"\${build}/\${project}.gro\" -p \"\${build}/\${project}.top\" \\
      -t \"\${restart}/\${project}.cpt\" -o \${project}.tpr;
    run mpiexec -n \$nprocs \\
      \${exec} mdrun -s \${project}.tpr -o \${project}.trr -cpo \${project}.cpt;
    echo;
  fi;

  script_timestamp ended;
}
");
  EMC::IO::close($stream);

  foreach (@{$modes}) {
    next if (!$settings->{$_}->{active});
    write_input($root, $gromacs, $_, "default");
  }
}


sub write_input {
  my ($root, $gromacs, $stage, $spot) = @_[0..3];
  my $md = EMC::Common::element($gromacs, "parent");
  my $context = EMC::Common::element($gromacs, "context");
  my $defined = EMC::Common::element($gromacs, "defined");
  my $verbatim = EMC::Common::element($gromacs, "verbatim");
  my $data = EMC::Common::element($verbatim, $stage, $spot, "data");
  my $lines = EMC::Common::element($verbatim, $stage, $spot, "lines");
  my $settings = EMC::Common::element($gromacs, "settings", $stage);

  if (EMC::Common::element($md, "flag", "timestep")) {
    if (!EMC::Common::element($defined, "timestep")) {
      $context->{timestep} = 1e-3*$md->{context}->{timestep};
    }
  }
  set_clusters($root, $gromacs, $stage) if (defined($settings->{tau_t}));
  $settings->{nsteps} = $context->{tequil} if ($stage eq "equilibrate");
  $settings->{nsteps} = $context->{trun} if ($stage eq "run");
  if ($stage eq "equilibrate" || $stage eq "run" ) {
    $settings->{dt} = $context->{timestep};
  }
  if ((ref($data) eq "ARRAY") && scalar(@{$data}))
  {
    my $defaults = EMC::Common::element($gromacs, "settings", "defaults");
    my $convert = {dt => "timestep", nsteps => "trun"};
    my $i = 0;

    $settings = EMC::Element::deep_copy($settings) if (defined($settings));
    foreach (keys(%{$convert})) {
      next if (!defined($settings->{$_}));
      $settings->{$_} = $context->{$convert->{$_}};
    }
    foreach (@{$data}) {
      my $line = $lines->[$i++];
      my @arg;

      next if (substr($_,0,1) eq "#");
      foreach (split(" ")) {
	next if ($_ eq "=");
	last if (substr($_,0,1) eq ";");
	push(@arg, $_);
      }
      next if (!scalar(@arg));
      my $keyword = shift(@arg);
      if ($keyword eq "active") {
	$settings->{active} = EMC::Math::boolean(@arg[0]);
	next;
      }
      if (!defined($defaults->{$keyword})) {
	EMC::Message::error_line($line,
	  "unallowed GROMACS keyword '$keyword'\n");
      }
      $settings->{$keyword} = join(" ", @arg);
    }
  }

  return if (!$settings->{active});

  my $identity = EMC::Common::element($root, "global", "identity");
  my $date = EMC::Common::date_full();
  my $stream = EMC::IO::open($stage.".mdp", "w");
  
  EMC::Message::info("creating GROMACS \"$stage.mdp\"\n");
  printf($stream ";
;  script:	$stage.mdp
;  author:	Created by $identity->{script} v$identity->{version}, $identity->{date}
;  date:	$date
;  purpose:	Manage GROMACS operations
;
");
  foreach (sort(keys(%{$settings}))) {
    my $keyword = $_;
    next if ($keyword eq "active");
    $keyword .= " " x (23-length($keyword)) if (length($keyword)<24);
    printf($stream "%s = %s\n", $keyword, $settings->{$_});
  }
  EMC::IO::close($stream);
}


sub set_clusters {
  my $root = shift(@_);
  my $gromacs = shift(@_);
  my $stage = shift(@_);

  my $settings = EMC::Common::element($gromacs, "settings", $stage);

  return if (!defined($settings->{tau_t}));
  
  my $polymers = EMC::Common::element($root, "emc", "polymers", "polymer");
  my $temperature = EMC::Common::element($root, "global", "temperature");
  my $tau_t = EMC::Common::element($gromacs, "context", "tau_t");

  my $set = {ref_t => [], tau_t => [], 'tc-grps' => []};
  my $groups = {};

  foreach (sort(keys(%{$polymers}))) {
    foreach (@{$polymers->{$_}->{data}}) {
      my $ptr = $_;
      foreach (@{$ptr->{groups}}) {
	++$groups->{$_};
      }
    }
  }
  foreach (sort(keys(%{$groups}))) {
    push(@{$set->{ref_t}}, $temperature);
    push(@{$set->{tau_t}}, $tau_t);
    push(@{$set->{'tc-grps'}}, $_);
  }
  foreach (keys(%{$set})) {
    $settings->{$_} = join(" ", @{$set->{$_}});
  }
}


# EMC script additions

sub write_emc {
  my $pdb = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $emc_flag = EMC::Common::element($root, "emc", "flag");
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $flag = EMC::Common::element($pdb, "flag");

  return if ($emc_flag->{test});
  return if (!(defined($flag) && $flag->{write}));
  return if ($emc_flag->{exclude}->{build});

  printf($stream "\ngromacs\t\t= {name -> output,");
  printf($stream " compress -> ".EMC::Math::boolean($flag->{compress}).",");
  printf($stream "\n\t\t  ");
  printf($stream " forcefield -> $field->{type},");
  printf($stream " detect -> false,");
  printf($stream " hexadecimal -> ".EMC::Math::boolean($flag->{hexadecimal}).",");
  printf($stream "\n\t\t  ");
  printf($stream " unwrap -> ".EMC::Math::boolean($flag->{unwrap}).",");
  printf($stream " pbc -> ".EMC::Math::boolean($flag->{pbc}).",");
  printf($stream " atom -> $flag->{atom},");
  printf($stream " residue -> $flag->{residue},");
  printf($stream "\n\t\t  ");
  printf($stream " segment -> $flag->{segment},");
  printf($stream " fixed -> ".EMC::Math::boolean($flag->{fixed}).",");
  printf($stream " rigid -> ".EMC::Math::boolean($flag->{rigid}).",");
  printf($stream "\n\t\t  ");
  printf($stream " parameters -> ".EMC::Math::boolean($flag->{parameters}));
  printf($stream "};\n");
}


# BASH jobs workflow additions

sub write_job {
  my $gromacs = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $global = EMC::Common::element($root, "global");
  my $context = EMC::Common::element($gromacs, "context");
  my $flag = EMC::Common::element($gromacs, "flag");
  my $project_name = EMC::Common::element($global, "project", "name");

  return if (!(defined($flag) && $flag->{write}));

  my $md = EMC::Common::element($root, "md", "context");
  my $md_flag = EMC::Common::element($root, "md", "flag");
  my $restart_dir = EMC::Common::element($md, "restart_dir");
  my $restart_name = "\${restart_dir}/*/*.restart?";
  my $restart_file = $md_flag->{restart} ? "\n".
    "  else\n".
    "    frestart=1;\n".
    "    restart=\$(first \$(ls -1t $restart_name));\n".
    "    if [ ! -e \"\${restart}\" ]; then\n".
    "      printf \"# $restart_name does not exist -> skipped\\n\\n\";\n".
    "      run cd \${WORKDIR};\n".
    "      return;\n".
    "    fi;\n".
    "    restart=\"-file \\\"'ls -1td $restart_name'\\\"\";" : "";
  my $shear_line = $global->{shear}->{rate} ? "\n      -var framp ".(
      $global->{shear}->{ramp} eq "" ? 0 : $global->{shear}->{ramp} eq "false" ? 0 : 1)." \\" : "";
  my $run_line = $flag->{trun} ?
      ($context->{trun} ne "" ? "\n\t-var trun ".eval($context->{trun})." \\" : "") : "";
  my $modes = [];

  foreach (@{$flag->{modes}}) {
    push(@{$modes}, $_) if ($flag->{script}->{$_});
  }
  $modes = join(" ", @{$modes});
  printf($stream
"
run_md() {
  local dir=\"\$1\"; shift;
  local frestart=\"\$1\"; shift;
  local ncores=\"\$1\"; shift;

  printf \"### \${dir}\\n\\n\";
  if [ ! -e \${dir} ]; then
    run mkdir -p \${dir};
  fi;

  local source=\"\$(path \"\${dir}\")\";
  local build=\"\$(path \"\${dir}/../build\")\";
  local restart_dir=\"\$(path ".(
    $md_flag->{restart} ? "$restart_dir" : "\${dir}/..").")\";
  local output file modes;
  
  if [ \${fbuild} != 1 ]; then
    if [ ! -e \${build}/$project_name.gro ]; then
      printf \"# ../build/$project_name.gro does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${build}/$project_name.top ]; then
      printf \"# ../build/$project_name.top does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
  fi;

  if [ \${freplace} != 1 ]; then
    if [ \${frestart} != 1 ]; then
      if [ -e \${dir}/$project_name.cpt ]; then
	printf \"# $project_name.cpt exists -> skipped\\n\\n\";
	run_null;
	return;
      fi;
    else
      if [ \${ferror} == 1 ]; then
	if [ -e \"\$(first \${restart_dir}/*/$project_name.out)\" ]; then
	  file=\$(first \$(ls -1t \${restart_dir}/*/$project_name.out));
	  if [ \"\$(grep ERROR \${file})\" != \"\" ]; then
	    run_null;
	    return;
	  fi;
	else
	  frestart=0;
	fi;
      fi;
    fi;
  fi;

  if [ \${frestart} == 1 ]; then
    modes=(run);
  else
    modes=($modes);
  fi;
  
  run cd \${dir};

  for mode in \${modes[@]}; do
    if [ ! -e \${build}/\${mode}.mdp ]; then
      printf \"# ../build/\${mode}.mdp does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    run cp \${build}/\${mode}.mdp .;
    replace.pl SEED \${SEED} \${mode}.mdp;
    SEED=\$(calc \${SEED}+1);
  done;
    
  set -f;
  WALLTIME=\${RUN_WALLTIME};
  run_pack -n \${ncores} -dir \"\${dir}\" -single \\
    -walltime \${RUN_WALLTIME} -starttime \${START_TIME} -queue \${QUEUE} \\
    -output $project_name.out -project $project_name \\
      \${build}/run_gromacs.sh \\
        -nprocs \${ncores} \\
	-project $project_name \\
	-restart \"\${restart_dir}\" \\
	-modes \"\${modes[@]}\"
  set +f;

  run cd \"\${WORKDIR}\";
  echo;
}

set_restart() {
  RESTART=(\$1/*/*.cpt);
  echo \"\${RESTART[0]}\";
}
"); 
}


# functions

# import

sub get {
  my $name = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $quiet = EMC::Common::element($attr, "quiet");
  my $stream;
  my $gromacs;

  EMC::Message::info("reading gromacs field from '$name'\n") if (!$quiet);
  $stream = EMC::IO::open($name, "r");
  $gromacs = EMC::GROMACS::read($stream, $attr);
  EMC::IO::close($stream, $name);

  return $gromacs;
}


sub attribute {
  return defined(@_[0]->{@_[1]}) ? @_[0]->{@_[1]} : @_[2];
}


sub read {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $kconstraint = attribute($attr, "kconstraint", 20000);
  my $virtual_mass = attribute($attr, "virtual_mass", 36);
  my $gromacs = EMC::Common::hash($attr, "gromacs");
  my $root = EMC::Common::element($attr, "root");
  my $guide = {

    # types

    angletypes => {item => "angle", func => \&read_angletypes},
    atomtypes => {item => "mass", func => \&read_atomtypes},
    bondtypes => {item => "bond", func => \&read_bondtypes},
    constrainttypes => {item => "constraint", func => \&read_constrainttypes},
    defaults => {item => "nonbond", func => \&read_defaults},
    dihedraltypes => {item => "torsion", func => \&read_dihedraltypes},
    moleculetype => {item => "molecule", func => \&read_moleculetype},
    nonbond_params => {item => "nonbond", func => \&read_nonbond_params},
    pairtypes => {item => "nonbond", func => \&read_pair14},

    # data
    
    atoms => {item => "mass", func => \&read_atoms},
    angles => {item => "angle", func => \&read_bonded},
    bonds => {item => "bond", func => \&read_bonded},
    constraints => {item => "bond", func => \&read_bonded},
    dihedrals => {item => "torsion", func => \&read_bonded},
    exclusions => {item => "exclusions", func => \&read_exclusions},
    impropers => {item => "improper", func => \&read_bonded},
    pairs => {item => "nonbond", func => \&read_pairs},
    pairs_nb => {item => "nonbond", func => \&read_pairs_nb},
    virtual_sites2 => {item => "virtual", func => \&read_virtual},
    virtual_sites3 => {item => "virtual", func => \&read_virtual},
    virtual_sites4 => {item => "virtual", func => \&read_virtual},
    virtual_sitesn => {item => "virtual", func => \&read_virtual}
  };
  my $similar = {
    angletypes => "angles",
    bondtypes => "bonds",
    constrainttypes => "constraints",
    dihedraltypes => "dihedrals",
    nonbond_params => "pairs",
    pairtypes => "pairs",
  };
  my $unit = {
    length => 10.0,		# Angstrom/nm
    energy => 1.0/4.184		# cal/J
  };
  my $functions = {
    angles => {
      ntypes => 3,
      func => {
	1 => {type => "harmonic", nconstants => 2, constants => ["theta", "k"],
	  units => [1, $unit->{energy}]},
	#2 => {type => "g96", nconstants => 2, constants => ["theta", "k"],
	2 => {type => "harmonic", nconstants => 2, constants => ["theta", "k"],
	  units => [1, $unit->{energy}]},
	3 => {type => "bond-bond", nconstants => 3,
	  constants => ["l1", "l2", "k"],
	  units => [
	    $unit->{length}, $unit->{length},
	    $unit->{energy}/$unit->{length}**2]},
	4 => {type => "bond-angle", nconstants => 4,
	  constants => ["l1", "l2", "l3", "k"],
	  units => [
	    $unit->{length}, $unit->{length}, $unit->{length},
	    $unit->{energy}/$unit->{length}**2]},
	5 => {type => "urey-bradley", nconstants => 4,
	  constants => ["theta", "k", "l", "kUB"],
	  units => [
	    1, $unit->{energy}, 
	    $unit->{length}, $unit->{energy}/$unit->{length}**2]},
	6 => {type => "quartic", nconstants => 6,
	  constants => ["theta", "k0", "k1", "k2", "k3", "k4"],
	  units => [
	    1, $unit->{energy}, $unit->{energy}, $unit->{energy},
	    $unit->{energy}, $unit->{energy}]},
	8 => {type => "table", nconstants => 2, constants => ["itable", "k"],
	  units => [1, $unit->{energy}]},
	9 => {type => "linear", nconstants => 2, constants => ["a0", "k"],
	  units => [1, $unit->{energy}/$unit->{length}**2]},
	#10 => {type => "restrict", nconstants => 2, constants => ["theta", "k"],
	10 => {type => "harmonic", nconstants => 2, constants => ["theta", "k"],
	  units => [1, $unit->{energy}]}
      }
    },
    atomtypes => {
      ntypes => 1,
      func => {
	1 => {
	  constants => ["mass", "name", "ncons", "charge", "comment"]
	}
      }
    },
    bonds => {
      ntypes => 2,
      func => {
	1 => {type => "harmonic", nconstants => 2, constants => ["l0", "k"],
	  units => [$unit->{length}, $unit->{energy}/$unit->{length}**2]},
	2 => {type => "quartic", nconstants => 2, constants => ["l0", "k"],
	  units => [$unit->{length}, $unit->{energy}/$unit->{length}**4]},
	3 => {type => "morse", nconstants => 3, constants => ["l0", "D", "beta"],
	  units => [$unit->{length}, $unit->{energy}, 1.0/$unit->{length}]},
	4 => {type => "cubic", nconstants => 3, constants => ["l0", "k2", "k3"],
	  units => [$unit->{length}, $unit->{energy}/$unit->{length}**2,
	    $unit->{energy}/$unit->{length}**3]},
	5 => {type => "connect", nconstants => 0, constants => [],
	  units => []},
	6 => {type => "harmonic", nconstants => 2, constants => ["l0", "k"],
	  units => [$unit->{length}, $unit->{energy}/$unit->{length}**2]},
	7 => {type => "fene", nconstants => 2, constants => ["l0", "k"],
	  units => [$unit->{length}, $unit->{energy}/$unit->{length}**2]},
	8 => {type => "table", nconstants => 2, constants => ["itable", "k"],
	  units => [1, $unit->{energy}]},
	9 => {type => "table", nconstants => 2, constants => ["itable", "k"],
	  units => [1, $unit->{energy}]}
      }
    },
    constraints => {
      ntypes => 2,
      func => {
	1 => {type => "harmonic", nconstants => [1,2], constants => ["l0", "k"],
	  units => [$unit->{length}], k => $kconstraint},
	2 => {type => "harmonic", nconstants => [1,2], constants => ["l0", "k"],
	  units => [$unit->{length}], k => $kconstraint},
      }
    },
    dihedrals => {
      ntypes => 4,
      func => {
	1 => {type => "proper", nconstants => 3, constants => ["phi", "k", "n"],
	  units => [1, $unit->{energy}, 1]},
	2 => {type => "improper", nconstants => 2, constants => ["psi", "k"],
	  units => [1, $unit->{energy}]},
	3 => {type => "ryckaert-bellemans", nconstants => 6,
	  constants => ["k0", "k1", "k2", "k3", "k4", "k5"],
	  units => [
	    $unit->{energy}, $unit->{energy}, $unit->{energy},
	    $unit->{energy}, $unit->{energy}, $unit->{energy}]},
	4 => {type => "improper", nconstants => 3,
	  constants => ["phi", "k", "n"], units => [1, $unit->{energy}, 1]},
	5 => {type => "fourier", nconstants => 5,
	  constants => ["k1", "k2", "k3", "k4", "k5"],
	  units => [
	    $unit->{energy}, $unit->{energy}, $unit->{energy},
	    $unit->{energy}, $unit->{energy}]},
	8 => {type => "table", nconstants => 2, constants => ["itable", "k"],
	  units => [1, $unit->{energy}]},
	9 => {type => "proper", nconstants => 3,
	  constants => ["phi", "k", "n"],	# multiple
	  units => [1, $unit->{energy}, 1]},
	10 => {type => "restrict", nconstants => 2, constants => ["phi", "k"],
	  units => [1, $unit->{energy}]}
      }
    },
    pairs => {
      ntypes => 2,
      func => {
	1 => {type => "lj", coul => 0, constants => ["V", "W"],
	  units => [
	    $unit->{energy}*$unit->{length}**6,
	    $unit->{energy}*$unit->{length}**12
	  ]},
	2 => {type => "lj", coul => 1,
	  constants => ["fudge", "q1", "q2", "V", "W"],
	  units => [
	    1, 1, 1,
	    $unit->{energy}*$unit->{length}**6,
	    $unit->{energy}*$unit->{length}**12
	  ]}
      }
    },
    pairs_nb => {
      ntypes => 2,
      func => {
	1 => {type => "lj", coul => 1,
	  constants => ["q1", "q2", "V", "W"],
	  units => [
	    1, 1,
	    $unit->{energy}*$unit->{length}**6,
	    $unit->{energy}*$unit->{length}**12
	  ]},
      }
    },
    virtual_sites2 => {
      ntypes => 2,
      func => {
	1 => {type => "harmonic", nconstants => 1, constants => ["a"],
	  units => [1]
	}
      }
    },
    virtual_sites3 => {
      ntypes => 3,
      func => {
	1 => {type => "harmonic", nconstants => 2, constants => ["a", "b"],
	  units => [1, 1]
	},
	2 => {type => "harmonic", nconstants => 2, constants => ["a", "d"],
	  units => [1, $unit->{length}]
	},
	3 => {type => "harmonic", nconstants => 2, constants => ["theta", "d"],
	  units => [1, $unit->{length}]
	},
	4 => {type => "harmonic", nconstants => 3, constants => ["a", "b", "c"],
	  units => [1, 1, 1/$unit->{length}]
	}
      }
    },
    virtual_sites4 => {
      ntypes => 3,
      func => {
	1 => {type => "harmonic", nconstants => 3, constants => ["a", "b", "c"],
	  units => [1, 1, $unit->{length}]
	}
      }
    },
    virtual_sitesn => {
      ntypes => 1,
      func => {
	1 => {type => "harmonic"}
      }
    }
  };
  my $comment;
  my $name;
  my $func;
  my $item;
  my $key;
  my $line;
  my $header;
  my $n_if = 0;
  my $f_skip = 0;
  my $global = {};

  $gromacs->{field} = $attr->{field} if (defined($attr->{field}));

  foreach (keys(%{$similar})) {
    $functions->{$_} = $functions->{$similar->{$_}};
  }

  foreach (ref($stream) eq "" ? split("\n", $stream) : <$stream>) {
    ++$line;
    chomp();

    #printf("%4d: %s\n", $line, $_);		# verbatim

    if (substr($_,0,1) eq "#") {		# filter out directives
      my @a = split(" ");
      ++$n_if if (substr(@a[0],0,3) eq "#if");
      $f_skip = 1 if (@a[0] eq "#ifdef");
      if (@a[0] eq "#endif") {
	if (--$n_if<0) {
	  EMC::Message::error_line($line, "unbalanced #endif");
	}
	$f_skip = 0 if (!$n_if);
      }
      next;
    }
    next if ($f_skip);

    if (substr($_,0,1) eq ";") {		# check for header
      my $arg = [split(" ")];
      my $tmp = shift(@{$arg});
      $comment = join(" ", @{$arg});
      $header = $comment if ($tmp eq ";;;;;;");
      next if (defined($key));
      next if (!($_ =~ m/ \- /));
      my @a = split(" - ", $comment);
      $global->{names}->{@a[0]} = @a[1];
      next;
    }

    if (substr($_,0,1) eq "[") {		# check for keyword
      $key = EMC::Common::trim(EMC::Common::strip($_));
      #EMC::Message::spot("key = $key\n");
      #EMC::Message::spot("name = $name\n") if ($key eq "atoms");
      next if (!defined($guide->{$key}));
      $item = EMC::Common::hash($gromacs, $guide->{$key}->{item});
      if (!defined($item->{flag})) {
	$item->{flag} = {array => 0, cmap => 0, first => 1};
      }
      $func = $guide->{$key}->{func};
      $name = defined($header) ? $header : $comment;
      undef($header);
      next;
    } elsif (!defined($item)) {
      next;
    }
    my $arg = EMC::List::drop(";", [split(" ")]);
    my $functions = EMC::Common::element($functions, $key);

    next if (!defined($arg));
    my $attr = {
      line => $line,  guide => $guide, gromacs => $gromacs, key => $key,
      item => $item, functions => $functions, arg => $arg, name => $name,
      comment => $comment, global => $global
    };

    $func->($stream, $attr);			# execute handling 
  }
  apply_virtual(
    $gromacs, {kconstraint => $kconstraint, virtual_mass => $virtual_mass});
  create_parameters($gromacs);
  #EMC::Message::dumper("gromacs = ", $gromacs);
  return $gromacs;
}  


# read types

sub read_angletypes {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));

}


sub init_mass {
  my $item = shift(@_);

  if (!defined($item->{index})) {
    $item->{flag}->{ntypes} = 1;
    $item->{index} = ["type", "mass", "name", "ncons", "charge", "comment"];
  }
  $item->{data} = {} if (!defined($item->{data}));
  return $item;
}


sub read_atomtypes {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};
  my $item = init_mass($attr->{item});
  my $arg = $attr->{arg};

  my $n = scalar(@{$arg});
  my $ptr = EMC::Common::list($item, "data", $arg->[0]);

  while (scalar(@{$ptr})<4) {
    push(@{$ptr}, 0);
  }
  $ptr->[1] = $arg->[0];		# type/name
  if ($n==2) {
    $ptr->[0] = eval($arg->[1]);	# mass
  } elsif ($n>5) {
    $ptr->[0] = eval($arg->[-5]);	# mass
    $ptr->[3] = eval($arg->[-4]);	# charge
    #$ptr = EMC::Common::attributes($ptr, {
    #	mass => eval($arg->[-5]), charge => eval($arg->[-4]),
    #   ptype => $arg->[-3], v => eval($arg->[-2]), w => eval($arg->[-1])
    #  }
    #);
    #$ptr->{atomnr} = eval($arg->[-6]) if ($n>6);
    #$ptr->{bondtype} = eval($arg->[-7]) if ($n>7);
  }
  EMC::Fields::equivalence($attr->{gromacs}, $arg->[0]);
}


sub read_bondtypes {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));

}


sub read_constrainttypes {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));

}


sub read_defaults {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};
  my $item = $attr->{item};
  my $arg = $attr->{arg};

  return if (scalar(@{$arg})<2);
  $item->{flag}->{func} = $arg->[0];
  $item->{flag}->{mix} = $arg->[1];
  $item->{flag}->{generate} = $arg->[2] eq "yes" ? 1 : 0;
  $item->{flag}->{fudgeLJ} = defined($arg->[3]) ? $arg->[3] : 1;
  $item->{flag}->{fudgeQQ} = defined($arg->[4]) ? $arg->[3] : 1;
}


sub read_dihedraltypes {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));

}


sub read_moleculetype {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};
  my $item = $attr->{item};
  my $arg = $attr->{arg};

  if (scalar(@{$arg})!=2) {
    EMC::Message::error_line($attr->{line},
      "illegal number of moleculetype entries\n");
  }
  if (defined($item->{flag}->{nbonded})) {
    if ($item->{flag}->{nbonded}!=$arg->[1]) {
      EMC::Message::error_line($attr->{line},
	"inconsistent nbonded ($item->{flag}->{nbonded}!=$arg->[1])\n");
    }
  } else {
    $item->{flag}->{nbonded} = $arg->[1];
  }
  my $global = $attr->{global};

  $global->{current} = EMC::Common::hash($item, "data", $arg->[0]);
  $global->{current}->{molecule} = $arg->[0];
  my $name = EMC::Common::element($global, "names", $arg->[0]);
  $global->{current}->{name} = $name ne "" ? $name : lc($attr->{name});
  $global->{current}->{resname} = $arg->[0];
}


sub read_nonbond_params {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};
  my $item = $attr->{item};
  my $arg = $attr->{arg};
  my $flag = $item->{flag};

  return if (scalar(@{$arg})<4);

  if ($flag->{func}!=$arg->[2]) {
    EMC::Message::error_line($attr->{line}, "inconsistent nonbond function\n");
  }
  if (!defined($functions->{func}->{$arg->[2]})) {
    EMC::Message::error_line($attr->{line}, "illegal nonbond function\n");
  }
  
  my $func = $functions->{func}->{$arg->[2]};
  my $sigma = eval($arg->[3]);
  my $epsilon = eval($arg->[4]);

  if (!defined($item->{index})) {
    $item->{flag}->{type} = $func->{type};
    $item->{flag}->{ntypes} = $functions->{ntypes};
    $item->{flag}->{index} = ["sigma", "epsilon"];
    $item->{index} = ["type1", "type2", "sigma", "epsilon"];
  }
  $item->{data} = {} if (!defined($item->{data}));
  if ($flag->{mix}==1) {
    my $s6 = $epsilon/$sigma;
    $epsilon = 0.25*$sigma/$s6;
    $sigma = $s6**(1/6);
  }
  my @a = ($sigma, $epsilon);
  my @t = EMC::Fields::arrange($arg->[0], $arg->[1]);
  my $data = EMC::Common::list($item, "data", @t, join("\t", @a));
  $data->[0] = [undef, @t];
}


sub read_pair14 {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $item = $attr->{item};
  my $arg = $attr->{arg};

}


# read data

# gromacs => {
#   molecule => {	# populated by atoms, used by bonds, angles, dihedrals
#     atom = [
#	{type, res, resname, atom, id, cgnr, charge}
#     ]
#   }
# }
# 
# $attr->{global}->{current} points to current item in gromacs; used mainly by
# bonds, angles, and dihedrals after gromacs->molecule has been populated
#

sub connect {
  my $atoms = shift(@_);
  my @ids = ref(@_[0]) eq "ARRAY" ? @_ : [@_];

  for (my $reverse=0; $reverse<2; ++$reverse) {
    foreach (@ids) {
      my @id = $reverse ? reverse(@{$_}) : @{$_};
      for (my $i=0; $i<scalar(@id)-1; ++$i) {
	if (!defined($atoms->[@id[$i]]->{connect})) {
	  $atoms->[@id[$i]]->{connect} = [];
	}
	my $connects = $atoms->[@id[$i]]->{connect};
	my $iconnect = @id[$i+1];
	next if (grep($_==$iconnect, @{$connects}));
	push(@{$connects}, $iconnect);
      }
    }
  }
  return $atoms;
}


sub read_atoms {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  
  my $functions = $attr->{functions};
  my $gromacs = $attr->{gromacs};
  my $global = $attr->{global};
  my $item = $attr->{item};
  my $arg = $attr->{arg};
  my $line = $attr->{line};
  my $n = scalar(@{$arg}); 

  if ($n<7 || $n>8) {
    EMC::Message::error_line(
      $attr->{line}, "illegal number of atom arguments\n");
  }
  if (!defined($global->{current})) {
    EMC::Message::error_line($attr->{line}, "moleculetype was not defined\n");
  }
  my $current = $global->{current};
  $current->{atom} = [] if (!defined($current->{atom}));
  my $type = $arg->[1];
  my $ptr = $current->{atom}->[$arg->[0]-1] = {
    line => $line, type => $type, resid => $arg->[2],
    resname => defined($current->{resname}) ? $current->{resname} : $arg->[3],
    atomname => $arg->[4], cgnr => $arg->[5], charge => eval($arg->[6])
  };
  ++$gromacs->{atom}->{$arg->[1]}->{n};
  return if ($n<8);

  $ptr->{mass} = eval($arg->[7]);

  my $mass = init_mass(EMC::Common::hash($gromacs, "mass"));

  $mass->{flag}->{ntypes} = 1;
  $mass = EMC::Common::element($gromacs, "mass", "data", $type);
  if ($mass) {
    return if ($mass->[0]==$ptr->{mass});		# => to apply_virtual
    #EMC::Message::spot("need for new type '$type'\n");
  } else {
    $mass = EMC::Common::hash($gromacs, "mass", "data");
    $mass->{$type} = [$ptr->{mass}, $type, 0, $ptr->{charge}];
    EMC::Fields::equivalence($gromacs, $type);
  }
}


sub read_bonded {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $arg = $attr->{arg};
  
  my $global = $attr->{global};

  if (!defined($global->{current})) {
    EMC::Message::error_line($attr->{line}, "moleculetype was not defined\n");
  }

  my $current = $global->{current};

  if (!defined($current->{atom})) {
    EMC::Message::error_line($attr->{line}, "atoms have not been defined\n");
  }

  my $key = $attr->{key};
  my $item = $attr->{item};
  my $atom = $current->{atom};
  my $functions = $attr->{functions};
  my $id = $attr->{guide}->{$key}->{item};
  my $n = $functions->{ntypes};
  my @a = map({eval($_)} @{$arg});
  my @i = map({$_-1} splice(@a, 0, $n));
  my @t = EMC::Fields::arrange(map($atom->[$_]->{type}, @i));
  my $func = EMC::Common::element($functions, "func", shift(@a));
  my $nconst = $func->{nconstants};
  my $nargs = [];

  foreach (ref($nconst) eq "ARRAY" ? @{$nconst} : ($nconst, $nconst)) {
    push(@{$nargs}, $_+$n+1);
  } 
  if (!defined($func)) {
    EMC::Message::error_line($attr->{line}, "illegal keyword '$key'\n");
  }
  if (scalar(@{$arg})<$nargs->[0] || scalar(@{$arg})>$nargs->[1]) {
    EMC::Message::error_line(
      $attr->{line}, "illegal number of arguments for keyword '$key'\n");
  }
  if ($func->{type} eq "improper") {
    $id = "improper";
    @t[0,1] = @t[1,0];
    @t = EMC::Fields::arrange_imp(@t);
    $item = EMC::Common::hash($attr, "gromacs", "improper");
  }
  if (!defined($item->{index})) {
    $item->{flag}->{type} = $func->{type};
    $item->{flag}->{ntypes} = $functions->{ntypes};
    $item->{flag}->{index} = [@{$func->{constants}}];
    $item->{index} = [map("type$_", (1..$n)), @{$func->{constants}}];
  }
  next if ($func->{type} eq "restrict");
  if ($func->{type} ne $item->{flag}->{type}) {
    EMC::Message::error_line($attr->{line},
      "inconsistent $key functions ($func->{type} != $item->{flag}->{type})\n");
  }
  if ($func->{type} ne "improper") {
    @i = EMC::Fields::arrange(@i);
    for (my $j=0; $j<$n-1; ++$j) { EMC::GROMACS::connect($atom, @i[$j,$j+1]); }
    for (my $j=$n-1; $j>0; --$j) { EMC::GROMACS::connect($atom, @i[$j,$j-1]); }
  } else {
    @i = EMC::Fields::arrange_imp(@i);
  }
  if ($key eq "constraints" && scalar(@{$arg}) == $nargs->[0]) {
    @a[1] = $func->{k};
  }
  my $data = EMC::Common::list($current, "parameters", $id);
  my $entry =  [join("\t", @a), @i];
  foreach (@i) {
    my $bonded = EMC::Common::list($atom->[$_], "bonded");
    push(@{$bonded}, $entry);
  }
  push(@{$data}, $entry);
  return if ($id ne "bond");
  $atom->[@i[0]]->{length}->{@i[1]} = @a[0];
  $atom->[@i[1]]->{length}->{@i[0]} = @a[0];
}


sub read_constraints {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};

}


sub read_dihedrals {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};

}


sub read_exclusions {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};

}


sub read_pairs {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};

}


sub read_pairs_nb {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};

}


sub read_virtual {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));

  my $global = $attr->{global};
  my $current = $global->{current};
  my $atom = $current->{atom};

  my $key = $attr->{key};
  my $type = $attr->{type};
  my $functions = $attr->{functions};
  my $func = $functions->{func};
  my @arg = @{$attr->{arg}};
  my $atom = $current->{atom}->[shift(@arg)-1];

  my $ifunc;
  my @connect;
  my $constants;

  if ($key eq "virtual_sitesn") {
    $ifunc = shift(@arg);
    @connect = @arg;
  } else {
    for (my $i=0; $i<$functions->{ntypes}; ++$i) {
      push(@connect, shift(@arg));
    }
    $ifunc = shift(@arg);
  }
  
  if (!defined($func->{$ifunc})) {
    EMC::Message::error_line($attr->{line}, "illegal function reference\n");
  }
  $func = $func->{$ifunc};
  if (defined($func->{nconstants})) {
    for (my $i=0; $i<$func->{nconstants}; ++$i) {
      $constants->{$func->{constants}->[$i]} = $func->{units}->[$i]*@arg[$i];
    }
  }
  $atom->{virtual} = {
    connect => [map($_-1, @connect)],
    type => substr($key,-1,1),
    constants => $constants,
    function => $ifunc
  };
}


sub get_type {
  my $gromacs = shift(@_);
  my $attr = shift(@_);
  my $atom = EMC::Common::element($attr, "atom");	# alternative atom
  my $eqv = EMC::Common::element($attr, "eqv");		# alternative eqv
  my $ftype = EMC::Common::element($attr, "ftype");	# ff parameter type
  my $index = EMC::Common::element($attr, "index");	# varying key index
  my $istart = EMC::Common::element($attr, "istart");	# starting type index
  my $item = EMC::Common::element($attr, "item");	# alternative item
  my $key = EMC::Common::element($attr, "key");		# key when defined
  my $mass = EMC::Common::element($attr, "mass");	# mass != masses
  my $name = EMC::Common::element($attr, "name");	# resname
  my $typei = EMC::Common::element($attr, "type");	# source type
  
  my $masses = EMC::Common::hash($gromacs, "mass", "data");
  
  $atom = EMC::Common::hash($gromacs, "atom") if (!$atom);
  $eqv = EMC::Common::element($gromacs, "equivalence", "data") if (!$eqv);
  my $type0 = defined($eqv->{$typei}) ? $eqv->{$typei}->[0] : $typei;
  $istart = EMC::Common::element($atom, $type0, "i") if (!defined($istart));
  $item = EMC::Common::hash($gromacs, $ftype, "data") if (!$item);
  $mass = defined($masses->{$typei}) ? $masses->{$typei}->[0] : undef if (!$mass);

  my $arrange = $ftype eq "improper" ?
    \&EMC::Fields::arrange_imp : \&EMC::Fields::arrange;
  my $offset = {
    nonbond => 0, increment => 1, bond => 2, angle => 3, torsion => 4,
    improper => 5};
  my $noffset = 6;
  my $typen;
  
  # masses

  # use exisiting if not alternative

  if ($key) {
    my $i;
    my $niters = EMC::Common::element($attr, "niters");

    $niters = 100 if (!$niters);

    #print(join("\t", __LINE__.":", ">GET<", $type0, $istart), "\n");
    for ($i=$istart; $i<$niters; ++$i) {
      $typen = $type0.($i ? $i : "");
      if ($mass && defined($masses->{$typen})) {	# skip unequal mass
	next if ($masses->{$typen}->[0] != $mass);
      }
      my @t = @{$key};					# skip existing keys
      @t[$index] = $typen;
      @t = $arrange->(@t);
      $atom->{$type0}->{i} = $i if ($atom->{$type0}->{i}<$i);
      #print(join("\t", __LINE__.":", "", ">TRY<", $typen, $i), "\n");
      last if (!EMC::Common::element($item, $arrange->(@t)));
    }
    if ($i==$niters) {
      EMC::Message::error("too many extra types for type '$type0'\n");
    }
  } else {
    $typen = $type0.++$atom->{$type0}->{i};		# create new type
  }
  
  if (!defined($masses->{$typen})) {			# update mass
    EMC::Message::info(
      "creating mass entry for type '$typen' from '$type0' ".
      (defined($name) ? "for '$name'" : "")."\n");
    $masses->{$typen} = defined($masses->{$typei}) ?
      [@{$masses->{$typei}}] : [$mass, $type0, 0, 0];
  }

  # equivalence

  if (!defined($eqv->{$typen})) {			# update equivalence
    $eqv->{$typen} =
      defined($eqv->{$typei}) ? [@{$eqv->{$typei}}] : [($type0) x 6];
    for (my $i=$offset->{$ftype}; $i<$noffset; ++$i) {
      $eqv->{$typen}->[$i] = $typen;
    }
  }

  # align

  $gromacs->{atom}->{$typen}->{i} = $atom->{$type0}->{i};
  return $typen;
}


sub find_mass {
  my $gromacs = shift(@_);
  my $type = shift(@_);
  my $mass = shift(@_);
  my $nconnects = shift(@_);

  my $eqv = EMC::Common::element($gromacs, "equivalence", "data");
  my $masses = EMC::Common::hash($gromacs, "mass", "data");

  if (defined($eqv)) {
    $type = $eqv->{$type}->[0] if (defined($eqv->{$type}));
  }
  if (defined($masses->{$type})) {
    return $type if ($masses->{$type}->[0]==$mass);
  } else {
    $masses->{$type} = [$mass, $type, 0, 0];
    return $type;
  }

  my $atom = EMC::Common::hash($gromacs, "atom");
  my $n = $atom->{$type}->{i};
  
  my $typen;
  my $i;

  for ($i=1; $i<=$n; ++$i) {
    $typen = $type.$i;
    if (defined($masses->{$typen})) {
      return $typen if ($masses->{$typen}->[0]==$mass);
    }
  }
  $typen = $type.$i;
  $atom->{$type}->{i} = $atom->{$typen}->{i} = $i;
  $masses->{$typen} = [$mass, $type, 0, 0];
  EMC::Fields::equivalence($gromacs, $typen, $type, $type, $typen);
  EMC::Message::info("creating mass entry for type '$typen' from '$type'\n");
  return $typen;
}


sub apply_virtual {
  my $gromacs = shift(@_);
  my $attr = shift(@_);
  my $kconstraint = $attr->{kconstraint};
  my $virtual_mass = $attr->{virtual_mass};
  my $molecules = $gromacs->{molecule}->{data};
  my $masses = EMC::Common::hash($gromacs, "mass", "data");
  my $equivalence = EMC::Common::element($gromacs, "equivalence", "data");

  EMC::Message::info("checking for virtual sites\n");
  foreach (sort(keys(%{$molecules}))) {
    my $name = $_;
    my $molecule = $molecules->{$name};
    my $atoms = $molecule->{atom};
    my $iatom = -1;
    my $virtual = 0;
    my $clusters = [];

    foreach (@{$atoms}) {				# reset and connect
      my $atom = $_;
      
      ++$iatom;
      undef($atom->{cluster});
      if (!defined($atom->{mass})) {
	if (defined($masses->{$atom->{type}})) {
	  $atom->{mass} = $masses->{$atom->{type}}->[0];
	}
      }
      next if (!defined($atom->{virtual}));
      next if (defined($atom->{connect}));
      foreach (sort(@{$atom->{virtual}->{connect}})) {
	EMC::GROMACS::connect($atoms, $iatom, $_);
      }
      $virtual = 1;
    }
    next if (!$virtual);

    $iatom = -1;
    foreach (@{$atoms}) {				# determine clusters
      my $atom = $_;

      ++$iatom;
      next if ($atom->{mass});

      my $nconnects = 
	defined($atom->{connect}) ? scalar(@{$atom->{connect}}) : 0;

      if ($nconnects) {
	my $cluster = EMC::Common::hash($atom, "cluster");

	push(@{$clusters}, $cluster);
	++$cluster->{null}->{$iatom};
	foreach (@{$atom->{connect}}) {
	  my $connect = $atoms->[$_];
	  my $icluster = 
		defined($connect->{cluster}) ? $connect->{cluster} : $cluster;
	  
	  $connect->{cluster} = $icluster;
	  ++$icluster->{$connect->{mass} ? "mass" : "null"}->{$_};
	}
      }
    }
    next if (!scalar(@{$clusters}));

    @{$clusters} = EMC::List::unique(-1, @{$clusters});	# redistribute mass
    foreach (@{$clusters}) {
      my $cluster = $_;
      my $select = {
	null => [sort(keys(%{$cluster->{null}}))],
	mass => [sort(keys(%{$cluster->{mass}}))]
      };
      my $nchange = scalar(@{$select->{mass}});
      my $delta;

      next if (!$nchange);
      foreach (@{$select->{null}}) {
	next if ($atoms->[$_]->{mass});
	$atoms->[$_]->{mass} = $virtual_mass;		# assign
	$delta += $virtual_mass;
      }
      $delta /= $nchange;
      foreach (@{$select->{mass}}) {
	$atoms->[$_]->{mass} -= $delta;			# adjust
      }
    }
    foreach (@{$atoms}) {				# create type when
      my $atom = $_;					# needed

      undef($atom->{cluster});
      $atom->{type} = find_mass($gromacs, $atom->{type}, $atom->{mass});
    }
   
    my $bond = EMC::Common::list($molecule, "parameters", "bond");
    foreach (@{$clusters}) {
      foreach (sort(keys(%{$_->{null}}))) {
	my $iatom = $_;
	my $atom = $atoms->[$_];
	my $site = "[$atom->{resname}:$_]";
	my $id = $atom->{virtual}->{connect};
	my $i;

	if (scalar(@{$id}) != 3) {
	  EMC::Message::warning(
	    "not adding virtual site $site (nconnects != 3)\n");
	  next;
	}
	my $l = [];
	for ($i=0; $i<3; ++$i) {			# determining lengths
	  my $length = EMC::Common::element(
	     $atoms->[$id->[$i]], "length", $id->[($i+1)%3]);
	  last if (!defined($length));
	  push(@{$l}, $length);
	}
	if ($i<3) {
	  EMC::Message::warning(
	    "not adding virtual site $site ".
	    "(missing lengths between connections)\n");
	  next;
	}
	my $l0 = [];
	for ($i=0; $i<3; ++$i) {			# adding bonds
	  push(@{$bond}, [
	    join("\t", 
	      EMC::Math::round(
		sqrt(
		  2.0*($l->[$i]**2+$l->[($i+2)%3]**2)
		  -$l->[($i+1)%3]**2)/3.0, 0.001), $kconstraint),
	    EMC::Fields::arrange($iatom, $id->[$i])]
	  );
	};
      }
    }
  }
}


sub create_list {
  my $connect = shift(@_);
  my $list = ref(@_[0]) eq "ARRAY" ? shift(@_) : [];
  my $id = defined(@_[0]) ? shift(@_) : 0;

  return $list if (defined($connect->[$id]->{visited}));
  $connect->[$id]->{visited} = 1;
  push(@{$list}, $id);
  foreach (@{$connect->[$id]->{connect}}) {
    EMC::GROMACS::create_list($connect, $list, $_);
  }
  return $list;
}


sub create_parameters {
  my $gromacs = shift(@_);
  my $molecules = EMC::Common::element($gromacs, "molecule", "data");
  my $index = {bond => 2, angle => 3, torsion => 4, improper => 5};
  my $eqv = EMC::Common::element($gromacs, "equivalence", "data");
  my $masses = EMC::Common::element($gromacs, "mass", "data");
  my $count = EMC::Common::element($gromacs, "atom");

  return if (!defined($molecules));

  EMC::Message::info("creating parameters\n");

  foreach (sort(keys(%{$molecules}))) {
    my $molecule = $molecules->{$_};
    my $parameters = EMC::Common::element($molecule, "parameters");
    my $atom = EMC::Common::element($molecule, "atom");
    my $name = $molecule->{molecule};
    my $tmp = {};


    next if (!defined($parameters));
    foreach (sort(keys(%{$parameters}))) {
      my $storage = EMC::Common::hash($gromacs, $_, "data");
      my $parameter = $parameters->{$_};
      my $arrange = (
	$_ eq "improper" ? \&EMC::Fields::arrange_imp : \&EMC::Fields::arrange);
      my $collect = {};
      my $doubles = {};
      my $item = {};
      my $ftype = $_;

      # deal with double entries

      foreach (@{$parameter}) {				# collect doubles
	my @arg = @{$_};
	my $key = shift(@arg);
	my @t = $arrange->(map({$atom->[$_]->{type}} @arg));
	my $data = EMC::Common::list($item, @t);
	my $entry = EMC::Common::element($collect, @t);
	
	$doubles->{join("\t", @t)} = 1 if ($entry);
	push(@{EMC::Common::list($collect, @t, $key)}, [@arg]);
      }

      if (scalar(keys(%{$doubles}))) {			# upon doubles
	foreach (sort(keys(%{$doubles}))) {
	  my ($freq, @select);
	  my $entry = EMC::Common::element($collect, split("\t"));

	  foreach (sort(keys(%{$entry}))) {
	    foreach (@{$entry->{$_}}) {
	      my @t = $arrange->(map({$atom->[$_]->{type}} @{$_}));
	      next if (!EMC::Common::element($collect, @t));
	      foreach (@{$_}) { ++$freq->{$_}; }
	      push(@select, $_);
	    }
	  }
	  my $nchange = scalar(@select)-1;		# determine candidates
	  next if (!$nchange);
	  my $list = EMC::List::sort([keys(%{$freq})], $freq);
	  $list = create_list(EMC::GROMACS::connect([], @select), $list->[0]);
	  for (my $i=2; $i<2+$nchange; ++$i) {
	    my $ti = $atom->[$list->[$i]]->{type};
	    my $t0 = $eqv->{$ti}->[0];
	    my ($types, $index);
	    foreach (@select) {
	      next if (!grep({$_ eq $list->[$i]} @{$_}));
	      $index = EMC::List::index($_, $list->[$i]);
	      $types = [map({$atom->[$_]->{type}} @{$_})];
	      last;
	    }
	    $tmp->{$t0}->{i} = $count->{$t0}->{i} if (!defined($tmp->{$t0}));
	    my $tn = get_type($gromacs, {
		atom => $tmp, ftype => $ftype, index => $index, 
		item => $item, key => $types,
		mass => $masses->{$ti}->[0], name => $name, type => $ti
	      });
	    if ($tmp->{$t0}->{i}>$count->{$tn}->{i}) {
	      $count->{$tn}->{i} = $tmp->{$t0}->{i};
	    }
	    $atom->[$list->[$i]]->{type} = $tn;
	  }
	}
      }

      # register parameters

      foreach (@{$parameter}) {
	my @arg = @{$_};
	my $key = shift(@arg);
	my @t = $arrange->(map({$atom->[$_]->{type}} @arg));
	my $data = EMC::Common::list($storage, @t, $key);
	
	push(@{$data}, [$atom->[0]->{resname}, @arg]);
      }
    }
  }
}


# conversion

sub copy_item {
  my $entry = shift(@_);
  my $item = shift(@_);

  foreach ("flag", "index", "data") {
    next if (defined($entry->{$_}));
    $entry->{$_} = EMC::Element::deep_copy($item->{$_});
  }
  return $entry;
}


sub to_field {
  my $gromacs = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $type = EMC::Common::element($attr, "type");
  my $field = EMC::Common::hash($attr, "field");
  
  if (defined($gromacs->{equivalence})) {
    $field->{equivalence} = EMC::Element::deep_copy($gromacs->{equivalence});
  }

  my $eqv = EMC::Common::hash($field, "equivalence", "data");
  my $molecules = EMC::Common::element($gromacs, "molecule", "data");
  my $count = EMC::Common::element($gromacs, "atom");
  my $mass = EMC::Common::element($gromacs, "mass", "data");

  my $convert = {
    martini => {
      mass => {
        index => ["mass", "name", "ncons", "charge", "comment"]
      },
      bond => {
	type => "harmonic",
	index => ["k", "l0"]
      },
      angle => {
	type => "harmonic",
	index => ["k", "theta"]
      },
      torsion => {
	type => "harmonic",
	index => ["k", "phi", "n"]
      },
      improper => {
	type => "harmonic",
	index => ["k", "psi"]
      },
      nonbond => {
	type => "lj",
	index => ["sigma", "epsilon"]
      }
    }
  };

  my $order = [
    "equivalence", "nonbond", "bond", "angle", "torsion", "improper", "mass"];

  if (!defined($convert->{$type})) {
    EMC::Message::error("unsupported field type '$type'\n");
  }
  $convert = $convert->{$type};

  EMC::Message::spot("type = $type\n");
  #EMC::Message::dumper("field = ", $field);
  #EMC::Message::dumper("gromacs = ", $gromacs);

  foreach (@{$order}) {
    next if (!defined($gromacs->{$_}));

    my $item = $gromacs->{$_}; next if (!defined($item->{data}));
    my $entry = EMC::Common::hash($field, $_);
    my $ftype = $_;
    my $arrange = ($ftype eq "improper" ?
      \&EMC::Fields::arrange_imp : \&EMC::Fields::arrange);

    EMC::Message::spot("ftype = $ftype\n");

    if (!defined($convert->{$ftype})) {			# verbatim
      copy_item($entry, $item);
      next;
    }

    if ($ftype eq "mass") {				# mass
      if (!defined($entry->{data})) {
	copy_item($entry, $item);
      } else {
	my $source = $item->{data};
	my $target = $entry->{data};
	foreach (sort(keys(%{$source}))) {
	  if (defined($target->{$_})) {
	  } else {
	    $target->{$_} = EMC::Element::deep_copy($source->{$_});
	  }
	}
      }
      next;
    }

    my $n = $item->{flag}->{ntypes};			# initialize
    my $convert_index = $convert->{$_}->{index};
    my $data = $item->{data};
    my $ptr = [$data];
    my $keys = [[sort(keys(%{$data}))]];
    my $index = EMC::List::hash($item->{flag}->{index});
    my $registry = {};
    my $select = [];
    my (@key);

    #print("\n");
    #EMC::Message::spot("ftype = $ftype\n");
    #EMC::Message::list("keys[0] = ", $keys->[0]);
    #EMC::Message::dumper("index = ", $index);

    $entry->{flag} = {array => 0, cmap => 0, first => 1, ntypes => $n};
    if (!defined($entry->{index})) {
      $entry->{index} = [map("type$_", (1..$n)), @{$convert_index}];
    }
    for (my $i=1; $i<$n; ++$i) { 
      push(@{$keys}, []);
    }
    while (1) {
      my $i = 0; 
      foreach (@{$keys}) {
       	$i += scalar(@{$_});
      }
      last if (!$i);
      
      for ($i=1; $i<$n; ++$i) { 			# advance
	last if(scalar(@{$keys->[-$i]}));
      }
      $i = $n-$i+1;
      @key[$i-1] = shift(@{$keys->[$i-1]});
      for (; $i<$n; ++$i) { 
	$ptr->[$i] = $ptr->[$i-1]->{@key[$i-1]};
	$keys->[$i] = [sort(keys(%{$ptr->[$i]}))];
	@key[$i] = shift(@{$keys->[$i]});
      }
      $ptr->[$i] = $ptr->[$i-1]->{@key[-1]};
      
      next if (ref($ptr->[-1]) ne "HASH");

      my $prm = [keys(%{$ptr->[-1]})];			# apply
      my $freq = {};
      
      print("-" x 79, "\n");
      print(join("\t", __LINE__.":", @key, scalar(@{$prm}), "\n"));
      
      foreach (@{$prm}) {
	++$freq->{$_};
      }
      $prm = EMC::List::sort([keys(%{$freq})], $freq);	# sort parameters

      foreach (reverse(@{$prm})) {
	my @p = split("\t");
	my $k = $_;
	my $f = {};

	# - parameters with lowest occurence
	# - type with highest overall occurence
	# - otherwise alphabetically lowest type

	foreach (@key) { 
	  $f->{$_}->{base} = defined($eqv->{$_}) ? $eqv->{$_}->[0] : $_;
	  $f->{$_}->{i} = $count->{$f->{$_}->{base}}->{i};
	  $f->{$_}->{freq} = $count->{$f->{$_}->{base}}->{n};
	  ++$f->{$_}->{n};
	}
	my @sort = sort({
	    #$f->{$a}->{n} == $f->{$b}->{n} ? 
	      $f->{$a}->{i} == $f->{$b}->{i} ?
		$f->{$a}->{freq} == $f->{$b}->{freq} ?
		  $f->{$a}->{base} cmp $f->{$b}->{base} :
		  $f->{$a}->{freq} <=> $f->{$b}->{freq} :
		  $f->{$a}->{i} <=> $f->{$b}->{i} #:
		  #$f->{$a}->{n} <=> $f->{$b}->{n}
	  }
	  @key
	);

	# find suitable type

	my $change = @sort[0];			# least frequent
	my $index = EMC::List::index(\@key, $change);
	my $pentry = $ptr->[-1]->{$k}->[0];
	my $typen = get_type($gromacs, {
	    ftype => $ftype, eqv => $eqv, index => $index, item => $registry,
	    key => \@key, name => $pentry->[0], type => $change
	  });
	my $success = 0;

	foreach (@{$ptr->[-1]->{$k}}) {		# change mol types
	  my @arg = @{$_};
	  my $name = shift(@arg);
	  my $atom = $molecules->{$name}->{atom};

	  print("\t", 
	    join("\t", ">LOOP<", $name, map({$atom->[$_]->{type}} @arg)), "\n");
       
	  next if (!defined($name));
	  
	  my $tc = $change;
	  my $tn = $typen;
	  my @t = @key;
	  my $flag = 0;
	  my $used = 0;
	  my $i = 0;

	  foreach (@arg) {
	    @t = map({$atom->[$_]->{type}} @arg);
	    if ($atom->[$_]->{type} eq $tc) {
	      $tn = get_type($gromacs, {
		  ftype => $ftype, eqv => $eqv, index => $i, item => $registry,
		  key => \@t, name => $name, type => $tc
		});
	      $atom->[$_]->{type} = $tn;
	      $success = $flag = 1;
	      @t[$i] = $tn;
	      push(@{EMC::Common::list($registry, $arrange->(@t))}, $k);
	      print(">>>\t\t",
	       	join("\t", ">REGI<", $name, $_, $tc, "=>", $tn), "\n");
	      my @tmp = map({$atom->[$_]->{type}} @arg);
	      print(">>>\t\t",
	       	join("\t", ">REGI<", $name, @arg, "=>", @tmp), "\n");
	      last;
	    }
	    ++$i;
	  }
	  if (!$flag) {
	    my $list = EMC::Common::list($registry, $arrange->(@t));
	    if (scalar(@{$list})) {
	      if (!defined(EMC::List::index($list, $k))) {
		print(
		  join("\t", __LINE__.":", ">FAIL<", $name, @arg, @t), "\n");
		my $f = {};
		$i = 0;
		foreach (@arg) {
		  my $t = $atom->[$_]->{type};
		  $f->{$_}->{i} = $count->{$eqv->{$t}->[0]}->{i};
		  $f->{$_}->{n} = $count->{$eqv->{$t}->[0]}->{n};
		  $f->{$_}->{index} = $i++;
		  $f->{$_}->{type} = $t;
		}
		my @sort = sort({
		    $f->{$a}->{n}==$f->{$b}->{n} ?
		      $f->{$a}->{i}<=>$f->{$b}->{i} :
		      $f->{$a}->{n}<=>$f->{$b}->{n};
		  } @arg);
		$i = $f->{@sort[0]}->{index};
		$tc = $f->{@sort[0]}->{type};
		@t = map({$atom->[$_]->{type}} @arg);
		$tn = get_type($gromacs, {
		    ftype => $ftype, eqv => $eqv, index => $i,
		    item => $registry, key => \@t, name => $name, type => $tc
		  });
		$atom->[@sort[0]]->{type} = $tn;
		$success = $flag = 1;
		@t[$i] = $tn;
		@t = $arrange->(@t);
		push(@{EMC::Common::list($registry, $arrange->(@t))}, $k);
		print(">>>\t\t",
		  join("\t", ">REGI<", $name, @sort[0], $tc, "=>", $tn), "\n");
		my @tmp = map({$atom->[$_]->{type}} @arg);
		print(">>>\t\t",
		  join("\t", ">REGI<", $name, @arg, "=>", @tmp), "\n");
	      }
	    } else {
	      push(@{$list}, $k);
	      $success = 1;
	    }
	  }
	}
	next if (!$success);				# skip when not changed

	print("\t",
	  join("\t", $success ? ">SUCC<" : ">FAIL<", @p, $freq->{$_}), "\n");
	
	foreach (@{$ptr->[-1]->{$k}}) {
	  my @arg = @{$_};
	  my $name = shift(@arg);
	  my $atom = $molecules->{$name}->{atom};
	  print("\t\t", 
	    join("\t", $name, @arg, map({$atom->[$_]->{type}} @arg)), "\n");
	  push(@{$select}, {p => [@p], source => $_});
	}
      }
    }

    # transfer parameters

    foreach (@{$select}) {
      my @p = @{$_->{p}};
      my @id = @{$_->{source}};
      my $resname = shift(@id);
      my $atom = EMC::Common::element($molecules, $resname, "atom");
      my @type = defined($atom) ? map({$atom->[$_]->{type}} @id) : @id;

      if (!defined($atom) && defined($resname)) {
	unshift(@id, $resname);
	EMC::Message::list(\@id);
      }
      foreach (@type) {					# equivalence
	if (!EMC::Common::element($eqv, $_)) {
	  EMC::Fields::equivalence($field, $_);
	}
      }
      my $data = EMC::Common::list($entry, "data", $arrange->(@type));
      foreach (@{$convert_index}) {
	push(@{$data}, @p[$index->{$_}]);
      }
    }
  }

  #EMC::Message::dumper("gromacs = ", $gromacs);
  #EMC::Message::dumper("field = ", $field);

  $field->{templates}->{flag} = {ntypes => 1};
  $field->{templates}->{index} = ["name", "smiles"];
  foreach (sort(keys(%{$molecules}))) {
    my $molecule = $molecules->{$_};
    my $smiles = smiles($molecule, 0);

    next if (!defined($smiles));
    $field->{templates}->{data}->{$_} = [$smiles, "# ".$molecule->{name}];
    #EMC::Message::spot("$_ = $smiles\n");
  }
  return $field;
}


sub reset {
  my $molecule = shift(@_);
  my $atoms = $molecule->{atom};

  foreach (@{$atoms}) { $_->{visited} = 0; }
}


sub link {
  my $molecule = shift(@_);
  my $current = shift(@_);
  my $level = shift(@_);
  my $nlink = shift(@_);

  my $atoms = $molecule->{atom};
  my $atom = $atoms->[$current];

  $atom->{link} = [];
  $atom->{visited} = $level;
  if (defined($atom->{connect})) {
    foreach (sort(@{$atom->{connect}})) {
      if ($atoms->[$_]->{visited}) {
	next if ($level-$atoms->[$_]->{visited}<2);
	my $link = (++$$nlink>9 ? "%" : "").$$nlink;
	push(@{$atom->{link}}, $link);
	push(@{$atoms->[$_]->{link}}, $link);
      } else {
	EMC::GROMACS::link($molecule, $_, $level+1, $nlink);
      }
    }
  }
}


sub smiles_rec {
  my $molecule = shift(@_);
  my $current = shift(@_);

  return if (!defined($current));
  
  my $atoms = $molecule->{atom};
  
  return if (!defined($atoms->[$current]));
  
  my $atom = $atoms->[$current];
  my $smiles = $atom->{type};

  $atom->{visited} = 1;
  if ($atom->{charge}) {
    $smiles .= ($atom->{charge}>0 ? "+" : "").$atom->{charge};
  }
  $smiles = "[$smiles]" if (length($smiles)>1);
  if (defined($atom->{link})) {
    $smiles .= join("", @{$atom->{link}});
  }
  if (defined($atom->{connect})) {
    my $append;
    foreach (sort(@{$atom->{connect}})) {
      next if ($atoms->[$_]->{visited});
      if (defined($append)) {
	$smiles .= "(".smiles_rec($molecule, $_).")";
      } else {
	$append = smiles_rec($molecule, $_);
      }
    }
    $smiles .= $append;
  }
  return $smiles;
}


sub smiles {
  my $molecule = shift(@_);
  my $nlink = 0;

  EMC::GROMACS::reset($molecule);
  EMC::GROMACS::link($molecule, 0, 1, \$nlink);
  EMC::GROMACS::reset($molecule);
  return EMC::GROMACS::smiles_rec($molecule, 0);
}


# write input file

sub write_mdp {
  my $stream = shift(@_);

  # mdp settings depend on force field choices

  printf($stream "
integrator		= md
dt			= 0.002
nsteps			= 500000

nstlog			= 5000
nstenergy		= 5000
nstxout-compressed	= 5000

continuation		= yes
constraints		= all-bonds
constraint-algorithm	= lincs

cutoff-scheme		= Verlet

coulombtype		= PME
rcoulomb		= 1.0

vdwtype			= Cut-off
rvdw			= 1.0
DispCorr		= EnerPres

tcoupl			= V-rescale
tc-grps			= Protein  SOL
tau-t			= 0.1      0.1
ref-t			= 300      300

pcoupl			= Parrinello-Rahman
tau-p			= 2.0
compressibility		= 4.5e-5
ref-p			= 1.0
");

  # settings for CHARMM

  printf($stream "
constraints		= h-bonds
cutoff-scheme		= Verlet
vdwtype			= cutoff
vdw-modifier		= force-switch
rlist			= 1.2
rvdw			= 1.2
rvdw-switch		= 1.0
coulombtype		= PME
rcoulomb		= 1.2
DispCorr		= no
    ");
}

