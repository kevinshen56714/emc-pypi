#!/usr/bin/env perl
#
#  module:	EMC::NAMD.pm
#  author:	Pieter J. in 't Veld
#  date:	August 31, 2022.
#  purpose:	NAMD structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "namd_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#
#    flag		HASH	optional flags
#
#    write		HASH
#      emc		FUNC	EMC script additions
#      job		FUNC	BASH workflow additions
#      script		FUNC	LAMMPS script
#
#  notes:
#    20220831	Inception of v1.0
#

package EMC::NAMD;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::NAMD'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Math;
use EMC::Script;


# defaults

$EMC::NAMD::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "August 31, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $namd = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);

  set_functions($namd, $attr);
  set_defaults($namd);
  set_commands($namd);
  
  return $namd;
}


# initialization

sub set_defaults {
  my $namd = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $namd->{context} = EMC::Common::attributes(
    EMC::Common::hash($namd, "context"),
    {
      dtcoulomb		=> 1,
      dtdcd		=> 10000,
      dtnonbond		=> 1,
      dtrestart		=> 100000,
      dtthermo		=> 1000,
      dttiming		=> 10000,
      dtupdate		=> 20,
      extra_bonds	=> [],
      fixed_atoms	=> [],
      pres_period	=> 100.0,
      pres_decay	=> 50.0,
      temp_damp		=> 3,
      timestep		=> 2.0,
      tequil		=> 100000,
      tminimize		=> 50000,
      trun		=> 10000000,
      verbatim		=> undef
    }
  );
  $namd->{flag} = EMC::Common::attributes(
    EMC::Common::hash($namd, "flag"),
    {
      engine		=> 1,
      write		=> 0
    }
  );
  $namd->{identity} = EMC::Common::attributes(
    EMC::Common::hash($namd, "identity"),
    $EMC::NAMD::Identity
  );
  return $namd;
}


sub transfer {
  my $namd = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($namd, "flag");
  my $context = EMC::Common::element($namd, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::NAMD{dtcoulomb},		\$context->{dtcoulomb}],
    [\$::EMC::NAMD{dtdcd},		\$context->{dtdcd}],
    [\$::EMC::NAMD{dtnonbond},		\$context->{dtnonbond}],
    [\$::EMC::NAMD{dtrestart},		\$context->{dtrestart}],
    [\$::EMC::NAMD{dtthermo},		\$context->{dtthermo}],
    [\$::EMC::NAMD{dttiming},		\$context->{dttiming}],
    [\$::EMC::NAMD{dtupdate},		\$context->{dtupdate}],
    [\$::EMC::NAMD{extra_bonds},	\$context->{extra_bonds}],
    [\$::EMC::NAMD{fixed_atoms},	\$context->{fixed_atoms}],
    [\$::EMC::NAMD{pres_period},	\$context->{pres_period}],
    [\$::EMC::NAMD{pres_decay},		\$context->{pres_decay}],
    [\$::EMC::NAMD{temp_damp},		\$context->{temp_damp}],
    [\$::EMC::NAMD{timestep},		\$context->{timestep}],
    [\$::EMC::NAMD{tequil},		\$context->{tequil}],
    [\$::EMC::NAMD{tminimize},		\$context->{tminimize}],
    [\$::EMC::NAMD{trun},		\$context->{trun}],
    [\$::EMC::NAMD{write}, 		\$flag->{write}]
  );
}


