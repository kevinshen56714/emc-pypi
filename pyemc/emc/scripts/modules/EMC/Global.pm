#!/usr/bin/env perl
#
#  module:	EMC::Global.pm
#  author:	Pieter J. in 't Veld
#  date:	September 2-9, 2022.
#  purpose:	Global structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "global_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    field		HASH	field definitions
#    units		HASH	units definitions
#    etc.
#
#  notes:
#    20220902	Inception of v1.0
#

package EMC::Global;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Global'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use Cwd;
use File::Basename;
use EMC::Common;
use EMC::Element;
use EMC::List;
use EMC::Math;
use EMC::Profiles;


# defaults

$EMC::Global::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 2, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $parent = shift(@_);
  my $global = EMC::Common::hash(EMC::Common::element($parent));
  my $attr = EMC::Common::attributes(@_);
  my $modules = {
    profiles => [\&EMC::Profiles::construct, $attr]
  };
  
  foreach (keys(%{$modules})) {
    my $ptr = $modules->{$_};
    $global->{$_} = {};
    $global->{$_}->{parent} = $parent;
    $global->{$_}->{root} = $global->{root} if (defined($global->{root}));
    $global->{$_} = (scalar(@{$ptr})>1 ? defined($attr) : 0) ? 
	  $ptr->[0]->(\$global->{$_}, $ptr->[1]) : $ptr->[0]->(\$global->{$_});
  }
  set_functions($global, $attr);
  set_defaults($global);
  set_commands($global);
  return $global;
}


# initialization

sub set_defaults {
  my $global = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $global = EMC::Common::attributes(
    $global,
    {
      # A

      angles		=> {},

      # B

      binsize		=> 0.01,
      bonds		=> {},

      # C

      check_exist	=> {},
      columns		=> 80,
      core		=> -1,
      cutoff		=> {
	center		=> -1,
	charge		=> -1, 
	ghost		=> -1,
	inner		=> -1,
	outer		=> -1,
	pair		=> -1,
	repulsive	=> 0,
	rmax		=> -1
      },

      # D

      default		=> "default", 
      defined		=> {},
      deform		=> {
	flag		=> 0,
	ncycles		=> 100,
	nblocks		=> 1,
	type		=> "relative",
	xx		=> 1,
	yx		=> 0,
	yy		=> 1,
	zx		=> 0,
	zy		=> 0,
	zz		=> 1,
	ignore		=> []
      },
      density		=> undef,
      densities		=> [],
      dielectric	=> undef,
      direction		=> {
	x		=> "x",
	y		=> "y",
	z		=> "z"
      },

      # E

      env		=> {
	home		=> $ENV{HOME},
	host		=> $ENV{HOST},
	root		=> $ENV{EMC_ROOT}
      },
      ext		=> [".csv", ".esh"],

      # F

      flag		=> {
	angle		=> 0,
	assume		=> 0,
	atomistic	=> 0,
	backwards	=> 1,
	bond		=> -1,
	charge		=> -1,
	chi		=> 0,
	comment		=> 0,
	cross		=> -1,
	crystal		=> -1,
	debug		=> EMC::Message::get_flag("debug"),
	ewald		=> -1,
	exclude		=> 1,
	expert		=> EMC::Message::get_flag("expert"),
	info		=> 1,
	mass		=> EMC::Message::get_flag("info"),
	mass_entry	=> -1,
	mol		=> 1,
	msd		=> 0,
	norestart	=> 0,
	number		=> 0,
	omit		=> 0,
	pair		=> 1,
	preprocess	=> 0,
	reduced		=> -1,
	rules		=> 0,
	trace		=> EMC::Message::get_flag("trace"),
	version		=> 0,
	volume		=> 0,
	warn		=> EMC::Message::get_flag("warn"),
	width		=> 0
      },

      # I

      include		=> {
	extension	=> ".dat",
	location	=> undef
      },
      inverse_type	=> {},

      # K

      kappa		=> -1,

      # L

      location		=> {
	analyze		=> [EMC::IO::emc_root."/scripts/analyze"],
	field		=> [EMC::IO::emc_root."/field"],
	include		=> []
      },

      # M

      mass		=> {},
      module		=> 0,

      # N

      nav		=> undef,
      ntotal		=> 10000,

      # O

      options_flag	=> {
	perl		=> 0,
	python		=> 0,
	tcl		=> 0
      },

      # P

      precision		=> -1,
      pressure		=> {
	flag		=> 0,
	couple		=> "couple",
	direction	=> "x+y+z",
	value		=> 1
      },
      project		=> {
	directory	=> "",
	name		=> "",
	script		=> ""
      },

      # R

      replace		=> {
	flag		=> 0,
	analysis	=> 1,
	build		=> 1,
	run		=> 1,
	test		=> 1
      },
      restricted	=> {
	all		=> [
	  
	  # used in EMC script

	  "seed", "ntotal", "fshape", "output", "field", "location", "nav", 
	  "temperature", "radius", "nrelax", "weight_nonbonded",
	  "weight_bonded", "weight_focus", "kappa", "cutoff", "inner_cutoff",
	  "charge_cutoff", "nsites", "mass", "lbox", "lx", "ly", "lz", "nx",
	  "ny", "nz", "all", "niterations",
	  
	  # used in generated BASH scripts

	  "window", "dir", "last", "serial", "restart", "frestart",
	  "fnorestart", "fwait", "femc", "freplace", "fbuild", "project",
	  "chemistry", "home"
	],
	group		=> [
	  "random", "block", "alternate", "import"
	],
	start		=> [
	  "density", "pressure", "nphase", "lphase"
	]
      },
      root		=> EMC::IO::emc_root(),

      # S

      script		=> {
	extension	=> ".esh",
	flag		=> 0,
	name		=> "chemistry",
	ncolumns	=> 80,
	suffix		=> "_chem"
      },
      seed		=> -1,
      shape		=> undef,
      shape_default	=> [1, 1.5],
      system		=> {
	id		=> "main",
	charge		=> 1,
	geometry	=> 1,
	map		=> 1,
	pbc		=> 1
      },

      # T

      temperature	=> undef,
      type		=> {},
      
      # U

      units		=> {
	energy		=> -1,
	length		=> -1,
	type		=> -1
      },

      # W

      wall		=> 10,
      work_dir		=> EMC::IO::scrub_dir(cwd()),
    }
  );
  $global->{include}->{location} = $global->{location}->{include};
  return $global;
}


sub transfer {
  my $global = EMC::Common::hash(shift(@_));
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Author,			\$global->{identity}->{author}],
    [\$::EMC::BinSize,			\$global->{binsize}],
    [\%::EMC::CheckExist,		\$global->{check_exist}],
    [\$::EMC::Columns,			\$global->{columns}],
    [\$::EMC::Core,			\$global->{core}],
    [\%::EMC::CutOff,			\$global->{cutoff}],
    [\$::EMC::Date,			\$global->{identity}->{date}],
    [\%::EMC::Deform,			\$global->{deform}],
    [\$::EMC::Density,			\$global->{density}],
    [\$::EMC::Dielectric,		\$global->{dielectric}],
    [\%::EMC::Direction,		\$global->{direction}],
    [\$::EMC::EMCVersion,		\$global->{identity}->{emc}->{version}],
    [\%::EMC::ENV,			\$global->{env}],
    [\@::EMC::EXT,			\$global->{ext}],
    [\%::EMC::Include,			\$global->{include}],
    [\$::EMC::Kappa,			\$global->{kappa}],
    [\%::EMC::Location,			\$global->{location}],
    [\$::EMC::NAv,			\$global->{nav}],
    [\$::EMC::NTotal,			\$global->{ntotal}],
    [\%::EMC::OptionsFlag,		\$global->{options_flag}],
    [\$::EMC::Precision,		\$global->{precision}],
    [\%::EMC::Pressure,			\$global->{pressure}],
    [\%::EMC::Project,			\$global->{project}],
    [\%::EMC::Replace,			\$global->{replace}],
    [\@::EMC::Restricted,		\$global->{restricted}->{all}],
    [\@::EMC::RestrictedGroup,		\$global->{restricted}->{group}],
    [\@::EMC::RestrictedStart,		\$global->{restricted}->{start}],
    [\$::EMC::Root,			\$global->{root}],
    [\$::EMC::Script,			\$global->{identity}->{script}],
    [\%::EMC::Script,			\$global->{script}],
    [\$::EMC::Seed,			\$global->{seed}],
    [\$::EMC::Shape,			\$global->{shape}],
    [\@::EMC::ShapeDefault,		\$global->{shape_default}],
    [\%::EMC::System,			\$global->{system}],
    [\%::EMC::Units,			\$global->{units}],
    [\$::EMC::Version,			\$global->{identity}->{version}],
    [\$::EMC::WorkDir,			\$global->{work_dir}]
  );
}