sub set_commands {
  my $namd = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($namd, "set");
  my $flag = EMC::Common::element($namd, "flag");
  my $context = EMC::Common::element($namd, "context");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  
  $indicator = $indicator ? "namd_" : "";
  my $commands = $namd->{commands} = EMC::Common::attributes(
    EMC::Common::hash($namd, "commands"),
    {
      namd		=> {
	comment		=> "create NAMD input script and parameter file",
	default		=> EMC::Math::boolean($flag->{write}),
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."dtcoulomb"	=> {
	comment		=> "set electrostatic interaction update frequency",
	default		=> $context->{dtcoulomb},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."dtdcd"	=> {
	comment		=> "set output frequency of DCD file",
	default		=> $context->{dtdcd},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."dtnonbond"	=> {
	comment		=> "set nonbonded interaction update frequency",
	default		=> $context->{dtnonbond},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."dtrestart"	=> {
	comment		=> "set output frequency of restart files",
	default		=> $context->{dtrestart},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."dtthermo"	=> {
	comment		=> "set output frequency of thermodynamic quantities",
	default		=> $context->{dtthermo},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."dttiming"	=> {
	comment		=> "set timing frequency",
	default		=> $context->{dttiming},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."dtupdate"	=> {
	comment		=> "set update frequency",
	default		=> $context->{dtupdate},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."extra_bonds"	=> {
	comment		=> "set selection for extra bonds",
	default		=> "-",
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."fixed_atoms"	=> {
	comment		=> "set selection for fixed atoms",
	default		=> "-",
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."pres_period"	=> {
	comment		=> "set pressure ensemble period",
	default		=> $context->{pres_period},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."pres_decay"	=> {
	comment		=> "set pressure ensemble decay",
	default		=> $context->{pres_decay},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."temp_damp"	=> {
	comment		=> "set temperature ensemble damping",
	default		=> $context->{temp_damp},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."tequil"	=> {
	comment		=> "set number of equilibration timesteps",
	default		=> $context->{tequil},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."tminimize"	=> {
	comment		=> "set number of minimization timesteps",
	default		=> $context->{tminimize},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      $indicator."trun"		=> {
	comment		=> "set number of timesteps for running",
	default		=> $context->{trun},
	gui		=> ["string", "chemistry", "top", "ignore"]}
    }
  );

  foreach (keys(%{$commands})) {
    my $ptr = $commands->{$_};
    if (!defined($ptr->{set})) {
      $ptr->{set} = \&EMC::NAMD::set_options;
    }
  }

  $namd->{items} = EMC::Common::attributes(
    EMC::Common::hash($namd, "items"),
    {
      namd		=> {
	chemistry	=> 1,
	environment	=> 0,
	order		=> 0,
	set		=> \&EMC::Script::set_item_verbatim
      }
    }
   ); 

  return $namd;
}


sub set_focus {
  my $line = shift(@_);
  my $ptr = shift(@_);
  my $extra = shift(@_);
  my $allowed = EMC::Hash::cat($extra, { 
    cluster => 2, element => 2, exclude => 0, include => 0, group => 2,
    site => 2, source => 0, system => 2, target => 0});
  my $item = "source";
  my $mode = "include";

  foreach (@_) {
    my @a = split("=");
    my $n = scalar(@a)-1;
    if (!defined($allowed->{@a[0]})) {
      error_line($line, "unallowed keyword '@a[0]'\n");
    }
    $extra = undef;
    if (ref($allowed->{@a[0]}) eq "HASH") {
      $extra = $allowed->{@a[0]};
    } elsif ($allowed->{@a[0]}==0) {
      EMC::Message::error_line(
	$line, "keyword '@a[0]' expects no arguments\n") if ($n);
    } elsif ($allowed->{@a[0]}==1) {
      EMC::Message::error_line(
	$line, "keyword '@a[0]' expects one argument\n") if ($n!=1);
    } else {
      EMC::Message::error_line(
	$line, "keyword '@a[0]' expects at least one argument\n") if (!$n);
    }
    if (@a[0] eq "name") { $ptr->{@a[0]} = @a[1]; }
    elsif (defined($extra->{@a[0]})) { $ptr->{@a[0]} = @a[1]; }
    elsif (@a[0] eq "include" || @a[0] eq "exclude") { $mode = @a[0]; }
    elsif (@a[0] eq "source" || @a[0] eq "target") { $item = @a[0]; }
    else {
      my $p = $ptr;
      foreach ($item, $mode, @a[0]) {
	$p->{$_} = {} if (!defined($p->{$_}));
	$p = $p->{$_};
      }
      if (defined($extra)) {
	if (!defined($extra->{@a[1]})) {
	  EMC::Message::error_line(
	    $line, "unallowed option '@a[1]' for keyword '@a[0]'\n");
	}
	$p->{@a[1]} = 1;
      } else {
	foreach (split(":", @a[1])) {
	  $p->{$_} = 1;
	}
      }
    }
  }
  return $ptr;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $namd = EMC::Common::element($struct, "module");
  my $context = EMC::Common::hash($namd, "context");
  my $flag = EMC::Common::hash($namd, "flag");
  my $set = EMC::Common::element($namd, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "namd_" : "";
  if ($option eq "namd") {
    if (EMC::Math::flag($args->[0])) {
      my $md = EMC::Common::element($namd, "parent");
      EMC::MD::set_flags($md, "write", 0);
      $md->{pdb}->{flag}->{write} = 0;
      return $flag->{write} = 1;
    }
    return $flag->{write} = 0;
  }
  if ($option eq $indicator."dtcoulomb") {
    return $context->{dtcoulomb} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."dtdcd") {
    return $context->{dtdcd} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."dtnonbond") {
    return $context->{dtnonbond} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."dtrestart") {
    return $context->{dtrestart} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."dtthermo") {
    return $context->{dtthermo} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."dttiming") {
    return $context->{dttiming} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."dtupdate") {
    return $context->{dtupdate} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."extra_bonds") {
    push(
      @{$context->{extra_bonds}},
      set_focus($line, {}, {distance => 1}, @{$args}));
    return $context->{extra_bonds};
  }
  if ($option eq $indicator."pres_decay") {
    return $context->{pres_decay} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."pres_period") {
    return $context->{pres_period} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."temp_damp") {
    return $context->{temp_damp} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."tminimize") {
    return $context->{tminimize} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."trun") {
    return $context->{trun} = EMC::Math::eval($args->[0])->[0]; }
  return undef;
}


sub set_functions {
  my $namd = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($namd, "set");
  my $write = EMC::Common::hash($namd, "write");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, indicator => 1, items => 1, md => 1};

  $set->{commands} = \&EMC::NAMD::set_commands;
  $set->{defaults} = \&EMC::NAMD::set_defaults;
  $set->{options} = \&EMC::NAMD::set_options;

  $write->{emc} = \&EMC::NAMD::write_emc;
  $write->{job} = \&EMC::NAMD::write_job;
  $write->{script} = \&EMC::NAMD::write_script;

  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $namd;
}


# NAMD script

sub write_script {			# <= write_namd
  my $root = shift(@_);
  my $name = shift(@_);

  my $global = EMC::Common::hash($root, "global");
  my $namd = EMC::Common::hash($root, "md", "namd");

  return if (!$namd->{flag}->{write});

  if ((-e "$name.namd")&&!$global->{replace}->{flag}) {
    EMC::Message::warning(
      "\"$name.namd\" exists; use -replace flag to overwrite\n");
    return;
  }

  EMC::Message::info("creating NAMD input script \"$name.namd\"\n");

  my $stream = EMC::IO::open("$name.namd", "w");
  
  write_header($stream, $root);
  write_verbatim($stream, $namd);
  write_footer($stream, $root);
  EMC::IO::close($stream);
}


sub write_header {			# <= write_namd_header
  my $stream = shift(@_);
  my $root = shift(@_);

  my $namd = EMC::Common::hash($root, "md", "namd");
  my $context = EMC::Common::hash($namd, "context");
  my $global = EMC::Common::hash($root, "global");
  my $identity = EMC::Common::hash($global, "identity");
  my $date = EMC::Common::date_full();

  printf($stream "%s",
"# NAMD input script for standardized atomistic simulations
# Created by $identity->{script} v$identity->{version}, $identity->{date} as part of EMC
# on $date

# Variable definitions

set		project		\"$global->{project}->{name}\"
set		source		\"$global->{build}->{dir}\"
set		params		\"$global->{build}->{dir}\"
set		frestart	".($global->{md}->{restart} ? 1 : 0)."
set		restart		\"\"
set		seed		".int(rand(1e8))."

set		temperature	$global->{temperature}
set		temp_damp	$context->{temp_damp}

set		pressure	$global->{pressure}->{value}
set		pres_period	$context->{pres_period}
set		pres_decay	$context->{pres_decay}

set		ensemble	\"".($global->{pressure}->{flag} ? "npt" : "nvt")."\"

set		cutoff_inner	$global->{cutoff}->{inner}
set		cutoff_outer	$global->{cutoff}->{pair}
set		cutoff_ghost	".($global->{cutoff}->{ghost}>0 ? $global->{cutoff}->{ghost} : $global->{cutoff}->{pair}+2)."

set		timestep	$global->{timestep}
set		dtnonbond	$context->{dtnonbond}
set		dtcoulomb	$context->{dtcoulomb}
set		dtupdate	$context->{dtupdate}
set		dtthermo	$context->{dtthermo}
set		dtdcd		$context->{dtdcd}
set		dtrestart	$context->{dtrestart}
set		dttiming	$context->{dttiming}

set		fixed_atoms	".(scalar(@{$context->{fixed_atoms}})?1:0)."
set		extra_bonds	".(scalar(@{$context->{extra_bonds}})?1:0)."
set		tminimize	$context->{tminimize}
set		tequil		$context->{tequil}
set		trun		$context->{trun}

set		fixedAtomsCol	B_or_O 
set		modes		[list]

# Command line arguments

puts \"====================================================\"

set		command		\"\"
set		value 		\"\"
set		exclude 	[list arg command exclude value]

foreach arg \${argv} {
  if { [string range \${arg} 0 0] eq \"-\" } {
    set command [string range \${arg} 1 end]
    if { \${command} eq \"mode\"} {
      set command \"modes\"
    }
    set value \"\"
  } else {
    set value \${arg}
  }
  if { [lsearch -exact \${exclude} \${command}]>=0 || 
       [info exists \${command}]==0 } {
    if { \${value} eq \"\" } {
      puts \"UserWarning: excluding \${command}\"
    }
    continue
  }
  if { \${value} != \"\" } {
    if { \${command} eq \"modes\"} {
      lappend \$command [list \${value}]
      puts \"UserInfo: appending \'\${value}\' to \${command}\"
    } else {
      set \${command} \${value}
      puts \"UserInfo: setting \${command} to \'\${value}\'\"
    }
  }
}

if { [llength \${modes}]==0 } {
  puts \"UserWarning: no execution modes were set\"
}

puts \"====================================================\"

# Input

if { \${fixed_atoms} } {
  fixedAtoms		on
  fixedAtomsFile	\"\${source}/\${project}.pdb\"
  fixedAtomsCol		\"\${fixedAtomsCol}\"
}

# ExtraBonds

if { \${extra_bonds} } {
  extraBonds		yes
  extraBondsFile	\"\${source}/\${project}_extra.bonds\"
}

structure		\"\${source}/\${project}.psf\"
coordinates		\"\${source}/\${project}.pdb\"

if { \${frestart} eq \"0\" } {
  source		\"\${source}/\${project}.cell\"
  temperature		\${temperature}
} else {
  binCoordinates	\"\${restart}/\${project}.restart.coor\"
  binVelocities		\"\${restart}/\${project}.restart.vel\"
  extendedSystem	\"\${restart}/\${project}.restart.xsc\"
}

# Force calculations

paraTypeCharmm		on
parameters		\"\${params}/\${project}.prm\"

exclude			scaled1-4
1-4scaling		1.0
switching		on
switchDist		\${cutoff_inner}
cutoff			\${cutoff_outer}
pairlistdist		\${cutoff_ghost}

PME			yes
PMEGridSpacing		1.0

# Integrator

rigidbonds		all
timestep		\${timestep}
nonBondedFreq		\${dtnonbond}
fullElectFrequency	\${dtcoulomb}
stepsPerCycle		\${dtupdate}
seed			\${seed}

# Temperature

if { \${ensemble} eq \"nvt\" } {
  langevin		on
  langevinDamping	\${temp_damp}
  langevinTemp		\${temperature}
  langevinHydrogen	off
}

# Pressure

if { \${ensemble} eq \"npt\" } {
  useGroupPressure	yes
  useFlexibleCell	no
  useConstantArea	no
  langevinPiston	on
  langevinPistonTarget	\${pressure}
  langevinPistonPeriod	\${pres_period}
  langevinPistonDecay	\${pres_decay}
  langevinPistonTemp	\${temperature}	
}

# Output

outputname		\${project}
outputEnergies		\${dtthermo}
outputPressure		\${dtthermo}
restartfreq		\${dtrestart}
outputTiming		\${dttiming}

if { \${dtdcd} > 0 } {
  DCDFile		\${project}.dcd
  DCDFreq		\${dtdcd}
}

wrapAll			on

");
}


sub write_verbatim {				# <= write_namd_verbatim
  my ($stream, $namd, $stage, $spot) = @_[0..3];
  my $verbatim = EMC::Common::element($namd, "verbatim");

  $stage = "default" if (!defined($stage));
  $spot = "default" if (!defined($spot));

  my $data = EMC::Common::element($verbatim, $stage, $spot, "data");

  if ($data) {
    EMC::Message::info("adding verbatim namd $spot paragraph at $stage\n");
    printf($stream "# Verbatim paragraph\n\n%s\n\n", join("\n", @{$data}));
  }
}


sub write_footer {				# <= write_namd_footer
  my $stream = shift(@_);
  my $root = shift(@_);

  printf($stream "%s",
"# Run conditions

foreach mode \$modes {
  if { \${mode} eq \"minimize\" } {
    puts     		\"UserInfo: running minimizer\"
    minimize		\${tminimize}
  }
  if { \${mode} eq \"quench\" } {
    puts		\"UserInfo: running velocity quenching\"
    velocityQuenching	on
    maximumMove		0.1
    reinitvels		\${temperature}
    run			\${tminimize}
    velocityQuenching	off
  } 
  if { \${mode} eq \"equilibrate\" } {
    puts		\"UserInfo: running MD equilibration\"
    reinitvels		\${temperature}
    run			\${tequil}
  }
  if { \${mode} eq \"run\" || \${mode} eq \"restart\" } {
    puts		\"UserInfo: starting run\"
    run			\${trun}
  }
}
");
}


# EMC script additions

sub write_emc {
  my $namd = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $emc_flag = EMC::Common::element($root, "emc", "flag");
  my $global = EMC::Common::element($root, "global");
  my $pdb = EMC::Common::element($root, "pdb", "flag");
  my $field = EMC::Common::element($root, "fields", "field");
  my $context = EMC::Common::element($namd, "context");
  my $flag = EMC::Common::element($namd, "flag");

  return if ($emc_flag->{test});
  return if (!(defined($flag) && $flag->{write}));
  return if ($emc_flag->{exclude}->{build});

  printf($stream "namd\t\t= {name -> output,");
  printf($stream " compress -> ".EMC::Math::boolean($pdb->{compress}).",");
  printf($stream " extend -> ".EMC::Math::boolean($pdb->{extend}).",");
  printf($stream "\n\t\t  ");
  printf($stream " forcefield -> $field->{type},");
  printf($stream " detect -> false,");
  printf($stream " hexadecimal -> ".EMC::Math::boolean($pdb->{hexadecimal}).",");
  printf($stream "\n\t\t  ");
  printf($stream " unwrap -> ".EMC::Math::boolean($pdb->{unwrap}).",");
  printf($stream " pbc -> ".EMC::Math::boolean($pdb->{pbc}).",");
  printf($stream " atom -> $pdb->{atom},");
  printf($stream " residue -> $pdb->{residue},");
  printf($stream "\n\t\t  ");
  printf($stream " segment -> $pdb->{segment},");
  printf($stream " rank -> ".EMC::Math::boolean($pdb->{rank}).",");
  printf($stream " vdw -> ".EMC::Math::boolean($pdb->{vdw}).",");
  printf($stream " cut -> ".EMC::Math::boolean($pdb->{cut}).",");
  printf($stream "\n\t\t  ");
  printf($stream " fixed -> ".EMC::Math::boolean($pdb->{fixed}).",");
  printf($stream " rigid -> ".EMC::Math::boolean($pdb->{rigid}).",");
  printf($stream " connectivity -> ".EMC::Math::boolean($pdb->{connect}).",");
  printf($stream "\n\t\t  ");
  printf($stream " parameters -> ".EMC::Math::boolean($pdb->{parameters}));
  printf($stream "};\n\n");
}


# BASH workflow additions

sub write_job {
  my $namd = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $global = EMC::Common::element($root, "global");
  my $md = EMC::Common::element($root, "md");
  my $context = EMC::Common::element($namd, "context");
  my $flag = EMC::Common::element($namd, "flag");
  my $project_name = EMC::Common::element($global, "project", "name");

  return if (!(defined($flag) && $flag->{write}));

  printf($stream
"
run_md() {
  local dir=\"\$1\"; shift;
  local frestart=\"\$1\"; shift;
  local ncores=\"\$1\"; shift;
  local fequil=\"\$1\"; shift;

  printf \"### \${dir}\\n\\n\";
  if [ ! -e \${dir} ]; then
    run mkdir -p \${dir};
  fi;

  local nppn=\${NCORES_PER_NODE};
  local nppt=\${NCORES_PER_THREAD};
  local nnodes=\$(calc \"int(\${ncores}/\${nppn})\");
  local nmpi=\$(calc \"int(\${nppn}/\${nppt})\");
  local nextra=\$(calc \"\${ncores}-\${nnodes}*\${nppn}\");
  local nmpiextra=\$(calc \"int(\${nextra}/\${nppt})\");
  local restart_dir=\"".($md->{flag}->{restart} ? "$md->{context}->{restart_dir}" : "..")."\";
  local output file thread equil mode;
  
  if [ \${fbuild} != 1 ]; then
    if [ ! -e \${dir}/../build/$project_name.pdb ]; then
      printf \"# ../build/$project_name.pdb does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${dir}/../build/$project_name.prm ]; then
      printf \"# ../build/$project_name.prm does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${dir}/../build/$project_name.namd ]; then
      printf \"# ../build/$project_name.namd does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
  fi;

  if [ \${freplace} != 1 ]; then
    if [ \${frestart} != 1 ]; then
      if [ -e \${dir}/$project_name.coor ]; then
	printf \"# $project_name.coor exists -> skipped\\n\\n\";
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

  if [ \"\${nppt}\" != \"1\" ]; then
    thread=\"+ppn \$(calc \"\${nppt}-1\") \";
    thread+=\"+commap 0-\$(calc \"\${nmpi}-1\") \";
    thread+=\"+pemap \${nmpi}-\$(calc \"\${nppn}-1\")\${nppn}.\";
    thread+=\$(calc \${nppn}-\${nmpi});
  fi;

  if [ \"\${frestart}\" == \"0\" ]; then
    mode=\"minimize equilibrate run\";
  else
    mode=\"run\";
  fi;

  run cd \${dir};
  run cp \${restart_dir}/build/$project_name.namd .;
  set -f;
  WALLTIME=\${RUN_WALLTIME};
  run_pack -n \${ncores} -nppt \${nppt} \\
    -walltime \${RUN_WALLTIME} -starttime \${START_TIME} -queue \${QUEUE} \\
    -output $project_name.out \\
    -project $project_name \\
      namd2 \${thread}\\
	--tclmain $project_name.namd \\
	  -mode \${mode} \\
	  -frestart \${frestart} \\
	  -seed \${SEED};
  set +f;

  SEED=\$(calc \${SEED}+1);
  run cd \"\${WORKDIR}\";
  echo;
}

set_restart() {
  RESTART=(\$1/*/*.restart.coor);
  echo \"\${RESTART[0]}\";
}
");
}