sub set_commands {
  my $global = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $flag = EMC::Common::element($global, "flag");
  my $pressure = EMC::Common::element($global, "pressure");
  my $set = EMC::Common::element($global, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "global_" : "";
  my $commands = $global->{commands} = EMC::Common::attributes(
    EMC::Common::hash($global, "commands"),
    {
      # B

      backwards		=> {
	comment		=> "Set backwards compatibility",
	default		=> EMC::Math::boolean($flag->{backwards}),
	gui		=> ["boolean", "environment", "top", "ignore"]},
      binsize		=> {
	comment		=> "set bin size for LAMMPS profiles",
	default		=> $global->{binsize},
	gui		=> ["real", "chemistry", "lammps", "advanced"]},

      # C

      charge		=> {
	comment		=> "chemistry contains charges",
	default		=> EMC::Math::boolean($flag->{charge}),
	gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
      charge_cut	=> {
	comment		=> "set charge interaction cut off",
	default		=> $global->{cutoff}->{charge},
	gui		=> ["real", "chemistry", "field", "standard", "general"]},
      core		=> {
	comment		=> "set core diameter",
	default		=> $global->{core},
	gui		=> ["real", "chemistry", "field", "advanced", "borne"]},
      cross		=> {
	comment		=> "include nonbond cross terms in LAMMPS params file",
	default		=> EMC::Math::boolean($flag->{cross}),
	gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
      crystal		=> {
	comment		=> "treat imported structure as a crystal",
	default		=> EMC::Math::boolean($flag->{crystal}),
	gui		=> ["boolean", "chemistry", "emc", "advanced"]},
      cut		=> {
	comment		=> "set pairwise interaction cut off",
	default		=> $global->{cutoff}->{pair},
	gui		=> ["real", "chemistry", "field", "standard", "general"]},
      cutoff		=> {
	comment		=> "set pairwise interaction cut off",
	default		=> EMC::Hash::text($global->{cutoff}, "real"),
	gui		=> ["string", "chemistry", "field", "ignore", "general"]},

      # D

      debug		=> {
	comment		=> "control debugging information",
	default		=> EMC::Math::boolean($flag->{debug}),
	gui		=> ["boolean", "environment", "top", "ignore"]},
      deform		=> {
	comment		=> "deform system from given density",
	default		=> EMC::Hash::text($global->{deform}, "integer"),
	gui		=> ["boolean", "environment", "top", "ignore"]},
      density		=> {
	comment		=> "set simulation density in g/cc for each phase",
	default		=> $global->{density},
	gui		=> ["list", "chemistry", "top", "standard"]},
      dielectric	=> {
	comment		=> "set charge medium dielectric constant",
	default		=> $global->{dielectric},
	gui		=> ["real", "chemistry", "field", "advanced"]},
      direction		=> {
	comment		=> "set build direction of phases",
	default		=> $global->{direction}->{x},
	gui		=> ["option", "chemistry", "emc", "advanced", "x,y,z"]},

      # E

      ewald		=> {
	comment		=> "set long range ewald summations",
	default		=> EMC::Math::boolean($flag->{ewald}),
	gui		=> ["boolean", "chemistry", "lammps", "standard"]},
      exclude		=> {
	comment		=> "exclude previous phase during build process",
	default		=> EMC::Math::boolean($flag->{exclude}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      expert		=> {
	comment		=> "set expert mode to diminish error checking",
	default		=> EMC::Math::boolean($flag->{expert}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      extension		=> {
	comment		=> "set environment script extension",
	default		=> $global->{script}->{extension},
	gui		=> ["string", "environment", "top", "ignore"]},

      # G

      ghost_cut		=> {
	comment		=> "set pairwise interaction cut off",
	default		=> $global->{cutoff}->{ghost},
	gui		=> ["real", "chemistry", "field", "standard", "general"]},

      # H

      help		=> {
	comment		=> "this message",
	set		=> \&EMC::Options::set_help},
      host		=> {
	comment		=> "set host on which to run simulations",
	default		=> $global->{env}->{host},
	gui		=> ["string", "environment", "emc", "advanced"]},

      # I

      info		=> {
	comment		=> "control runtime information",
	default		=> EMC::Math::boolean($flag->{info}),
	gui		=> ["boolean", "chemistry", "top", "ignore"]},
      inner		=> {
	comment		=> "set inner cut off",
	default		=> $global->{cutoff}->{inner},
	gui		=> ["real", "chemistry", "field", "advanced"]},

      # K

      kappa		=> {
	comment		=> "set electrostatics kappa",
	default		=> $global->{kappa},
	gui		=> ["real", "chemistry", "field", "advanced", "dpd"]},

      # L

      location		=> {
	comment		=> "prepend paths for various file locations",
	default		=> EMC::Hash::text($global->{location}, "array"),
	gui		=> ["list", "chemistry", "emc", "advanced"]},

      # N

      norestart		=> {
	comment		=> "control possibility of restarting when rerunning",
	default		=> EMC::Math::boolean($flag->{norestart}),
	gui		=> ["integer", "chemistry", "emc", "ignore"]},
      ntotal		=> {
	comment		=> "set total number of atoms",
	default		=> $global->{ntotal},
	gui		=> ["integer", "chemistry", "top", "standard"]},

      # O

      omit		=> {
	comment		=> "omit fractions from chemistry file",
	default		=> EMC::Math::boolean($flag->{omit}),
	gui		=> ["boolean", "chemistry", "top", "ignore"]},
      options_perl	=> {
	comment		=> "export options, comments, and default values in Perl syntax",
	default		=> EMC::Math::boolean($global->{options_flag}->{perl}),
	gui		=> []},
      options_tcl	=> {
	comment		=> "export options, comments, and default values in Tcl syntax",
	default		=> EMC::Math::boolean($global->{options_flag}->{tcl}),
	gui		=> []},
      outer		=> {
	comment		=> "set outer cut off",
	default		=> $global->{cutoff}->{outer},
	gui		=> ["real", "chemistry", "field", "advanced"]},

      # P

      percolate		=> {
	comment		=> "import percolating InsightII structure",
	default		=> EMC::Math::boolean($flag->{percolate}),
	gui		=> ["boolean", "chemistry", "emc", "advanced"]},
      port		=> {
	comment		=> "port EMC setup variables to other applications",
	default		=> "",
	gui		=> ["list", "chemistry", "top", "ignore"]},
      precision		=> {
	comment		=> "set charge kspace precision",
	default		=> $global->{precision},
	gui		=> ["real", "chemistry", "lammps", "advanced"]},
      preprocess	=> {
	comment		=> "use gcc to preprocess the input script",
	default		=> EMC::Math::boolean($flag->{preprocess}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      pressure		=> {
	comment		=> "set system pressure and invoke NPT ensemble; optionally add direction and/or (un)couple for specifying directional coupling",
	default		=> ($pressure->{flag} ?
			      $pressure->{value} : "false").", ".
			   ("direction=".$pressure->{direction}).", ".
			   ($pressure->{couple}),
	gui		=> ["real", "chemistry", "top", "standard"]},
      project		=> {
	comment		=> "set project name; slashes are used to create subdirectories",
	default		=> $global->{project}->{script},
	gui		=> ["string", "chemistry", "top", "standard"]},

      # R

      replace		=> {
	comment		=> "replace all written scripts as produced by EMC setup",
	default		=> EMC::Math::boolean($global->{replace}->{flag}),
	gui		=> ["boolean", "environment", "top", "advanced"]},
      rmax		=> {
	comment		=> "set maximum build cutoff radius",
	default		=> $global->{cutoff}->{rmax},
	gui		=> ["real", "chemistry", "emc", "standard"]},

      # S

      script		=> {
	comment		=> "set script file name",
	default		=> $global->{script}->{name},
	gui		=> ["string", "chemistry", "top", "standard"]},
      script_ncolums	=> {
	comment		=> "set number of colums in output scripts",
	default		=> $global->{script}->{ncolumns},
	gui		=> ["string", "chemistry", "top", "ignore"]},
      seed		=> {
	comment		=> "set initial random seed",
	default		=> $global->{seed},
	gui		=> ["integer", "chemistry", "emc", "advanced"]},
      shape		=> {
	comment		=> "set shape factor",
	default		=> $global->{shape},
	gui		=> ["real", "chemistry", "top", "standard"]},
      system		=> {
	comment		=> "system identification and checks during building",
	default		=> EMC::Hash::text($global->{system}, "boolean", "id"),
	gui		=> ["boolean", "chemistry", "emc", "advanced"]},
      system_charge	=> {
	comment		=> "check for charge neutrality after build",
	default		=> EMC::Math::boolean($global->{system}->{charge}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      system_geometry	=> {
	comment		=> "check geometry sizing upon building",
	default		=> EMC::Math::boolean($global->{system}->{geometry}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      system_id		=> {
	comment		=> "check for charge neutrality after build",
	default		=> $global->{system}->{id},
	gui		=> ["string", "chemistry", "emc", "ignore"]},
      system_map	=> {
	comment		=> "map system box before build",
	default		=> EMC::Math::boolean($global->{system}->{map}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      system_pbc	=> {
	comment		=> "apply periodic boundary conditions after build",
	default		=> EMC::Math::boolean($global->{system}->{pbc}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},

      # T

      temperature	=> {
	comment		=> "set simulation temperature",
	default		=> $global->{temperature},
	gui		=> ["real", "chemistry", "top", "standard"]},
      tighten	=> {
	comment		=> "set tightening of simulation box for imported structures",
	default		=> defined($global->{tighten}) ? $global->{tighten} : "false",
	gui		=> ["real", "chemistry", "emc", "standard"]},
      trace		=> {
	comment		=> "control function call trace upon error",
	default		=> EMC::Math::boolean($flag->{trace}),
	gui		=> ["boolean", "chemistry", "top", "ignore"]},
      
      # U

      units		=> {
	comment		=> "set units type",
	default		=> $global->{units}->{type},
	gui		=> ["string", "chemistry", "field", "advanced", "units"]},
      units_energy	=> {
	comment		=> "set units for energetic scale",
	default		=> $global->{units}->{energy},
	gui		=> ["real", "chemistry", "field", "advanced", "units"]},
      units_length	=> {
	comment		=> "set units for length scale",
	default		=> $global->{units}->{length},
	gui		=> ["real", "chemistry", "field", "advanced", "units"]},

      # V

      version		=> {
	comment		=> "output version information",
	default		=> EMC::Math::boolean($flag->{version}),
	gui		=> ["boolean", "chemistry", "top", "ignore"]},

      # W

      wall		=> {
	comment		=> "set temporary exclusion wall thickness",
	default		=> $global->{wall},
	gui		=> ["real", "chemistry", "emc", "advanced"]},
      warn		=> {
	comment		=> "control warning information",
	default		=> EMC::Math::boolean($flag->{warn}),
	gui		=> ["boolean", "chemistry", "top", "ignore"]},
      width		=> {
	comment		=> "use double width in scripts",
	default		=> EMC::Math::boolean($flag->{width}),
	gui		=> ["boolean", "environment", "top", "advanced"]},
      workdir		=> {
	comment		=> "set work directory",
	default		=> $global->{work_dir},
	gui		=> ["boolean", "environment", "top", "advanced"]
      }
    }
  );

  foreach (keys(%{$commands})) {
    my $ptr = $commands->{$_};
    if (!defined($ptr->{set})) {
      $ptr->{set} = \&EMC::Global::set_options;
    }
  }

  $global->{notes} = [
    "Chemistry and environment file names are assumed to have $global->{script}->{extension} extensions",
    "File names with suffixes _chem can be taken as chemistry file names wild cards",
    "Reserved environment loop variables are: stage, trial, and copy",
    "Densities for multiple phases are separated by commas",
    "Shears are defined in terms of erate; values < 0 turns shear off",
    "Inner and outer cut offs are interpreted as fractions for colloidal force fields",
    "Valid field options are: ignore, complete, warn, empty, or error",

    "Queue name 'default' refers to whichever queue is default; queue name 'local' executes all jobs sequentially on local machine",
    "Reserved environment loop variables are: stage, trial, and copy"
  ];
  return $global;
}


sub set_context {
  my $global = EMC::Common::hash(shift(@_));
  my $cutoff = EMC::Common::element($global, "cutoff");
  my $defined = EMC::Common::element($global, "defined");
  my $flag = EMC::Common::element($global, "flag");
  my $units = EMC::Common::element($global, "units");
  
  my $root = EMC::Common::hash(shift(@_));
  my $fields = EMC::Common::element($root, "fields");
  my $field = EMC::Common::element($root, "fields", "field");
  my $options = EMC::Common::element($root, "options");

  # A

  EMC::IO::path_prepend(
    $global->{include}->{location}, ".");
  EMC::IO::path_prepend(
    $global->{include}->{location}, $global->{work_dir}."/chemistry/include");
  
  # C

  $global->{columns} = $ENV{COLUMNS} if (defined($ENV{COLUMNS}));
  $options->{columns} = $global->{columns} if (defined($global->{columns}));

  $global->{core} = (
    $field->{type} eq "born" ? 1.0 : -1) if (!$defined->{core});
  
  $cutoff->{pair} = (
    $field->{type} eq "dpd" ? 1.0 :
    $field->{type} eq "cff" ? 9.5 :
    $field->{type} eq "colloid" ? 500.0 :
    $field->{type} eq "charmm" ? 12.0 :
    $field->{type} eq "gauss" ? 7.0 :
    $field->{type} eq "opls" ? 9.5 :
    $field->{type} eq "born" ? 10.5 :
    $field->{type} eq "martini" ? 12.0 :
    $field->{type} eq "trappe" ? 14.0 :
    $field->{type} eq "standard" ? 2.5 :
    $field->{type} eq "sdk" ? 15.0 : -1) if (!$defined->{cutoff}->{pair});
  $cutoff->{center} = (
    $field->{type} eq "martini" ? 0.00001 : -1) if (!$defined->{cutoff}->{center});
  $cutoff->{charge} = (
    $field->{type} eq "dpd" ? 3.0 : 
    $field->{type} eq "gauss" ? 3.0 : 
    $cutoff->{pair}) if (!$defined->{cutoff}->{charge});
  $cutoff->{ghost} = (
    $field->{type} eq "dpd" ? 4.0 :
    $field->{type} eq "gauss" ? 4.0 : -1) if (!$defined->{cutoff}->{ghost});
  $cutoff->{inner} = (
    $field->{type} eq "charmm" ? 10.0 :
    $field->{type} eq "colloid" ? 1.00001: 
    $field->{type} eq "martini" ? 9.0 : -1) if (!$defined->{cutoff}->{inner});
  $cutoff->{outer} = (
    $field->{type} eq "colloid" ? 1.25 : -1) if (!$defined->{cutoff}->{outer});
  $cutoff->{rmax} = (
    $field->{type} eq "dpd" ? 1.0 :
    $field->{type} eq "gauss" ? 1.5 : -1) if (!$defined->{cutoff}->{rmax});

  if ($cutoff->{pair}<0) {
    EMC::Message::dumper("field = ", $field);
    EMC::Message::error(
      "no adequate cutoff has been set (correct force field?)\n");
  }

  # D

  $global->{density} = (
    $field->{type} eq "dpd" ? 3.0 : 
    $field->{type} eq "gauss" ? 1.0 : 1.0) if (!$defined->{density});

  $global->{dielectric} = (
    $field->{type} eq "dpd" ? 0.5 : 
    $field->{type} eq "gauss" ? 0.5 : 
    $field->{type} eq "martini" ? 15 : 1) if (!$defined->{dielectric});

  # F

  $flag->{atomistic} = (
    $field->{type} eq "born" ? 1 :
    $field->{type} eq "cff" ? 1 :
    $field->{type} eq "charmm" ? 1 : 0);
  $flag->{charge} = (
    $field->{type} eq "dpd" ? 1 :
    $field->{type} eq "cff" ? 1 :
    $field->{type} eq "charmm" ? 1 :
    $field->{type} eq "gauss" ? 1 :
    $field->{type} eq "opls" ? 1 :
    $field->{type} eq "born" ? 1 :
    $field->{type} eq "martini" ? 0 :
    $field->{type} eq "trappe" ? 1 :
    $field->{type} eq "standard" ? 0 :
    $field->{type} eq "sdk" ? 0 : 0) if (!$defined->{flag}->{charge});
  $flag->{cross} = (
    $field->{type} eq "born" ? 1 :
    $field->{type} eq "dpd" ? 1 :
    $field->{type} eq "gauss" ? 1 :
    $field->{type} eq "martini" ? 1 : 0) if (!$defined->{flag}->{cross});
  $flag->{dpd} = (
    $field->{type} eq "dpd" ? 1 :
    $field->{type} eq "gauss" ? 1 : 0);
  $flag->{ewald} = (
    $flag->{charge}<0 ? 0 : $flag->{charge}) if (!$defined->{flag}->{ewald});
  $flag->{ewald} = 0 if ($flag->{charge}==0);
  $flag->{mass_entry} = (
    $field->{type} eq "dpd" ? 1 : 
    $field->{type} eq "gauss" ? 1 : 
    $field->{type} eq "martini" ? 1 : 0) if (!$defined->{flag}->{mass_entry});
  $flag->{reduced} = (
    $field->{type} eq "dpd" ? 1 :
    $field->{type} eq "gauss" ? 1 :
    $field->{type} eq "standard" ? 1 :
    0) if (!$defined->{flag}->{reduced});
  if (!$defined->{flag}->{rules}) {
    my %allowed = (born => 1, charmm => 1, opls => 1, trappe => 1);
    $flag->{rules} = defined($allowed{$field->{type}}) ? 1 : 0;
  }
  $flag->{shake} = (
    $field->{type} eq "charmm" ?
      defined($global->{shake}->{flag}) ? 
	EMC::Math::flag($global->{shake}->{flag}) :
       	0 : 0) if (!$defined->{flag}->{shake});

  # K

  $global->{kappa} = (
    $field->{type} eq "dpd" ? 0.656 : 
    $field->{type} eq "gauss" ? 0.656 : 4.0) if (!$defined->{kappa});

  # L

  EMC::IO::path_prepend(
    $global->{location}->{analyze},
    $global->{env}->{root}."/scripts/analyze",
    $global->{work_dir}."/chemistry/analyze", ".");
  EMC::IO::path_prepend(
    $global->{location}->{field},
    $global->{env}->{root}."/field", ".");
  EMC::IO::path_prepend(
    $global->{location}->{field_list},
    $global->{env}->{root}."/field",
    $global->{work_dir}."/chemistry/field", ".");
  EMC::IO::path_prepend(
    $global->{location}->{include},
    $global->{work_dir}."/chemistry/include", ".");
  $global->{field_list}->{location} = $global->{location}->{field_list};
  $global->{field_list}->{include} = $global->{location}->{include};

  # N

  $global->{nav} = (
    $flag->{reduced} ? 1.0 : 0.6022141179) if (!$defined->{nav});

  # P

  $global->{precision} = (
    $field->{type} eq "dpd" ? 0.1 :
    $field->{type} eq "gauss" ? 0.1 : 0.001) if (!$defined->{precision});

  # S

  $global->{script}->{name} = (
    split($global->{script}->{extension}, $global->{script}->{name}))[0];
  $global->{shape} = $global->{shape_default}->[
    $global->{nphases}>1 ? 1 : 0] if (!$defined->{shape});
  $global->{script}->{name} = (
    split($global->{script}->{extension}, $global->{script}->{name}))[0];
  $global->{system}->{charge} = (
    $fields->{flag}->{charge} &= $global->{system}->{charge});

  # T

  $global->{temperature} = (
    $flag->{reduced} ? 1.0 : 300.0) if (!$defined->{temperature});
  $global->{tighten} = (
    $field->{type} eq "dpd" ? 1.0 : 
    $field->{type} eq "gauss" ? 1.0 : 3.0) if (!$defined->{tighten});

  # U

  if (!defined($defined->{units}->{type})) {
    $units->{type} = (
      $field->{type} eq "colloid" ? "real" :
      $field->{type} eq "dpd" ? "lj" : 
      $field->{type} eq "gauss" ? "lj" : "real");
  }
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $global = EMC::Common::element($struct, "module");
  my $defined = EMC::Common::hash($global, "defined");
  my $flag = EMC::Common::hash($global, "flag");
  my $warning = $global->{warning} = EMC::Common::array($global, "warning");
  my $set = EMC::Common::element($global, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $n = scalar(@{$args});

  $indicator = $indicator ? "global_" : "";

  # B

  if ($option eq "backwards") {
    if (($flag->{backwards} = EMC::Math::flag($args->[0]))) {
      EMC::Message::spot("backwards = $flag->{backwards}\n");
      EMC::Options::set_defaults($root);
      EMC::Options::set_commands($root);
    }
    return $flag->{backwards};
  }
  if ($option eq "binsize") {
    return $global->{binsize} = EMC::Math::eval($args->[0])->[0]; }

  # C

  if ($option eq "charge") {
    $defined->{flag}->{charge} = 1;
    return $flag->{charge} = EMC::Math::flag($args->[0]); }
  if ($option eq "charge_cut") {
    $defined->{cutoff}->{charge} = 1;
    return $global->{cutoff}->{charge} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "core") {
    $defined->{core} = 1;
    return $global->{core} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "cross") {
    $defined->{flag}->{cross} = 1;
    return $flag->{cross} = EMC::Math::flag($args->[0]); }
  if ($option eq "crystal") {
    $defined->{flag}->{crystal} = 1;
    return $flag->{crystal} = EMC::Math::flag($args->[0]); }
  if ($option eq "cut") {
    $global->{cutoff}->{repulsive} = $args->[0] eq "repulsive" ? 1 : 0;
    if (!$global->{cutoff}->{repulsive}) {
      $defined->{cutoff}->{pair} = 1;
      $global->{cutoff}->{pair} = EMC::Math::eval($args->[0])->[0];
    }
    return $global->{cutoff}->{repulsive};
  }
  if ($option eq "cutoff") {
    my $values = EMC::Math::eval($args);
    EMC::Hash::set($line, $global->{cutoff}, "real", "-1", [], @{$values});
    foreach (keys(%{$global->{cutoff}})) {
      $defined->{cutoff}->{$_} = 1 if ($global->{cutoff}->{$_}>0);
    }
    return $global->{cutoff};
  }

  # D

  if ($option eq "debug") {
    $flag->{debug} = EMC::Math::flag($args->[0]);
    EMC::Message::set_flag({debug => $flag->{debug}});
    return $flag->{debug};
  }
  if ($option eq "deform") {
    EMC::Hash::set($line, $global->{deform}, "args->", "xx", [], @{$args});
    return 1;
  }
  if ($option eq "density") {
    my $values = EMC::Math::eval($args);
    $defined->{density} = 1;
    $global->{density} = $values->[0];
    $global->{densities} = $values;
    return $values->[0];
  }
  if ($option eq "dielectric") {
    $defined->{dielectric} = 1;
    return $global->{dielectric} = EMC::Math::eval($args->[0])->[0];
  }
  if ($option eq "direction") { 
    set_direction($line, $global->{direction}, $args->[0]);
    return 1;
  }

  # E

  if ($option eq "ewald") {
    $defined->{flag}->{ewald} = 1;
    return $flag->{ewald} = EMC::Math::flag($args->[0]); }
  if ($option eq "exclude") {
    if ($args->[0] eq "wall") { $flag->{exclude} = 2; }
    elsif ($args->[0] eq "soft") { $flag->{exclude} = 1; }
    elsif ($args->[0] eq "true") { $flag->{exclude} = 1; }
    elsif ($args->[0] eq "false") { $flag->{exclude} = 0; }
    else {
      my $v = EMC::Math::eval($args->[0])->[0];
      $flag->{exclude} = $v>0 ? $v : 0;
    }
    return $flag->{exclude};
  }
  if ($option eq "expert") {
    $flag->{expert} = EMC::Math::flag($args->[0]);
    EMC::Message::set_flag({expert => $flag->{expert}});
    return $flag->{expert};
  }
  if ($option eq "extension") {
    return $global->{script}->{extension} = $args->[0]; }

  # G

  if ($option eq "ghost_cut") { 
    return $global->{cutoff}->{ghost} = EMC::Math::eval($args->[0])->[0]; }

  # H

  if ($option eq "host") {
    return $global->{env}->{host} = $args->[0]; }

  # I

  if ($option eq "info") {
    $flag->{info} = EMC::Math::flag($args->[0]);
    EMC::Message::set_flag({info => $flag->{info}});
    return $flag->{info};
  }
  if ($option eq "inner") { 
    $defined->{cutoff}->{inner} = 1;
    return $global->{cutoff}->{inner} = EMC::Math::eval($args->[0])->[0]; }

  # K

  if ($option eq "kappa") { 
    $defined->{kappa} = 1;
    return $global->{kappa} = EMC::Math::eval($args->[0])->[0]; }

  # L

  if ($option eq "location") {
    EMC::Hash::set($line, $global->{location}, "array", 1, [], @{$args});
    EMC::Fields::update_field(
      $root->{types}, "location",
      EMC::IO::scrub_dir($global->{location}->{field}->[0]));
    foreach (map({$global->{location}->{$_}} keys(%{$global->{location}}))) {
      next if (ref($_) ne "ARRAY");
      foreach (@{$_}) { $_ = EMC::IO::scrub_dir($_); }
      EMC::IO::path_prepend($_, ".");
    }
    return $global->{location};
  }

  # N

  if ($option eq "norestart") {
    return $flag->{norestart} = EMC::Math::flag($args->[0]); }
  if ($option eq "ntotal") { 
    return $global->{ntotal} = EMC::Math::eval($args->[0])->[0]; }

  # O

  if ($option eq "omit") {
    return $flag->{omit} = EMC::Math::flag($args->[0]); }
  elsif ($option eq "options_perl") {
    return set_options_flag($global, "perl", $args->[0]); }
  elsif ($option eq "options_tcl") { 
    return set_options_flag($global, "tcl", $args->[0]); }
  if ($option eq "outer") {
    return $global->{cutoff}->{outer} = EMC::Math::eval($args->[0])->[0]; }

  # P

  if ($option eq "port") {
    return set_port($global, $line, @{$args}); }
  if ($option eq "precision") {
    $defined->{precision} = 1;
    return $global->{precision} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "preprocess") {
    return $flag->{preprocess} = EMC::Math::flag($args->[0]); }
  if ($option eq "pressure") {
    my $pressure = $global->{pressure};
    $pressure->{value} = EMC::Math::eval($args->[0])->[0] if ((
	$pressure->{flag} = $args->[0] ne "false"));
    my $ncouple = 0;
    my $ndir = scalar(split"[+]", $pressure->{direction});
    my @s = @{$args}; shift(@s); foreach (@s) {
      my @arg = split(":", $args->[1]);
      @arg = split("=", $args->[1]) if (scalar(@arg)==1);
      my @dir = sort(split("[+]", $arg[1]));
      my %d = (x => 0, y => 0, z => 0);
      foreach (@dir) {
	if (!defined($d{$_})) { 
	  EMC::Message::error_line($line, "illegal direction '$_'\n");
       	}
	$d{$_} = 1;
      }
      @dir = (); foreach (sort(keys(%d))) { push(@dir, $_) if ($d{$_}); }
      if (@arg[0] eq "couple") {
	$pressure->{couple} = "couple";
	$pressure->{couple} .= ":".join("+", @dir) if (scalar(@dir));
	$ncouple = scalar(@dir) if (scalar(@dir));
      } elsif (@arg[0] eq "uncouple") {
	$pressure->{couple} = "uncouple";
	$pressure->{couple} .= ":".join("+", @dir) if (scalar(@dir));
	$ncouple = scalar(@dir) if (scalar(@dir));
      } elsif (@arg[0] eq "direction") {
	$pressure->{direction} = join("+", @dir) if (scalar(@dir));
	$ndir = scalar(@dir) if (scalar(@dir));
      }
    }
    if ($ncouple>$ndir) {
      EMC::Message::error_line($line, "coupling and direction inconsistency\n");
    }
    return $global->{pressure};
  }
  if ($option eq "project") {
    my $project = $global->{project};
    $project->{name} = basename($project->{script} = $args->[0]);
    $project->{directory} = dirname($args->[0]);
    $project->{directory} = "" if ($project->{directory} eq ".");
    $project->{directory} .= "/" if (length($project->{directory}));
    return $project;
  }

  # Q

  if ($option eq "quiet") { 
    return $flag->{info} = $flag->{debug} = $flag->{warn} = 0; }

  # R

  if ($option eq "replace") {
    return $global->{replace}->{flag} = EMC::Math::flag($args->[0]); }

  # S

  if ($option eq "script") {
    return $global->{script}->{name} = $args->[0]; }
  if ($option eq "script_ncolumns") {
    return $global->{script}->{ncolumns} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "seed") {
    return $global->{seed} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "shape") {
    $defined->{shape} = 1;
    return $global->{shape} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "system") { 
    EMC::Hash::set($line, $global->{system}, "boolean", "", ["id"], @{$args});
    return $global->{system};
  }
  if ($option eq "system_charge") {
    return $global->{system}->{charge} = EMC::Math::flag($args->[0]); }
  if ($option eq "system_geometry") {
    return $global->{system}->{geometry} = EMC::Math::flag($args->[0]); }
  if ($option eq "system_id") {
    return $global->{system}->{id} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "system_map") {
    return $global->{system}->{map} = EMC::Math::flag($args->[0]); }
  if ($option eq "system_pbc") {
    return $global->{system}->{pbc} = EMC::Math::flag($args->[0]); }

  # T

  if ($option eq "temperature") {
    $defined->{temperature} = 1;
    return $global->{temperature} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "tighten") {
    $defined->{tighten} = 1;
    return $flag->{tighten} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "trace") {
    $flag->{trace} = EMC::Math::flag($args->[0]);
    EMC::Message::set_flag({trace => $flag->{trace}});
    return $flag->{trace};
  }

  # U

  if ($option eq "units") {
    my %allow = (lj => 1, real => 1, si => 1, reduced => 1);
    if (!defined($allow{$args->[0]})) {
      EMC::Message::error_line(
	$line, "unallowed units option '$args->[0]'\n"); }
    $args->[0] = "reduced" if ($args->[0] eq "lj");
    $global->{units}->{type} = $args->[0];
    $defined->{units}->{type} = 1;
    return $global->{units};
  }
  if ($option eq "units_energy") {
    my $value = EMC::Math::eval($args->[0])->[0];
    if ($value<=0) {
      EMC::Message::error_line($line, "energy units <= 0\n"); }
    $defined->{units}->{energy} = 1;
    return $global->{units}->{energy} = $value;
  }
  if ($option eq "units_length") {
    my $value = EMC::Math::eval($args->[0])->[0];
    if ($value<=0) {
      EMC::Message::error_line($line, "length unit <= 0\n"); }
    $defined->{units}->{length} = 1;
    return  $global->{units}->{length} = $value;
  }

  # V

  if ($option eq "version") {
    return $flag->{version} = EMC::Math::flag($args->[0]); }

  # W

  if ($option eq "wall") {
    if ($args->[0] eq "true") {
      $flag->{exclude} = 2;
    } elsif ($args->[0] eq "false") {
      $flag->{exclude} = 1;
    } else {
      my $v = EMC::Math::eval($args->[0])->[0];
      $global->{wall} = $v if ($v>0);
      $flag->{exclude} = 2 if ($v>0);
    }
    return $global->{wall};
  }
  if ($option eq "warn") {
    $flag->{warn} = EMC::Math::flag($args->[0]);
    EMC::Message::set_flag({warn => $flag->{warn}});
    return $flag->{warn};
  }
  if ($option eq "width") { 
    return $flag->{width} = EMC::Math::flag($args->[0]); }
  if ($option eq "workdir") { 
    return $global->{work_dir} = $args->[0]; }

  return undef;
}


sub set_functions {
  my $global = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($global, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, indicator => 0, items => 1};

  $set->{commands} = \&EMC::Global::set_commands;
  $set->{context} = \&EMC::Global::set_context;
  $set->{defaults} = \&EMC::Global::set_defaults;
  $set->{options} = \&EMC::Global::set_options;

  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $global;
}


# density functions

sub set_densities {
  my $global = shift(@_);
  my $density = $global->{density};
  my $densities = $global->{densities};
  my $i = scalar(@{$densities});
  my $n = $global->{nphases}<2 ? 1 : $global->{nphases};

  while ($i<$n) { $densities->[$i++] = $density; }
}


# direction functions

sub set_direction {
  my $line = shift(@_);
  my $direction = shift(@_);
  my $dir = shift(@_);
  my %option = (
    x => ["x", "y", "z"],
    y => ["y", "z", "x"],
    z => ["z", "x", "y"]);

  if (!defined($option{$dir})) {
    EMC::Message::error_line($line, "option '$dir' is not allowed\n"); }
  $direction->{x} = $option{$dir}->[0];
  $direction->{y} = $option{$dir}->[1];
  $direction->{z} = $option{$dir}->[2];
}


# options_flag functions

sub set_options_flag {
  my $global = shift(@_);
  my $flag = shift(@_);
  my $value = shift(@_);
  my $options_flag = $global->{options_flag};

  foreach (keys(%{$options_flag})) { $options_flag->{$_} = 0; };
  return $options_flag->{$flag} = EMC::Math::flag($value);
}


sub set_port {
  my $global = shift(@_);
  my $line = shift(@_);
  my $options_flag = $global->{options_flag};
  my %port = (options => {perl => 1, tcl => 1}, field => 1);

  foreach (@_) {
    my @arg = split(":");
    if (scalar(keys(%{$port{$arg[0]}}))) {
      if (!defined(${$port{$arg[0]}}{$arg[1]})) {
	EMC::Message::error_line($line, "illegal '$arg[0]' option '$arg[1]'\n");
      }
    }
    if ($arg[0] eq "options") {
      foreach (keys(%{$options_flag})) { $options_flag->{$_} = 0; }
      $options_flag->{$arg[1]} = 1;
    } elsif ($arg[0] eq "field") {
      EMC::Message::error_line($line, "field option currently unavailable\n");
    } else {
      EMC::Message::error_line($line, "illegal port '@arg[0]'\n");
    }
  }
}

