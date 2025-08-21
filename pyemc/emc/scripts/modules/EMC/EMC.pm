#!/usr/bin/env perl
#
#  module:	EMC::EMC.pm
#  author:	Pieter J. in 't Veld
#  date:	September 3, 2022.
#  purpose:	EMC structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "emc_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20220903	Inception of v1.0
#

package EMC::EMC;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::EMC'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::List;
use EMC::Math;
use EMC::Message qw(format_output);
use EMC::Options;
use File::Path;


# defaults

$EMC::EMC::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 3, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $parent = shift(@_);
  my $emc = EMC::Common::hash(EMC::Common::element($parent));
  my $attr = EMC::Common::attributes(@_);
  my $modules = {
    clusters => [\&EMC::Clusters::construct, $attr],
    groups => [\&EMC::Groups::construct, $attr],
    polymers => [\&EMC::Polymers::construct, $attr],
    variables => [\&EMC::Variables::construct]
  };
  
  foreach (keys(%{$modules})) {
    my $ptr = $modules->{$_};
    $emc->{$_} = {};
    $emc->{$_}->{parent} = $parent;
    $emc->{$_}->{root} = $emc->{root} if (defined($emc->{root}));
    $emc->{$_} = (scalar(@{$ptr})>1 ? defined($attr) : 0) ? 
	      $ptr->[0]->(\$emc->{$_}, $ptr->[1]) : $ptr->[0]->(\$emc->{$_});
  }
  
  set_functions($emc, $attr);
  set_defaults($emc);
  set_commands($emc);
  return $emc;
}


# initialization

sub set_defaults {
  my $emc = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $emc->{context} = EMC::Common::attributes(
    EMC::Common::hash($emc, "context"),
    {
      # B

      build		=> {
	center		=> 0,
	dir		=> "../build",
	name		=> "build",
	order		=> "random",
	origin		=> {x => 0, y => 0, z => 0},
	niterations	=> 1000,
	nrelax		=> 100,
	radius		=> undef,
	replace		=> 0,
	theta		=> 0,
	weight		=> {
	  bond		=> undef,
	  focus		=> 1,
	  nonbond	=> undef
	}
      },

      # C

      convert		=> {},
      
      # D

      delete		=> {
	default		=> {
	  phase		=> 1,
	  fraction	=> 1,
	  center	=> [0, 0, 0],
	  thickness	=> ["infinite", "infinite", "infinite"],
	  type		=> "relative",
	  mode		=> "include",
	  sites		=> "all",
	  groups	=> "all",
	  clusters	=> "all"
	},
	phases		=> []
      },
      depth		=> 8,

      # E

      export		=> {
	smiles		=> ""
      },

      # F

      focus		=> [],

      # M

      moves		=> {
	cluster		=> {
	  default	=> {
	    active	=> "false",
	    clusters	=> "all",
	    cut		=> 0.05,
	    frequency	=> 1,
	    limit	=> "auto:auto",
	    max		=> "0:0",
	    min		=> "auto:auto",
	    phase	=> 0
	  },
	  phases	=> []
	},
	displace	=> {
	  default	=> {
	    active	=> "true",
	    frequency	=> 1
	  },
	  phases	=> []
	}
      },

      # N

      nphases		=> undef,

      # P

      phases		=> [],

      # R

      record		=> {
	flag		=> 0,
	name		=> '""',
	frequency	=> 1,
	inactive	=> "true",
	unwrap		=> "sites",
	pbc		=> "true",
	cut		=> "false"
      },
      region		=> {
	epsilon		=> 0.1,
	sigma		=> 1
      },
      run		=> {
	nequil		=> 0,
	ncycles		=> 0,
	nblocks		=> 100, 
	clusters	=> "all",
	groups		=> "all",
	sites		=> "all"
      },

      # S

      split		=> {
	default		=> {
	  phase		=> 1,
	  thickness	=> 1,
	  fraction	=> 0.5,
	  type		=> "relative",
	  mode		=> "random",
	  sites		=> "all",
	  groups	=> "all",
	  clusters	=> "all"
	},
	phases		=> []
      },
      suffix		=> -1,

      # T

      traject		=> {
	frequency	=> 0,
	append		=> "true"
      },

      # V

      verbatim		=> undef
    }
  );
  $emc->{defined} = EMC::Common::attributes(
    EMC::Common::hash($emc, "defined"),
    {
      build		=> {
	weight		=> {
	  focus		=> 1
	}
      }
    }
  );
  $emc->{flag} = EMC::Common::attributes(
    EMC::Common::hash($emc, "flag"),
    {
      # E
      
      exclude		=> {
	build		=> 0
      },
      execute		=> "-",

      # F

      focus		=> 0,

      # I

      insight		=> {
	compress	=> 0,
	pbc		=> 1,
	unwrap		=> 1,
	write		=> 0
      },

      # P

      progress		=> {
	build		=> 1,
	clusters	=> 0
      },

      # O

      output		=> {
	debug		=> 0,
	info		=> 1,
	warning		=> 1,
	exit		=> 1
      },

      # T

      test		=> 0,
      types		=> 0, 

      # W

      write		=> 1,

    }
  );
  $emc->{identity} = EMC::Common::attributes(
    EMC::Common::hash($emc, "identity"),
    $EMC::EMC::Identity
  );
  return $emc;
}


sub transfer {
  my $emc = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Build{center},		\$context->{build}->{center}],
    [\$::EMC::Build{dir},		\$context->{build}->{dir}],
    [\$::EMC::Build{name},		\$context->{build}->{name}],
    [\$::EMC::Build{order},		\$context->{build}->{order}],
    [\$::EMC::Build{origin},		\$context->{build}->{origin}],
    [\$::EMC::Build{niterations},	\$context->{build}->{niterations}],
    [\$::EMC::Build{nrelax},		\$context->{build}->{nrelax}],
    [\$::EMC::Build{radius},		\$context->{build}->{radius}],
    [\$::EMC::Build{replace},		\$context->{build}->{replace}],
    [\$::EMC::Build{theta},		\$context->{build}->{replace}],
    [\$::EMC::Build{weight},		\$context->{build}->{weight}],
    [\%::EMC::Convert,			\$context->{convert}],
    [\$::EMC::Delete,			\$context->{delete}],
    [\$::EMC::EMC{depth},		\$context->{depth}],
    [\$::EMC::EMC{exclude},		\$flag->{exclude}],
    [\$::EMC::EMC{execute},		\$flag->{execute}],
    [\$::EMC::EMC{export},		\$context->{export}],
    [\$::EMC::EMC{moves},		\$context->{moves}],
    [\$::EMC::EMC{output},		\$flag->{output}],
    [\$::EMC::EMC{progress},		\$flag->{progress}],
    [\$::EMC::EMC{run},			\$context->{run}],
    [\$::EMC::EMC{suffix},		\$context->{suffix}],
    [\$::EMC::EMC{test},		\$flag->{test}],
    [\$::EMC::EMC{traject},		\$context->{traject}],
    [\$::EMC::EMC{write},		\$flag->{write}],
    [\$::EMC::Flag{focus},		\$flag->{focus}],
    [\@::EMC::Focus,			\$context->{focus}],
    [\%::EMC::Insight,			\$flag->{insight}],
    [\%::EMC::Moves,			\$context->{moves}],
    [\$::EMC::NPhases,			\$context->{nphases}],
    [\@::EMC::Phases,			\$context->{phases}],
    [\%::EMC::Record,			\$context->{record}],
    [\%::EMC::Region,			\$context->{region}],
    [\$::EMC::Split,			\$context->{split}],
    [\$::EMC::Verbatim{emc},		\$context->{verbatim}]
  );
}


sub set_commands {
  my $emc = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($emc, "set");
  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "emc_" : "";
  my $commands = $emc->{commands} = EMC::Common::attributes(
    EMC::Common::hash($emc, "commands"),
    {
      # B

      build		=> {
	comment		=> "set build script name",
	default		=> $context->{build}->{name},
	gui		=> ["string", "chemistry", "emc", "advanced"]},
      build_center	=> {
	comment		=> "insert first site at the box center",
	default		=> EMC::Math::boolean($context->{build}->{center}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      build_dir		=> {
	comment		=> "set build directory for LAMMPS script",
	default		=> $context->{build}->{dir},
	gui		=> ["string", "chemistry", "lammps", "advanced"]},
      build_order	=> {
	comment		=> "set build order of clusters",
	default		=> $context->{build}->{order},
	gui		=> ["string", "chemistry", "emc", "ignore"]},
      build_origin	=> {
	comment		=> "set build order of clusters",
	default		=> EMC::Hash::text($context->{build}->{origin}),
	gui		=> ["string", "chemistry", "emc", "ignore"]},
      build_replace	=> {
	comment		=> "replace already existing build results",
	default		=> EMC::Math::boolean($context->{build}->{replace}),
	gui		=> ["boolean", "environment", "top", "advanced"]},
      build_theta	=> {
	comment		=> "set the minimal insertion angle",
	default		=> EMC::Math::boolean($context->{build}->{theta}),
	gui		=> ["boolean", "environment", "top", "advanced"]},

      # D

      delete		=> {
	comment		=> "sets which clusters to delete; each deletion is separated by a +-sign; default assigns no clusters to delete",
	default		=> EMC::Hash::text($context->{delete}->{default}, "string"),
	gui		=> ["list", "chemistry", "emc", "ignore"]},

      # E

      emc		=> {
	comment		=> "create EMC build script",
	default		=> EMC::Math::boolean($flag->{write}),
	gui		=> ["boolean", "chemistry", "top", "ignore"]},
      emc_depth		=> {
	comment		=> "set ring recognition depth in groups paragraph",
	default		=> $context->{depth},
	gui		=> ["integer", "chemistry", "emc", "ignore"]},
      emc_export	=> {
	comment		=> "set EMC section to export",
	default		=> EMC::Hash::text($context->{export}, "string"),
	gui		=> ["string", "chemistry", "top", "string"]},
      emc_exclude	=> {
	comment		=> "set EMC section to exclude",
	default		=> EMC::Hash::text($flag->{exclude}, "boolean"),
	gui		=> ["string", "chemistry", "top", "ignore"]},
      emc_execute	=> {
	comment		=> "execute EMC build script",
	default		=> EMC::Math::boolean($flag->{execute}),
	gui		=> ["boolean", "chemistry", "top", "ignore"]},
      emc_moves		=> {
	comment		=> "set Monte Carlo moves for after build",
	default		=> EMC::Hash::text($context->{moves}, "integer"),
	gui		=> ["string", "chemistry", "top", "emc"]},
      emc_output	=> {
	comment		=> "set EMC output modes",
	default		=> EMC::Hash::text($flag->{output}, "boolean"),
	gui		=> ["string", "chemistry", "top", "ignore"]},
      emc_progress	=> {
	comment		=> "set progress indicators",
	default		=> EMC::Hash::text($flag->{progress}, "boolean"),
	gui		=> ["string", "chemistry", "top", "ignore"]},
      emc_run		=> {
	comment		=> "set Monte Carlo run conditions for after build",
	default		=> EMC::Hash::text($context->{run}, "string"),
	gui		=> ["string", "chemistry", "top", "emc"]},
      emc_test		=> {
	comment		=> "test EMC build script",
	default		=> EMC::Math::boolean($flag->{test}),
	gui		=> ["boolean", "chemistry", "top", "ignore"]},
      emc_traject	=> {
	comment		=> "settings for EMC trajectory",
	default		=> EMC::Hash::text($context->{traject}, "string"),
	gui		=> ["string", "chemistry", "top", "emc"]},

      # F

      focus		=> {
	comment		=> "list of molecules to focus on",
	default		=> "-",
	gui		=> ["string", "chemistry", "emc", "standard"]},

      # G

      grace		=> {
	comment		=> "(deprecated: use weight) set build relaxation grace",
	default		=> join(",", grace($context->{build}->{weight})),
	gui		=> ["list", "chemistry", "emc", "ignore"]},

      # I

      insight		=> {
	comment		=> "create InsightII CAR and MDF output",
	default		=> EMC::Math::boolean($flag->{insight}->{write}),
	gui		=> ["string", "chemistry", "emc", "ignore"]},
      insight_compress	=> {
	comment		=> "set InsightII CAR and MDF compression",
	default		=> EMC::Math::boolean($flag->{insight}->{compress}),
	gui		=> ["option", "chemistry", "emc", "ignore"]},
      insight_pbc	=> {
	comment		=> "apply periodic boundary conditions",
	default		=> EMC::Math::boolean($flag->{insight}->{pbc}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      insight_unwrap	=> {
	comment		=> "apply unwrapping",
	default		=> EMC::Math::boolean($flag->{insight}->{unwrap}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},

      # M

      moves_cluster	=> {
	comment		=> "define cluster move settings used to optimize build",
	default		=> EMC::Hash::text($context->{moves}->{cluster}->{default}, "string"),
	gui		=> ["list", "chemistry", "emc", "advanced"]},

      # N

      niterations	=> {
	comment		=> "set number of build insertion iterations",
	default		=> $context->{build}->{niterations},
	gui		=> ["integer", "chemistry", "emc", "standard"]},
      nrelax		=> {
	comment		=> "set number of build relaxation cycles",
	default		=> $context->{build}->{nrelax},
	gui		=> ["integer", "chemistry", "emc", "standard"]},

      # P

      phases		=> {
	comment		=> "sets which clusters to assign to each phase; each phase is separated by a +-sign; default assigns all clusters to phase 1",
	default		=> "all",
	gui		=> ["list", "chemistry", "top", "standard"]},

      # R

      radius		=> {
	comment		=> "set build relaxation radius",
	default		=> $context->{build}->{radius},
	gui		=> ["real", "chemistry", "emc", "standard"]},
      record		=> {
	comment		=> "set record entry in build paragraph",
	default		=> EMC::Hash::text($context->{record}, "string"),
	gui		=> ["list", "chemistry", "top", "ignore"]},
      region_epsilon	=> {
	comment		=> "set epsilon to use for exclusion regions",
	default		=> $context->{region}->{epsilon},
	gui		=> ["real", "chemistry", "field", "advanced"]},
      region_sigma	=> {
	comment		=> "set sigma to use for exclusion regions",
	default		=> $context->{region}->{sigma},
	gui		=> ["real", "chemistry", "field", "advanced"]},

      # S

      split		=> {
	comment		=> "sets which clusters to partition; each split is separated by a +-sign; default assigns no clusters to split",
	default		=> EMC::Hash::text($context->{split}->{default}, "string"),
	gui		=> ["list", "chemistry", "emc", "advanced"]},
      suffix		=> {
	comment		=> "set EMC and LAMMPS suffix",
	default		=> $context->{suffix},
	gui		=> ["string", "chemistry", "top", "ignore"]},

      # T

      types		=> {
	comment		=> "output types only",
	default		=> EMC::Math::boolean($flag->{types}),
	gui		=> ["string", "chemistry", "top", "ignore"]},

      # W

      weight		=> {
	comment		=> "set build relaxation energetic weights",
	default		=> EMC::Hash::text($context->{build}->{weight}, "real"),
	gui		=> ["list", "chemistry", "emc", "standard"]}
    }
  );

  foreach (keys(%{$commands})) {
    my $ptr = $commands->{$_};
    if (!defined($ptr->{set})) {
      $ptr->{set} = \&EMC::EMC::set_options;
    }
  }

  $emc->{items} = EMC::Common::attributes(
    EMC::Common::hash($emc, "items"),
    {
      emc		=> {
	chemistry	=> 1,
	environment	=> 0,
	order		=> 0,
	set		=> \&EMC::Script::set_item_verbatim
      },
      shorthand		=> {
	chemistry	=> 1,
	environment	=> 1,
	order		=> 0,
	set		=> \&set_item_shorthand
      }
    }
  ); 

  $emc->{notes} = [
    "This script comes with no warrenty of any kind.  It is distributed under the same terms as EMC, which are described in the LICENSE file included in the EMC distribution.",
    "A '+' sign demarcates clusters for each phase; remaining clusters are assigned to the first empty phase"
  ];
  return $emc;
}


sub set_context {
  my $emc = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($root, "global", "units");
  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $defined = EMC::Common::element($emc, "defined");

  if (!defined($defined->{build}->{radius})) {
    $context->{build}->{radius} = (
      $field->{type} eq "dpd" ? 1.0 :
      $field->{type} eq "gauss" ? 1.5 : 5.0);
  }
  foreach (keys(%{$context->{build}->{weight}})) {
    if (!defined($defined->{build}->{weight}->{$_})) {
      $context->{build}->{weight}->{$_} = (
	$field->{type} eq "dpd" ? 0.01 :
	$field->{type} eq "gauss" ? 0.01 : 0.0001);
    }
  }

  if (!$flag->{write}) {
    $flag->{execute} = $flag->{test} = 0;
  }
  if (EMC::Math::flag($flag->{execute})) {
    $flag->{executable} = $ENV{HOST} ne "" ? 
			  "emc_$ENV{HOST}" : "emc".$context->{suffix};
  } elsif ($flag->{execute} eq "-" || EMC::Math::flag_q($flag->{execute})) {
    $flag->{execute} = 0;
  } elsif ($flag->{execute} ne "-") {
    $flag->{executable} = $flag->{execute};
    $flag->{execute} = 1;
  }

  $context->{nphases} = $global->{nphases} = scalar(@{$context->{phases}});

  if (!defined($defined->{suffix})) {
    my $suffix;
    if ($ENV{HOST} ne "") {
      $suffix = $ENV{HOST};
    } elsif ($^O eq "MSWin32" || $^O eq "MSWin64") { 
      $suffix = "win32";
    } elsif ($^O eq "darwin") { 
      $suffix = "macos";
    } elsif ($^O eq "linux") {
      my $uname = `uname -m`;
      $suffix = "linux";
      $suffix .= "_".$uname if ($uname eq "x86_64" || $uname eq "aarch64");
    }
    $context->{suffix} = "_$suffix";
  }
  $context->{suffix} = (split("\n", $context->{suffix}))[0];
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $emc = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $defined = EMC::Common::element($emc, "defined");
  my $build = EMC::Common::element($context, "build");
  my $set = EMC::Common::element($struct, "root", "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $n = scalar(@{$args});

  $indicator = $indicator ? "emc_" : "";

  # B

  if ($option eq "build") {
    return $build->{name} = $args->[0]; }
  if ($option eq "build_center") {
    return $build->{center} = EMC::Math::flag($args->[0]); }
  if ($option eq "build_dir") { 
    return $build->{dir} = $args->[0]; }
  if ($option eq "build_order") {
    return $build->{order} = 
      EMC::Options::set_allowed($line, $args->[0], "random", "sequence"); }
  if ($option eq "build_origin") {
    EMC::Hash::set(
      $line, $build->{origin}, "string", "0", [], @{$args});
    return 1; }
  if ($option eq "build_replace") {
    return $build->{replace} = EMC::Math::flag($args->[0]); }
  if ($option eq "build_theta") {
    return $build->{theta} = EMC::Math::eval($args->[0])->[0]; }

  # D

  if ($option eq "delete") {
    return EMC::List::set_list_oper($line, $context->{delete}, @{$args});
  }

  # E

  if ($option eq "emc") { 
    return $flag->{write} = EMC::Math::flag($args->[0]); }
  if ($option eq "emc_depth") {
    my $value = EMC::Math::eval($args->[0])->[0];
    if ($args->[0] eq "auto") { $context->{depth} = "auto"; }
    elsif ($value>2) { $context->{depth} = $value; }
    else { 
      EMC::Message::error_line(
	$line, "ring depth can only be set to auto or values > 2\n");
    }
    return $context->{depth};
  }
  if ($option eq "emc_export") {
    my %allowed = (csv => 1, json => 2, math => 3, false => 0, true => 1);
    my @convert = ("", "csv", "json", "math");
    EMC::Hash::set($line, $context->{export}, "string", "", [], @{$args});
    my $ptr = $context->{export};
    foreach (sort(keys(%{$ptr}))) {
      next if ($_ eq "flag");
      if (!defined($allowed{$ptr->{$_}})) {
	EMC::Message::error_line($line, "illegal emc_export $_ argument\n");
      }
      $ptr->{$_} = @convert[$allowed{$ptr->{$_}}];
    }
    return $context->{export};
  }
  if ($option eq "emc_exclude") {
    EMC::Hash::set($line, $flag->{exclude}, "boolean", "", [], @{$args});
    return $flag->{exclude};
  }
  if ($option eq "emc_execute") {
    return $flag->{execute} = $args->[0]; }
  if ($option eq "emc_moves") {
    EMC::Hash::set($line, $context->{moves}, "integer", "", [], @{$args});
    return $context->{moves};
  }
  if ($option eq "emc_output") { 
    EMC::Hash::set($line, $flag->{output}, "boolean", "", [], @{$args});
    return $flag->{output};
  }
  if ($option eq "emc_progress") {
    EMC::Hash::set($line, $flag->{progress}, "boolean", "", [], @{$args});
    return $flag->{progress}; }
  if ($option eq "emc_run") {
    EMC::Hash::set($line, $context->{run}, "string", "", [], @{$args});
    return $context->{run};
  }
  if ($option eq "emc_test") {
    $flag->{test} = EMC::Math::flag($args->[0]); }
  if ($option eq "emc_traject") { 
    EMC::Hash::set($line, $context->{traject}, "string", "", [], @{$args});
    return $context->{traject};
  }

  # F

  if ($option eq "focus") {
    my $result = -1;
    $context->{focus} = [];
    foreach (@{$args}) {
       if ($_ eq "-" || $_ eq "false" || $_ eq "none") { $result = 0; last; }
       if ($_ eq "all" || $_ eq "true") { $result = 1; last; }
    }
    if ($result<0) {
      push(@{$context->{focus}}, @{$args}) if (scalar(@{$args}));
      $flag->{focus} = 1;
    }
    else { 
      $flag->{focus} = $result;
    }
    return $flag->{focus};
  }

  # G

  if ($option eq "grace") {
    EMC::Message::warning(
      "'grace' has been deprecated; please use 'weight' instead\n");
    $n = 3 if ($n>3);
    my $value = EMC::Math::eval($args);
    my $i; for ($i=0; $i<$n; ++$i) {
      $build->{weight}->{
	("nonbond", "bond", "focus")[$i]} = 1.0-$value->[$i]; }
    return 1; }

  # I

  if ($option eq "insight") { 
    return $flag->{insight}->{write} = EMC::Math::flag($args->[0]); }
  if ($option eq "insight_compress") { 
    return $flag->{insight}->{compress} = EMC::Math::flag($args->[0]); }
  if ($option eq "insight_pbc") { 
    return $flag->{insight}->{pbc} = EMC::Math::flag($args->[0]); }
  if ($option eq "insight_unwrap") { 
    return $flag->{insight}->{unwrap} = EMC::Math::flag($args->[0]); }

  # M

  if ($option eq "moves_cluster") {
    EMC::List::set_list_oper($line, $context->{moves}->{cluster}, @{$args});
    return $context->{moves}->{cluster};
  }

  # N

  if ($option eq "niterations") { 
    return $build->{niterations} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "nrelax") {
    return $build->{nrelax} = EMC::Math::eval($args->[0])->[0]; }

  # P

  if ($option eq "phases") {
    my @phase;
    foreach (@{$args}) {
      if ($_ eq "+") {
       	push(@{$context->{phases}}, [@phase]); @phase = ();
      }
      elsif (index($_, "\+")>=0) {
	my $first = 1;
	foreach (split("\\+")) {
	  next if ($_ eq "");
	  push(@phase, $_) if ($first);
	  push(@{$context->{phases}}, [@phase]) if (scalar(@phase)); 
	  @phase = $first ? () : ($_); $first = 0;
	}
      }
      else {
       	push(@phase, $_) if ($_ ne "");
      }
    }
    push(@{$context->{phases}}, [@phase]) if (scalar(@phase));
    if (scalar(@{$context->{phases}})==1 && 
        scalar(@phase)==1 && @phase[0] eq "all") {
      $context->{phases} = [];
    }
    $context->{nphases} = scalar(@{$context->{phases}});
    return $context->{phases};
  }

  # R

  if ($option eq "radius") {
    $defined->{build}->{radius} = 1;
    return $build->{radius} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "record") {
    my $n = 0;
    my $value = EMC::Math::eval($args);
    my $record = $context->{record};

    foreach (@{$args}) { 
      ++$n if (scalar(split("="))==1);
    }
    if ($n) {
      if (scalar(@{$args})!=$n) {
	EMC::Message::error_line($line,
	  "record is missing identifiers\n");
      }
      if ($n!=3) {
	EMC::Message::error_line($line,
	  "record needs exactly 3 entries when omitting identifiers\n");
      }
    }
    if ($n==3) {
      if (!length($args->[0])) {
	EMC::Message::error_line($line,
	  "record name cannot be empty\n");
      }
      if (!$value->[1]) {
	EMC::Message::error_line($line,
	  "record frequency has to be larger than 1\n");
      }
      $record->{name} = $args->[0];
      $record->{frequency} = $value->[1];
      $record->{inactive} = EMC::Math::boolean(flag($args->[2]));
    } else {
      EMC::Hash::set($line, $record, "string", "", [], @{$args});
      foreach (keys(%{$record})) {
	if ($_ eq "frequency") { 
	  $record->{$_} = EMC::Math::eval($record->{$_});
	} elsif ($_ eq "unwrap") {
	  $record->{$_} = EMC::EMC::flag_unwrap($record->{$_});
	} elsif ($_ ne "name") {
	  $record->{$_} = EMC::Math::boolean(flag($record->{$_}));
	}
      }
    }
    return $record->{flag} = 1;
  }
  if ($option eq "region_epsilon") {
    my $value = EMC::Math::eval($args->[0])->[0];
    my $region = $context->{region};
    $region->{epsilon} = $value>0.0 ? $value : $args->[0] if ($value>=0.0);
    return $region->{epsilon};
  }
  if ($option eq "region_sigma") {
    my $value = EMC::Math::eval($args->[0])->[0];
    my $region = $context->{region};
    $region->{sigma} = $value>0.0 ? $value : $args->[0] if ($value>=0.0);
    return $region->{sigma};
  }

  # S

  if ($option eq "split") {
    return EMC::List::set_list_oper($line, $context->{split}, @{$args}); }
  if ($option eq "suffix") { 
    $defined->{suffix} = 1;
    return $context->{suffix} = $args->[0]; }

  # T

  if ($option eq "types") {
    return $flag->{types} = EMC::Math::flag($args->[0]);
  }

  # W

  if ($option eq "weight") {
    my $tmp = EMC::Hash::define(EMC::Hash::copy($build->{weight}), undef);
    EMC::Hash::set($line, $tmp, "real", "", [], @{$args});
    foreach (keys(%{$tmp})) {
      next if (!defined($tmp->{$_}));
      $defined->{build}->{weight}->{$_} = 1;
      $build->{weight}->{$_} = $tmp->{$_};
    }
    return 1; }

  return undef;
}


sub set_functions {
  my $emc = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($emc, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, indicator => 1, items => 1};

  $set->{commands} = \&EMC::EMC::set_commands;
  $set->{context} = \&EMC::EMC::set_context;
  $set->{defaults} = \&EMC::EMC::set_defaults;
  $set->{options} = \&EMC::EMC::set_options;
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $emc;
}


# set item

sub set_item_shorthand {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $flag = EMC::Common::element($root, "global", "flag");
  my $option = EMC::Common::element($struct, "option");
  my $emc = EMC::Common::element($struct, "module");
  
  my $polymers = EMC::Common::element($emc, "polymers");
  my $clusters = EMC::Common::element($emc, "clusters");
  my $groups = EMC::Common::element($emc, "groups");
  my $index = $groups->{index} = EMC::Common::array($groups, "index");
  
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $iline = 0;

  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$iline++];

    my $mass;
    my @field;
    my $volume;
    my $charges;
    my $terminator = 0;
    my $id = EMC::Groups::set_group(
      $root, $line, shift(@arg), \$charges, \@field, \$mass, \$terminator);
    my $name = EMC::Common::convert_name($id)->[0];
    my $chemistry = shift(@arg);
    my $group = EMC::Common::hash($groups, "group");
   
    EMC::EMC::check_name($emc, $name, $line, 0);
    push(@{$index}, $name) if (!defined($group->{$name}));

    $group = $group->{$name} = {
      id => $id,
      charges => $charges,
      chemistry => $chemistry,
      connect => [],
      field => [@field],
      line => $line,
      mass => $mass,
      nconnects => 0,
      polymer => 0,
      type => 'group',
      terminator => 0,
      flag => {regular => 1},
      nextra => EMC::Chemistry::count_clusters($chemistry)
    };
    $struct->{line} = $line;
    $struct->{args} = [$name, $name, @arg];
    $struct->{module} = $clusters;
    EMC::Clusters::set_cluster($struct);
  }
  EMC::Groups::set_context($groups);
  return $root;
}


# option functions

sub check_name {
  my $struct = shift(@_);
  my $name = shift(@_);
  my $line = shift(@_);
  my $itype = shift(@_);
  my $type = ("group", "cluster", "polymer")[$itype];

  my $global = EMC::Common::element($struct, "root", "global");
  my $project = EMC::Common::element($global, "project", "name");
  my $restricted = EMC::Common::hash($global, "restricted");
  my $flag = EMC::List::hash(
    $itype ? (@{$restricted->{all}}, $project) : 
	     (@{$restricted->{all}}, @{$restricted->{group}}, $project));

  if ($name eq "") {
    EMC::Message::error_line($line,
      "empty name\n");
  }
  if (substr($name,0,1) =~ m/[0-9]/) {
    EMC::Message::error_line($line,
      "illegal $type name \'$name\' (starts with a number)\n");
  }
  if ($name =~ m/[+\-\.*\%\/]/) {
    EMC::Message::error_line($line,
      "illegal $type name \'$name\' (contains an illegal character)\n");
  }
  if ($flag->{$name}) {
    EMC::Message::error_line($line,
      "illegal $type name \'$name\' (reserved variable)\n");
  }
  foreach (@{$restricted->{start}}) {
    next if ($_ ne substr($name,0,length($_)));
    EMC::Message::error_line($line,
      "illegal $type name \'$name\' (disallowed variable start)\n");
  }
  return $name;
}


sub grace {
  my $weight = shift(@_);
  my @order = ("nonbond", "bond", "focus");
  my @grace;

  foreach (@order) { push(@grace, 1.0-${$weight}{$_}); }
  return @grace;
}


# validity check

sub check_validity {
  my $root = shift(@_);
  
  return if (EMC::Common::element($root, "environment", "flag", "active"));

  my $emc = EMC::Common::hash($root, "emc");
  my $context = EMC::Common::hash($emc, "context");
  my $clusters = EMC::Common::hash($emc, "clusters");
  my $global = EMC::Common::hash($root, "global");
  my $flag = EMC::Common::hash($root, "global", "flag");
  my $groups = EMC::Common::hash($emc, "groups");
  my $polymer = EMC::Common::hash($emc, "polymers", "polymer");
  my $import = EMC::Common::hash($emc, "clusters", "import");

  # check connectivity

  if ((!$flag->{reduced}) && 
      (scalar(@{$clusters->{index}}) != scalar(@{$clusters->{mol_mass}}))) {
    EMC::Message::error(
      "mol masses need to be defined for set force field type\n");
  }
  
  my %check; 
  my $nphases = scalar(@{$context->{phases}});
  my @phases = ();
  my $iphase = 0;

  # check clusters

  foreach (@{$clusters->{index}}) {
    my $poly = defined($polymer->{$_}) ? $polymer->{$_} : undef;

    if (ref($poly->{data}) ne "ARRAY") {
      EMC::Message::error("missing polymer definition for cluster '$_'\n");
    }
    $check{$_} = -1;
  }

  # check phases

  foreach (@{$context->{phases}}) {
    ++$iphase; foreach (@$_) {
      if (defined $check{$_}) {
	if ($check{$_}<0) {				# keep order as entered
	  push(@{$phases[($check{$_} = $iphase)-1]}, $_); next;
	}
	warning("cluster '$_' is already assigned to phase $check{$_}\n");
      }
      else {
	if ($flag->{expert}) {
	  push(@{$phases[($check{$_} = $iphase)-1]}, $_); next;
	} else {
	  #warning("ignoring cluster '$_': does not occur in chemistries\n");
	  EMC::Message::error("cluster '$_': does not occur in chemistries\n");
	}
      }
    }
  }

#  foreach (keys(%type)) {
#    next if (!$type{$_});
#    next if (defined($polymer->{$_}));
#    EMC::Message::error("undefined polymer \'$_\' in check paragraph\n");
#  }
  
  my @rest;
  my $iempty = -1;
  
  foreach (@{$clusters->{index}}) {			# add remains at empty
    push(@rest, $_) if ($check{$_}<1);
  }
  
  # check phases

  for ($iphase=0; $iphase<$nphases; ++$iphase) {
    next if (defined(@phases[$iphase]));
    if (!scalar(@rest)) {
      EMC::Message::error("empty phase definition\n");
    } elsif ($iempty>=0) {
      EMC::Message::error("multiple empty phase definitions\n");
    }
    $iempty = $iphase;
  }
  if (scalar(@rest)) {
    $phases[$iempty<0 ? $nphases : $iempty] = [@rest];
  }

  $iphase = 0;
  $context->{phases} = [];
  $clusters->{sampling} = 
    defined($import->{name}) ? [$import->{name}] : [];
  foreach (@phases) { 
    if (defined($_) && scalar(@{$_})>0) {
      push(@{$context->{phases}}, $_);
      EMC::Message::info("phase%d = {%s}\n", ++$iphase, join(", ", @$_));
      push(@{$clusters->{sampling}}, @$_);
    }
  }
  $global->{nphases} = $context->{nphases} = scalar(@{$context->{phases}});
  if (!defined($global->{shape})) {
    $global->{shape} = $global->{shape_default}->[$global->{nphases}>1 ? 1 : 0];
  }
}


sub convert_key {
  my $emc = shift(@_);
  my $convert = EMC::Common::hash($emc, "context", "convert");

  return 
    scalar(@_)>1 ?
    defined($convert->{@_[0]}) ?
    defined($convert->{@_[0]}->{@_[1]}) ?
    $convert->{@_[0]}->{@_[1]} : 0 : 0 : 0;
}


sub create_clusters {
  my $emc = shift(@_);
  my $polymers = EMC::Common::hash($emc, "polymers", "id");
  my $polymer = EMC::Common::hash($emc, "polymers", "polymer");
  my @clusters = ();

  foreach (@_) {
    if (defined($polymer->{$_})) {
      my $poly = $polymer->{$_};
      my $npolys = scalar(@{$poly->{data}});
      if (EMC::Common::element($poly, "options", "group") ? 0 : $npolys>1) {
	my $name = $_;
	my $i;
	for ($i=1; $i<=$npolys; ++$i) {
	  push(@clusters, $name."_".$i);
	}
      }
      else {
	push(@clusters, $_);
      }
    }
    else {
      push(@clusters, $_);
    }
  }
  return @clusters;
}


sub create_groups {				# <= create_emc_groups
  my @groups;
  foreach (@_) {
    my @arg = split(":", $_);
    push(@groups, scalar(@arg)>1 ? "{".join(", ", @arg)."}" : $_);
  }
  return @groups;
}


sub flag_unwrap {
  my %allowed = (clusters => 1, sites => 1);

  return @_[0] if (defined($allowed{@_[0]}));
  
  my @flag = ("none", "clusters", "sites");
  my $value = EMC::Math::flag(@_[0]);
  
  return @flag[$value<0 ? 0 : $value>2 ? 2 : $value];
}


sub set_convert_key {
  my $emc = shift(@_);
  my $type = shift(@_);					# used during init
  my $key = shift(@_);
  my $convert = EMC::Common::hash($emc, "context", "convert");
  my $index = 1;

  $convert->{$type}->{$key} = 1;
  foreach (sort(keys(%{$convert->{type}}))) {
    $convert->{$type}->{$_} = $index++;
  }
}


# I/O functions

sub write_script {				# <= write_emc
  my $root = shift(@_);
  my $name = shift(@_);

  my $emc = EMC::Common::element($root, "emc");
  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $global = EMC::Common::element($root, "global");
  my $clusters = EMC::Common::element($emc, "clusters");
  my $fimport = defined(
    EMC::Common::element($emc, "clusters", "import", "name")) ? 1 : 0;
  my $fgraft = defined(
    EMC::Common::element($emc, "groups", "context", "ngrafts")) ? 1 : 0;

  return if (!$flag->{write});
  
  if ((-e "$name.emc")&&!$global->{replace}->{flag}) {
    EMC::Message::warning(
      "\"$name.emc\" exists; use -replace flag to overwrite\n");
    return;
  }

  EMC::Message::info("creating EMC build script \"$name.emc\"\n");

  my $stream = EMC::IO::open("$name.emc", "w");

  write_header($stream, $emc);
  printf($stream "\n") if (write_user($stream, $emc, 0, 0));
  write_variables_header($stream, $emc);
  printf($stream "\n") if (write_user($stream, $emc, 0, 1));
  write_field($stream, $emc);
  write_import($stream, $emc);
  printf($stream "\n") if (write_user($stream, $emc, 0, 2));
  write_groups($stream, $emc, "regular");
  write_field_apply($stream, $emc);
  write_variables_sizing($stream, $emc, "regular");
  write_import_variables($stream, $emc);
  write_groups($stream, $emc, "graft") if ($fgraft);
  write_field_apply($stream, $emc);
  if ($fgraft) {
    write_clusters($stream, $emc, "graft", @{$clusters->{index}});
    write_variables_sizing($stream, $emc, "graft");
    write_field_apply($stream, $emc);
  }
  printf($stream "\n") if (write_user($stream, $emc, 0, 3));
  write_simulation($stream, $emc);
  my $iphase = 0;
  foreach (@{$context->{phases}}) {
    write_phase($stream, $emc, ++$iphase, @$_);
  }
  printf($stream "\n") if (write_user($stream, $emc, $iphase+1, 0));
  write_run($stream, $emc);
  write_profile($stream, $emc);
  write_focus($stream, $emc);
  write_store($stream, $emc);
  EMC::IO::close($stream);
}


sub write_build {				# <= write_emc_build
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $phase = shift(@_);

  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $global = EMC::Common::element($emc, "root", "global");

  return if ($flag->{test});
  return if ($flag->{exclude}->{build});

  my $mode = "soft";
  my @clusters = create_clusters($emc, @_);
  my $n = scalar (@clusters)-1;
  my $i = 0;
  
  my $lx = $phase ? "2*fshape" : "fshape";
  my $split = $context->{split}->{phases};
  my $fsplit = $phase ? defined($split->[$phase-1]) ? 1 : 0 : 0;
  my $fwall = $global->{flag}->{exclude}==2 ? 1 : 0;
  my @flags;

  foreach (sort(keys(%{$global->{system}}))) {
    next if ($_ eq "flag" || $_ eq "id");
    push(@flags, "$_ -> ".EMC::Math::boolean($global->{system}->{$_}));
  }

  printf($stream "build\t\t= {\n");
  printf($stream "%s\n", format_output(0, "system {", 2, 2));
  printf($stream "%s",
    format_output(1, "id ".$global->{system}->{id}, 4, 2));
  printf($stream "%s", 
    format_output(1, "split ".EMC::Math::boolean($fsplit), 4, 2));
  #printf($stream "%s", format_output(1, "density density", 4, 2));
  printf($stream "%s",
    format_output(1, "geometry {xx -> lxx, yy -> lyy, zz -> lzz", 4, 2));
  printf($stream "\t\t    zy -> lzy, zx -> lzx, yx -> lyx},\n");
  if (!defined($context->{import}->{name}) && $global->{deform}->{flag}) {
    printf($stream "%s", 
      format_output(1, "deform {".
	"$global->{deform}->{xx}, $global->{deform}->{yy}, ".
	"$global->{deform}->{zz}, $global->{deform}->{zy}, ".
	"$global->{deform}->{zx}, $global->{deform}->{yx}}", 4, 2));
  }
  printf($stream "%s", format_output(1, "temperature temperature", 4, 2));
  printf($stream "%s", format_output(0, "flag {".join(", ", @flags)."}", 4, 2));
  printf($stream "\n");
  printf($stream "%s", format_output(1, "}", 2, 2));

  printf($stream "%s\n", format_output(0, "select {", 2, 2));
  printf($stream "%s", format_output(1, "progress ".
      ($flag->{progress}->{build} ? "list" : "none"), 4, 2));
  printf($stream "%s", format_output(1, "frequency 1", 4, 2));
  printf($stream "%s", format_output(1, "name \"error\"", 4, 2));
  if ($context->{build}->{center}) {
    printf($stream "%s", 
      format_output(1, "center ".
	EMC::Math::boolean($context->{build}->{center}), 4, 2));
    my $v = $context->{build}->{origin};
    printf($stream "%s", 
      format_output(1, "origin {$v->{x}, $v->{y}, $v->{z}}", 4, 2));
  }
  printf($stream "%s", 
    format_output(1, "order $context->{build}->{order}", 4, 2));
  printf($stream "%s",
    format_output(1, "cluster {".join(", ", @clusters)."}", 4, 2));
  printf($stream "%s",
    format_output(1, "relax {ncycles -> nrelax, radius -> radius}", 4, 2));

  if ($context->{record}->{flag}) {
    printf($stream "%s\n", format_output(0, "record {", 4, 2));
    printf($stream "%s", 
      format_output(1, "name ".$context->{record}->{name}, 6, 2));
    printf($stream "%s",
      format_output(1, "frequency ".$context->{record}->{frequency}, 6, 2));
    my $n = scalar(keys(%{$context->{record}}));
    foreach (sort(keys(%{$context->{record}}))) {
      --$n; if ($_ ne "flag" && $_ ne "name" && $_ ne "frequency") {
	printf($stream "%s",
	  format_output($n, "$_ ".$context->{record}->{$_}, 6, 2));
      }
    }
    printf($stream "\n    },\n");
  }

  printf($stream "%s\n", format_output(0, "grow {", 4, 2));
  printf($stream "%s", format_output(1, "method energetic", 6, 2));
  printf($stream "%s", format_output(1, "check all", 6, 2));
  printf($stream "%s", format_output(1, "nbonded 20", 6, 2));
  printf($stream "%s", format_output(1, "ntrials 20", 6, 2));
  printf($stream "%s", 
    format_output(1, "niterations $context->{build}->{niterations}", 6, 2));
  printf($stream "%s",
    format_output(1, "theta $context->{build}->{theta}", 6, 2));
  
  my $exclude = $phase>1 ? $global->{flag}->{exclude} : 0;

  #if ($phase<2 && 
  #	defined($context->{import}->{name}) && 
  #	$context->{import}->{type} ne "structure") {
  #  $exclude = $phase = 1; $mode = "hard";
  #}

  my $n = $fwall ? $phase<$context->{nphases} : 0;
  my $i0 = $phase>1 ? 0 : 1;
  my $t = $fwall ? 10 : 8;
  my $dir = $global->{direction}->{x};

  printf($stream "%s\n", format_output(0, "weight {", 6, 2));
  printf($stream "%s", format_output(1, "bonded weight_bond, nonbonded -> weight_nonbond", 8, 2));
  printf($stream "%s", format_output($n>=$i0, "focus weight_focus}", 8, 2));

  printf($stream "%s\n", format_output(0, "exclude {", 6, 2)) if ($n>=$i0);
  for (my $i=$i0; $i<=$n; ++$i) {
    my $lx = $dir eq "x" ? $i ? "lwall" : "lprevious" : "lxx";
    my $ly = $dir eq "y" ? $i ? "lwall" : "lprevious" : "lyy";
    my $lz = $dir eq "z" ? $i ? "lwall" : "lprevious" : "lzz";
    
    my $cx = $dir eq "x" ? "0.5*lxx" : "0";
    my $cy = $dir eq "y" ? "0.5*lyy" : "0";
    my $cz = $dir eq "z" ? "0.5*lzz" : "0";

  printf($stream "%s\n", format_output(0, "{", 8, 2)) if ($n);
    printf($stream "%s",
      format_output(1, "shape cuboid, type -> absolute, mode -> $mode", $t, 2));
    if ($i) {
      printf($stream "%s",
	format_output(1, "center {x -> $cx, y -> $cy, z -> $cz}", $t, 2));
    }
    printf($stream "%s",
      format_output(1, "h {xx -> $lx, yy -> $ly, zz -> $lz", $t, 2));
    printf($stream "\t\t    zy -> lzy, zx -> lzx, yx -> lyx}");
    printf($stream "\n%s", format_output($i<$n, "}", 8, 2)) if ($n);
  }
  printf($stream "\n%s", format_output(0, "}", 6, 2)) if ($n>=$i0);
  printf($stream "\n%s", format_output(0, "}", 4, 2));
  printf($stream "\n%s", format_output(0, "}", 2, 2));
  printf($stream "\n};\n\n");
}


sub write_clusters {				# <= write_emc_clusters
  my $stream = shift(@_);			# !!! changed cluster syntax !!!
  my $emc = shift(@_);				# !!!         REDO!          !!!
  my $type = shift(@_);
  my @clusters = @_;

  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $groups = EMC::Common::element($emc, "groups");
  my $cluster = EMC::Common::element($emc, "clusters", "cluster");
  my $polymers = EMC::Common::element($emc, "polymers");
  my $polymer = EMC::Common::element($polymers, "polymer");
  my $polymer_id = EMC::Common::element($polymers, "id");
  my $global = EMC::Common::element($emc, "root", "global");

  my $n = scalar (@clusters);
  my $i = 0;

  foreach (@clusters) {
    if (!defined($polymer->{$_})) {
      --$n; 
      if ($global->{flag}->{expert}) {
	warning("allowing undefined group '$_'\n");
      } else {
	EMC::Message::error("undefined group '$_'\n");
      }
      next;
    }
    --$n if (defined($cluster->{$_}->{flag}->{regular}) && $type ne "regular");
    --$n if (defined($cluster->{$_}->{flag}->{graft}) && $type ne "graft");
  }

  return if (!$n);

  printf($stream "(* define $type clusters *)\n\n") if ($type ne "regular");
  printf($stream "clusters\t= {\n");
  printf($stream "%s", format_output(1, "progress ".
      ($flag->{progress}->{clusters} ? "list" : "none"), 2, 2));
  foreach (@clusters) {
    my $ipoly = 0;
   
    if (EMC::Common::element($polymer, $_, "options", "group") ? 1 :
        EMC::Common::element($polymer, $_, "options", "type") ? 0 : 1) {
      if (!EMC::Common::element($polymer, $_, "data")) {
	--$n; next;
      }
      my $group = $cluster->{$_}->{group}->{id};

      if (defined($cluster->{$_}->{flag}->{graft})) {
	next if ($type eq "regular");
	printf($stream "%s\n",
	  format_output(0, "cluster {", 2, 2));
	printf($stream "%s",
	  format_output(1, "id $_, ".
	    "system -> $global->{system}->{id}, ".
	    "group -> $group}", 4, 2));
	printf($stream "%s\n",
	  format_output(0, "graft {", 2, 2));
	printf($stream "%s",
	  format_output(--$n, "cluster $_, ".
	    "selection -> $group, fraction -> f_$_}", 4, 2));
      } elsif(defined($cluster->{$_}->{flag}->{regular})) {
	next if ($type eq "graft");
	printf($stream "%s\n",
	  format_output(0, "cluster {", 2, 2));
	printf($stream "%s",
	  format_output(--$n, "id $_, ".
	    "system -> $global->{system}->{id}, ".
	    "group -> $group, n -> n_$_}", 4, 2));
      }
    } else {
      next if ($type eq "graft");
      write_polymers($stream, $emc, "cluster", $_, --$n);
    }
  }
  printf($stream "\n};\n\n");
}


sub write_delete {				# <= write_emc_delete
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $phase = shift(@_);

  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $global = EMC::Common::element($emc, "root", "global");

  my @clusters = $phase ? create_clusters($emc, @{$context->{phases}->[$phase-1]}) : ();
  my $delete = $context->{delete}->{phases};
  my $direction = $global->{direction}->{x};
  my $dir = {x => 0, y => 1, z => 2}->{$direction};
  my $unwrap = 1;

  $dir = [$dir, ($dir+1)%3, ($dir+2)%3];
  foreach (@{$delete->[$phase]}) {
    my $hash = $_;
    my @focus = ();
    my @center = (0, 0, 0);
    my $thickness = $hash->{thickness};
    my @h = ("infinite", "infinite", "infinite");
    
    for (my $i=0; $i<3; ++$i) {
      @h[$dir->[$i]] = $thickness->[$i] if ($thickness->[$i] ne "infinite");
      @center[$dir->[$i]] = $hash->{center}->[$i] if ($hash->{center});
    }
    if (0 && !$hash->{center}) {
      @center[$dir->[0]] = 0.5;
      if ($hash->{type} eq "absolute") {
	my @l = (["lxx", "lyx", "lzx"], ["1", "lyy", "lyz"], ["1", "1", "lzz"]);
	for (my $i=0; $i<3; ++$i) {
	  next if (@center[$i] eq "0");
	  next if (@l[$i]->[$dir] eq "1");
	  @center[$i] .= "*".@l[$i]->[$dir];
	}
      }
    }
    printf($stream "delete\t\t= {\n");
    #printf($stream format_output(1, "system ".$global->{system}->{id}, 2, 2));
    #printf($stream format_output(1, "direction ".$direction, 2, 2));
    printf($stream format_output(1, "mode ".$hash->{mode}, 2, 2));
    printf($stream format_output(1, "unwrap ".EMC::Math::boolean($unwrap), 2, 2));
    printf($stream format_output(1, "fraction ".$hash->{fraction}, 2, 2));
    $unwrap = 0;
    
    foreach ("sites", "groups", "clusters") {
      if ($hash->{$_} ne "all") {
	push(@focus, {$_ => $hash->{$_}});
      }
    }
    if (scalar(@focus)) {
      my $i;
      my $n = scalar(@focus)-1;

      printf($stream format_output(0, "focus {", 2, 2));
      printf($stream "\n");
      for ($i=0; $i<=$n; ++$i) {
	my $select = @focus[$i];
	my $key = (keys(%{$select}))[0];

	printf($stream format_output($i<$n, "$key {".join(", ", @{$select->{$key}})."}", 4, 2));
	printf($stream "\n") if ($i==$n);
      }
      printf($stream format_output(1, "}", 2, 2));
    }
    printf($stream format_output(0, "outside {", 2, 2));
    printf($stream "\n");
    printf($stream format_output(1, "shape cuboid", 4, 2));
    printf($stream format_output(1, "type ".$hash->{type}, 4, 2));
    printf($stream format_output(1, "center {".join(", ", @center)."}", 4, 2));
    printf($stream format_output(0, "h {".join(", ", @h)."}", 4, 2));
    printf($stream "\n");
    printf($stream format_output(0, "}", 2, 2));
    printf($stream "\n};\n\n");
  }
}


sub write_field {				# <= write_emc_field
  my $stream = shift(@_);
  my $emc = shift(@_);

  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $global = EMC::Common::element($emc, "root", "global");
  my $fields = EMC::Common::element($emc, "root", "fields");

  my $n = scalar(keys(%{$fields->{fields}}));
  my $pos = $n>1 ? 4 : 2;
  my $none = 1;
  my $i = 0;

  printf($stream "(* define force field *)\n\n");
  printf($stream "field\t\t= {\n");
  foreach (sort(keys(%{$fields->{fields}}))) {
    my $ptr = $fields->{fields}->{$_};

    my $id = $ptr->{id};
    my $name = $ptr->{name};
    my $mode = $ptr->{type};
    my $location = $ptr->{location};
    my $ilocation = $ptr->{ilocation} ? $ptr->{ilocation} : "";

    my $pre = "location$ilocation+field".($i ? $i : "");
    my $style = $ptr->{style} ne "" ? $ptr->{style} :
		$none ? (++$i<$n ? "template" : "none") : "template";

    $none = 0 if ($style eq "none");
    printf($stream "  {\n") if ($n>1);
    printf($stream "%s,\n",
      format_output(0, "id $id", $pos, 2));
    printf($stream "%s,\n",
      format_output(0, "mode $mode", $pos, 2));
    if ($fields->{field}->{type} eq "get") {
      printf($stream "%s\n",
	format_output(0, "name $pre+\"$name.field\"", $pos, 2));
    } elsif ($fields->{field}->{type} eq "cff") {
      printf($stream "%s,\n", 
	format_output(0, "name {$pre+\".frc\", ".
	  "$pre+\"_templates.dat\"}", $pos, 2));
    } elsif (
#	-f EMC::IO::expand("$global->{root}/field/$name.top") ||
	-f EMC::IO::expand($location ne "" ? "$location/" : "")."$name.top" #||
#	|| $global->{flag}->{rules}
      ) {
      printf($stream "%s,\n",
	format_output(0, "name {$pre+\".prm\", $pre+\".top\"}", $pos, 2));
    } else {
      printf($stream "%s,\n",
	format_output(0, "name $pre+\".prm\"", $pos, 2));
    }
    printf($stream "%s\n",
      format_output(0, "compress false", $pos, 2));
    printf($stream "  }%s\n", $i<$n ? "," : "") if ($n>1);
  }
  printf($stream "};\n\n");
}


sub write_field_apply {				# <= write_emc_field_apply
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $mode = shift(@_); $mode = "repulsive" if ($mode eq "");

  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $global = EMC::Common::element($emc, "root", "global");
  my $field = EMC::Common::element($emc, "root", "fields");
  my $field_flag = EMC::Common::element($field, "flag");
  my $field_flags = EMC::Common::element($field, "flags");

  my @types = (
    "angle", "torsion", "improper", "increment", "group", "debug", "error");
  my %debug = (
    full => 1, reduced => 1, false => 1);

  #printf($stream "(* apply force field *)\n\n");
  printf($stream "field\t\t= {\n");

  printf($stream "%s",
    format_output(1, "mode apply", 2, 2));
  printf($stream "%s\n",
    format_output(0, "check {", 2, 2));
  printf($stream "%s",
    format_output(1, "atomistic ".
      EMC::Math::boolean($field_flag->{check}), 4, 2));
  printf($stream "%s\n  }",
    format_output(0, "charge ".
      EMC::Math::boolean($field_flag->{charge}), 4, 2));
  foreach (@types) {
    if (($_ eq "debug" && defined($debug{$field_flag->{$_}})) ||
        (defined($field_flags->{$field_flag->{$_}}))) {
      printf($stream ",\n%s",
       	format_output(0, "$_ $field_flag->{$_}", 2, 2));
    }
  }
  printf($stream "\n");
  printf($stream "};\n\n");
  if ($field_flag->{debug} ne "false") {
    printf($stream "put\t\t= {name -> \"debug\"};\n\n");
  }
  $field_flags->{ncalls}++;
}


sub write_focus {				# <= write_emc_focus
  my $stream = shift(@_);
  my $emc = shift(@_);
  
  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $clusters = EMC::Common::element($emc, "clusters");
  my $global = EMC::Common::element($emc, "root", "global");

  return if (!$flag->{focus});

  my @focus = ();

  foreach (@{$context->{focus}}) {
    if ($_ eq "-") { next; }
    elsif (!defined($clusters->{cluster}->{$_})) {
      EMC::Message::warning("undefined focus cluster \'$_\'\n");
    }
    push(@focus, $_);
  }
  printf($stream "(* focus *)\n\n");
  if (scalar(@focus)==0) {
    printf($stream "focus\t\t= {};\n\n");
  }
  elsif (scalar(@focus)==1) {
    printf($stream "focus\t\t= {clusters -> @focus[0]};\n\n");
  }
  else {
    printf($stream "focus\t\t= {clusters -> {".join(", ", @focus)."}};\n\n");
  }
}


sub write_force {				# <= write_emc_force
  my $stream = shift(@_);
  my $emc = shift(@_);

  printf($stream "force\t\t= {style -> none, message -> nkt};\n");
  printf($stream "force\t\t= {style -> init, message -> nkt};\n\n");
}


sub write_select {
  my $select = shift(@_);

  EMC::Message::dumper("select = ", $select);
  EMC::Message::spot("select = ".EMC::Hash::string($select));
}


sub write_groups {				# <= write_emc_groups
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $type = shift(@_);

  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $groups = EMC::Common::element($emc, "groups");
  my $group = EMC::Common::element($emc, "groups", "group");
  my $polymer = EMC::Common::element($emc, "polymers", "polymer");
  my $global = EMC::Common::element($emc, "root", "global");

  my $ntypes = {
    graft =>  EMC::Common::element($groups, "context", "ngrafts"), 
    regular => EMC::Common::element($groups, "context", "nregulars"),
    select => EMC::Common::element($groups, "context", "nselects")};

  my $n = defined($type) ? $ntypes->{$type} : scalar(@{$groups->{index}});
  my $i = 0;

  return if (!$n);

  printf($stream "(* define %sgroups *)\n\n", defined($type) ? $type." " : "");
  printf($stream "groups\t\t= {\n");
  foreach (@{$groups->{index}}) {
    my $field;
    my $charges;
    my $name = $_;
    my $id = $group->{$name}->{id};
    my $terminator = $group->{$name}->{terminator};

    next if (defined($type) && !$group->{$name}->{flag}->{$type});
    printf($stream format_output(0, "group {", 2, 2));
    printf($stream "\n");
    if (!$group->{$name}->{polymer}) {
      my @fields = @{$group->{$name}->{field}};
      if (scalar(@fields)>1) { $field = "{".join(", ", @fields)."}"; }
      elsif (scalar(@fields)==1) { $field = "@fields[0]"; }
      $charges = $group->{$name}->{charges};
    }
    if ($group->{$name}->{polymer}) {
      if (!defined($polymer->{$name})) {
	EMC::Message::error("polymer $name is not defined\n");
      }
      my $poly = $polymer->{$name};
      my $options = $poly->{options};
      printf($stream format_output(1, "id $id", 4, 2));
      printf($stream format_output(1, "fraction $options->{fraction}, order -> ${$options}{order}, bias -> ${$options}{bias}", 4, 2));
      printf($stream format_output(1, "terminator true", 4, 2)) if ($terminator);
      printf($stream format_output(0, "polymers {", 4, 2));
      write_polymers($stream, $emc, "group", $name);
      printf($stream "\n    }\n  }%s", $i++<$n-1 ? ",\n" : "");
    } elsif ($group->{$name}->{nconnects}) {
      my $j = 0;
      my $connect = $group->{$name}->{connect};
      my $nconnects = $group->{$name}->{nconnects};
      
      printf($stream 
	format_output(1, 
	  "id $id, depth -> $context->{depth}, chemistry -> chem_$name", 4, 2));
      printf($stream
	format_output(1, "charges $charges", 4, 2)) if (defined($charges));
      printf($stream
	format_output(1, "field $field", 4, 2)) if (defined($field));
      printf($stream
	format_output(1, "terminator true", 4, 2)) if ($terminator);
      printf($stream 
	format_output(0, "connects {", 4, 2));

      printf($stream "\n");
      foreach (@{$group->{$name}->{connect}}) {
	my @connect = @{$_}; ++$j;
	my $k = scalar(@connect);
	--$nconnects;
	foreach (sort({$a->{name} cmp $b->{name}} @connect)) {
	  my $ptr = $_;
	  
	  if (defined($ptr->{select})) {
	      printf($stream 
		format_output($nconnects ? 1 : --$k ? 1 : 0, 
		  "{source \$end$j, selection -> {id -> $name, select -> ".
		  EMC::Hash::string($ptr->{select})."}}",
		  6, 2));
	  } else {
	    if ($ptr->{connect} =~ m/[0-9]/) {
	      printf($stream 
		format_output($nconnects ? 1 : --$k ? 1 : 0, 
		  "{source \$end$j, destination -> {$ptr->{name}, \$end".$ptr->{connect}."}}",
		  6, 2));
	    } else {
	      printf($stream 
		format_output($nconnects ? 1 : --$k ? 1 : 0, 
		  "{source \$end$j, element -> \"$ptr->{connect}\",".
		  "destination -> $ptr->{name}}", 6, 2));
	    }
	  }
	}
      }
      printf($stream "\n    }\n  }%s", $i++<$n-1 ? ",\n" : "");
    } else {
      printf($stream format_output(1, "id $id", 4, 2));
      printf($stream format_output(1, "depth $context->{depth}", 4, 2));
      #printf($stream format_output(1, "terminator true", 4, 2)) if ($terminator);
      printf($stream
	format_output(1, "charges $charges", 4, 2)) if (defined($charges));
      printf($stream
	format_output(1, "field $field", 4, 2)) if (defined($field));
      printf($stream format_output(0, "chemistry chem_$name", 4, 2));
      printf($stream "\n".format_output($i++<$n-1, "}", 2, 2));
    }
  }
  printf($stream "\n};\n\n");
}


sub write_header {				# <= write_emc_header
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $identity = EMC::Common::element($emc, "root", "global", "identity");
  my $date = EMC::Common::date_full();

  chop($date);
  #printf($stream "#!/usr/bin/env emc.sh\n");
  printf($stream "(* EMC: Script *)

(* Created by $identity->{script} v$identity->{version}, $identity->{date}
   on $date *)

");
}


sub write_import {				# <= write_emc_import
  my $stream = shift(@_);
  my $emc = shift(@_);

  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $clusters = EMC::Common::element($emc, "clusters");
  my $import = EMC::Common::element($clusters, "import");

  return if (!defined($import->{name}));

  my $global = EMC::Common::element($emc, "root", "global");
  my $id = $import->{name};
  my $field;

  if (scalar(@{$import->{field}})>1) {
    $field = ",\n\t\t   field -> {".join(", ", @{$import->{field}})."}";
  } elsif (scalar(@{$import->{field}})==1) {
    $field = ",\n\t\t   field -> @{$import->{field}}[0]";
  }
  if ($import->{charges}>=0) {
    $field .= ",\n\t\t   charges -> ".EMC::Math::boolean($import->{charges});
  }
  printf($stream "(* import file *)\n");
  printf($stream "\n");
  if ($import->{mode} eq "get" || 				# emc
      $import->{mode} eq "emc") {
    printf($stream "get\t\t= {name -> import$field};\n");
  } elsif ($import->{mode} eq "insight") {			# insight
    my $debug = $import->{debug} ? " debug -> true," : "";
    printf($stream 
      "insight\t\t= {id -> %s, name -> import, mode -> get,$debug\n\t\t   ".
      "depth -> $import->{depth}, crystal -> %s, percolate -> %s,\n\t\t   ".
      "formal -> %s, flag -> {charge -> %s}$field};\n",
      $id, EMC::Math::boolean($import->{crystal}),
      EMC::Math::boolean($import->{percolate}<0 ? $flag->{percolate} :
       	$import->{percolate}),
      EMC::Math::boolean($import->{formal}),
      EMC::Math::boolean($global->{system}->{charge})
    );
  } elsif ($import->{mode} eq "pdb") {				# pdb
    printf($stream 
      "pdb\t\t= {name -> import, mode -> get, detect -> true, ".
      "depth -> $import->{depth},\n");
    printf($stream 
      "\t\t   crystal -> %s, flag -> {charge -> %s}, map -> %s$field};\n",
      EMC::Math::boolean($import->{crystal}),
      EMC::Math::boolean($global->{system}->{charge}),
      EMC::Math::boolean($import->{map}));
  }
  if (defined($import->{tighten})) {				# tighten
    my $include = {structure => 1, tube => 1};

    if (defined($include->{$import->{type}})) {
      write_import_tighten($stream, $emc);
      printf($stream "focus\t\t= {mode -> middle, ntrials -> 1};\n");
    }
  }
  printf($stream "\n");

  write_variables($stream,
    "lxx geometry(id -> xx)",
    "lyy geometry(id -> yy)",
    "lzz geometry(id -> zz)",
    "lzy geometry(id -> zy)",
    "lzx geometry(id -> zx)",
    "lyx geometry(id -> yx)",
    "",
    "la lxx",
    "lb sqrt(lyx*lyx+lyy*lyy)",
    "lc sqrt(lzx*lzx+lzy*lzy+lzz*lzz)",
    "",
    "lbox vtotal()^(1/3)");
}


sub write_import_tighten {			# <= write_emc_tighten
  my $stream = shift(@_);
  my $emc = shift(@_);

  my $clusters = EMC::Common::element($emc, "clusters");
  my $import = EMC::Common::element($clusters, "import");
  my $global = EMC::Common::element($emc, "root", "global");
  
  my @geometry = ("infinite", "infinite", "infinite");
  my $value = $import->{tighten};
  my $flag = 1;
  
  $value = $clusters->{tighten} if ($value<0);
  if ($import->{type} eq "surface") {
    foreach (($global->{direction}->{x})) {
      @geometry[0] = $value if ($_ eq "x");
      @geometry[1] = $value if ($_ eq "y");
      @geometry[2] = $value if ($_ eq "z");
    }
  } elsif ($import->{type} eq "tube") {
    @geometry = ($value, $value, $value);
    foreach (($import->{direction})) {
      @geometry[0] = "infinite" if ($_ eq "x");
      @geometry[1] = "infinite" if ($_ eq "y");
      @geometry[2] = "infinite" if ($_ eq "z");
    }
  } elsif ($import->{type} eq "structure") {
    @geometry = ($value, $value, $value);
  } else {
    $flag = 0;
  }

  if ($flag) {
    printf($stream 
      "deform\t\t= {mode -> tighten, type -> absolute,\n".
      "\t\t   geometry -> {%s}};\n", join(", ", @geometry));
  }
}


sub write_import_variables {			# <= write_emc_import_variables
  my $stream = shift(@_);
  my $emc = shift(@_);

  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $groups = EMC::Common::element($emc, "groups");
  my $clusters = EMC::Common::element($emc, "clusters");
  my $cluster = EMC::Common::element($clusters, "cluster");
  my $import = EMC::Common::element($clusters, "import");
  my $import_nparallel = EMC::Common::element($clusters, "import_nparallel");
  my $global = EMC::Common::element($emc, "root", "global");
  my $deform = EMC::Common::element($global, "deform");
  my $direction = EMC::Common::element($global, "direction");

  return if (!defined($import->{name}));

  my $x = $direction->{x};
  my $y = $direction->{y};
  my $z = $direction->{z};
  my $nav = $global->{flag}->{reduced} ? "" : "/nav";
  my $ngrafts = $groups->{context}->{ngrafts};
  my @volume = ();
  my @variables = ();
  my $fauto = 0;
  my $bits = {nx => 1, ny => 2, nz => 4};

  foreach ("nx", "ny", "nz") {
    $fauto |= $bits->{$_} if ($import->{$_} eq "auto");
  }
  #if ($fauto && $ngrafts) {
  #  EMC::Message::error(
  #    "cannot automatically determine ncells for grafts\n");
  #}
  if ($import->{type} eq "crystal") {				# crystal

    if ($fauto && $ngrafts) {
    }
    push(@variables,
      $import->{ny} ne "auto" ?
	"n$y $import->{ny}" :
      $import_nparallel ? 
	"n$y $import_nparallel" : 
	"n$y n$x",
      $import->{nz} ne "auto" ?
	"n$z $import->{nz}" :
	"n$z n$x",
    );
    @volume = ("vtotal vtotal()");

  } elsif ($import->{type} eq "surface") {			# surface

    if (scalar(@{$context->{phases}})) {
      if ($fauto) {
	my $s = ""; foreach (@{$context->{phases}->[0]}) {
	  next if (EMC::Common::element($cluster, $_, "flag", "graft"));
	  $s .= "+" if ($s ne ""); $s .= "l_$_*n_$_";
	}
	push(@variables, "nphase1 ".($s ne "" ? "int($s+0.5)" : "0"));
	if ($import->{density} eq "number") {
	  $s = "nphase1";
	} else {
	  $s = ""; foreach (@{$context->{phases}->[0]}) {
	    next if (EMC::Common::element($cluster, $_, "flag", "graft"));
	    $s .= "+" if ($s ne ""); $s .= "m_$_*n_$_";
	  }
	}
	push(@variables, "mphase1 ".($s ne "" ? $s : "0"));
	push(@variables, "vphase1 mphase1$nav/density1");
      }
      push(@variables,
	$import->{ny} ne "auto" ?
	  "n$y $import->{ny}" :
	$import_nparallel ? 
	  "n$y $import_nparallel" : 
	  "n$y int((vphase1/fshape)^(1/3)/l$y$y+0.5)",
	$import->{nz} ne "auto" ?
	  "n$z $import->{nz}" :
	  "n$z int((vphase1/fshape)^(1/3)/l$z$z+0.5)",
	"n$y n$y ? n$y : 1",
	"n$z n$z ? n$z : 1");
    } else {
      push(@variables,
	"n$x $import->{nx}",
	"n$y $import->{ny}",
	"n$z $import->{nz}"
      );
      if ($import->{ny} eq "auto" || $import->{nz} eq "auto") {
	EMC::Message::error("cannot automatically determine n$y and/or n$z\n");
      }
    }
    if ($import->{exclude} eq "contour") {
      push(@volume,
	"vtotal vsites(ntrials -> $import->{ntrials})",
       	"l$x$x vtotal/lbox^2");
    } else {
      push(@volume,
       	"vtotal vtotal()");
    }

  } elsif ($import->{type} eq "tube") {				# tube

    if (scalar(@{$context->{phases}})) {
      if ($fauto) {
	my $s = ""; foreach (@{$context->{phases}->[0]}) {
	  next if (EMC::Common::element($cluster, $_, "flag", "graft"));
	  $s .= "+" if ($s ne ""); $s .= "l_$_*n_$_";
	}
	push(@variables, "nphase1 ".($s ne "" ? "int($s+0.5)" : "0"));
	if ($import->{density} eq "number") {
	  $s = "nphase1";
	} else {
	  $s = ""; foreach (@{$context->{phases}->[0]}) {
	    next if (EMC::Common::element($cluster, $_, "flag", "graft"));
	    $s .= "+" if ($s ne ""); $s .= "m_$_*n_$_";
	  }
	}
	push(@variables, "mphase1 ".($s ne "" ? $s : "0"));
	push(@variables, "vphase1 mphase1$nav/density1");
      }
      push(@variables,
	$import->{ny} ne "auto" ?
	  "n$y $import->{ny}" :
	$import_nparallel ? 
	  "n$y $import_nparallel" : 
	  "n$y int((vphase1/fshape)^(1/3)/l$y$y+0.5)",
	$import->{nz} ne "auto" ?
	  "n$z $import->{nz}" :
	  "n$z int((vphase1/fshape)^(1/3)/l$z$z+0.5)",
	"n$y n$y ? n$y : 1",
	"n$z n$z ? n$z : 1");
    } else {
      push(@variables,
	"n$x $import->{nx}",
	"n$y $import->{ny}",
	"n$z $import->{nz}"
      );
      if ($import->{ny} eq "auto" || $import->{nz} eq "auto") {
	EMC::Message::error("cannot automatically determine n$y and/or n$z\n");
      }
    }    
    push(@volume,
      "vtotal vsites(ntrials -> $import->{ntrials})");

    if (scalar(@{$context->{phases}})) {
      if ($import->{direction} eq $x) {
	EMC::Message::error("growth and import direction cannot be equal\n");
      }

      my $idx = {x => 0, y => 1, z => 2};
      my $dir = $import->{direction};
      my $d = {x => "a", y => "b", z => "c"}->{$dir};
      my $adapt = {
	x => ["lxx lxx*l$d/la", "la l$d"],
	y => ["lyx lyx*l$d/lb", "lyy lyy*l$d/lb", "lb l$d"],
	z => ["lzx lzx*l$d/lc", "lzy lzy*l$d/lc", "lzz lzz*l$d/lc", "lc l$d"]
      };
      my $options = {
	x => {y => $adapt->{z}, z => $adapt->{y}},
	y => {x => $adapt->{z}, z => $adapt->{x}},
	z => {x => $adapt->{y}, y => $adapt->{x}}};
	
      push(@volume,
       	@{$options->{$x}->{$dir}},
       	"lbox sqrt(l$y$y*l$z$z)"
      );

    }

  } elsif ($import->{type} eq "structure") {			# structure

    push(@variables,
      $import->{ny} ne "auto" ?
	"n$y $import->{ny}" :
      $import_nparallel ? 
	"n$y $import_nparallel" : 
	"n$y n$x",
      $import->{nz} ne "auto" ?
	"n$z $import->{nz}" :
	"n$z n$x");
    push(@volume,
      "vtotal vsites(ntrials -> $import->{ntrials})");

  } elsif ($import->{type} eq "system") {			# system

    push(@variables,
      $import->{ny} ne "auto" ?
	"n$y $import->{ny}" :
      $import_nparallel ? 
	"n$y $import_nparallel" : 
	"n$y n$x",
      $import->{nz} ne "auto" ?
	"n$z $import->{nz}" :
	"n$z n$x");
    push(@volume,
      "vtotal vtotal()");
    
  } else {
    EMC::Message::error("unexpected error while calling import type\n");
  }

  printf($stream "(* import sizing *)\n\n");
  write_variables($stream, @variables);
  
  my @flags = ();
  my $flag = $import->{flag};
  my %index = (x => 0, y => 1, z => 2);
  my @periodic = ("true", "true", "true");
  if ($import->{type} eq "surface") {
    @periodic[$index{$x}] = "false";
  } elsif ($import->{type} eq "tube") {
    @periodic = ("false", "false", "false");
    @periodic[$index{$import->{direction}}] = "true";
  } elsif ($import->{type} eq "structure") {
    @periodic = ("false", "false", "false");
  } elsif ($import->{type} eq "system") {
    @periodic = ("true", "true", "true");
    $flag = "mobile";
  }
  {
    my $extra;
    my $include = {structure => 1, tube => 1};

    if (defined($import->{translate})) {
      my $d = $import->{translate};

      if ($d!=0) {
	$d = "($d)" if ($d =~ m/\+|\-/);
	$d = "{$d*lxx/la, 0, 0}" if ($direction->{x} eq "x");
	$d = "{$d*lyx/lb, $d*lyy/lb, 0}" if ($direction->{x} eq "y");
	$d = "{$d*lzx/lc, $d*lzy/lc, $d*lzz/lc}" if ($direction->{x} eq "z");
	$extra .= ",\n\t\t   translate -> $d";
      }
    }
    $extra .= ",\n\t\t   " if ($import->{guess}>=0 || $import->{unwrap}>=0);
    $extra .= "guess -> ".EMC::Math::boolean($import->{guess}) if ($import->{guess}>=0);
    $extra .= ", " if ($import->{guess}>=0 && $import->{unwrap}>=0);
    $extra .= "unwrap -> ".EMC::Math::boolean($import->{unwrap}) if ($import->{unwrap}>=0);
    printf($stream 
      "crystal\t\t= {n -> {nx, ny, nz}, periodic -> {%s}%s};\n",
      join(", ", @periodic), $extra);

    if (!defined($include->{$import->{type}})) {
      if (defined($import->{tighten})) {			# tighten
	write_import_tighten($stream, $emc);
      }
      printf($stream "\n");
      write_variables($stream,
      	"lxx geometry(id -> xx)",
      	"lyy geometry(id -> yy)",
      	"lzz geometry(id -> zz)",
	"lxtal l$x$x",
	"lphase lxtal",
	"lbox sqrt(l$y$y*l$z$z)",
	"fshape lphase/lbox");

    } else {
      printf($stream "\n");
    }
  }
  push(@flags, $flag) if ($flag ne "mobile");
  push(@flags, "focus") if ($import->{focus});
  if (scalar(@flags)) {
    my $flags = join(", ", @flags);
    $flags = "{$flags}" if (scalar(@flags)>1);
    printf($stream "flag\t\t= {oper -> set, flag -> $flags};\n\n");
  }
  printf($stream "simulation	= {
  systems	-> {
    properties	-> {id -> 0, t -> temperature}
  }\n};\n\n");

  if ($deform->{flag}) {
    printf($stream 
"deform		= {
  mode		-> affine,
  type		-> $deform->{type},
  frequency	-> 1,
  geometry	-> {
    xx		-> $deform->{xx},
    yy		-> $deform->{yy},
    zz		-> $deform->{zz},
    zy		-> $deform->{zy},
    zx		-> $deform->{zx},
    yx		-> $deform->{yx}}
};

run		= {ncycles -> $deform->{ncycles}, nblocks -> $deform->{nblocks}};

force		= {style -> none, message -> raw};
force		= {style -> init, message -> raw};\n\n");
  }

  write_variables($stream, 
    "lxx geometry(id -> xx)",
    "lyy geometry(id -> yy)",
    "lzz geometry(id -> zz)",
    "lzy geometry(id -> zy)",
    "lzx geometry(id -> zx)",
    "lyx geometry(id -> yx)",
    "",
    "la lxx",
    "lb sqrt(lyx*lyx+lyy*lyy)",
    "lc sqrt(lzx*lzx+lzy*lzy+lzz*lzz)",
    "",
    "charge charge()",
    "ntotal ntotal()",
    "mtotal mtotal()",
    @volume,
    "nl_$import->{name} nclusters()");
}


sub write_interaction {				# <= write_emc_interaction
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $phase = shift(@_);
  my $mode = shift(@_); $mode = "repulsive" if ($mode eq "");
  
  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $build = EMC::Common::element($emc, "context", "build");
  my $import = EMC::Common::element($emc, "clusters", "import");
  my $global = EMC::Common::element($emc, "root", "global");
  my $field = EMC::Common::element($emc, "root", "fields", "field");
  my $field_flags = EMC::Common::element($emc, "root", "fields", "flags");

  my $field_exclude = $field->{type} eq "dpd" ||
	$field->{type} eq "colloid" ? 1 : 0;
  my $flag_import =
	$import->{exclude} eq "box" && defined($import->{name}) &&
	$import->{type} eq "surface" && $field_flags->{ncalls}>1 ? 1 : 0;
  my $flag_exclude = $global->{flag}->{exclude};
  my $flag = $flag_exclude==2 ?  ($flag_import ? 1 : ($phase>1 ? 2 : 0)) :
	     $flag_exclude==1 ? ($flag_import ? $phase<2 : 0) : 0;
  my $ptr = $build->{cluster};
  my $rmax = $global->{cutoff}->{rmax};

  return if ($field_exclude && !$flag && $flag_exclude!=2);
  
  printf($stream "types\t\t= {\n");
  printf($stream "%s\n", format_output(0, "inverse {", 2, 2));
  printf($stream "%s\n", format_output(0, "cutoff $field->{inverse}", 4, 2));
  printf($stream "%s", format_output(1, "}", 2, 2));
  if (!$field_exclude) {
    printf($stream "%s\n", format_output(0, "$field->{type} {", 2, 2));
    if ($global->{cutoff}->{inner}>0) {
      printf($stream "%s\n", 
	format_output(0, "pair {active -> true, mode -> $mode, ", 4, 2));
      printf($stream "%s\n", 
	format_output(0, "inner inner_cutoff, cutoff -> cutoff}", 20, 2));
    } elsif ($global->{core}>=0) {
      printf($stream "%s\n", 
	format_output(0, "pair {active -> true, mode -> $mode, ", 4, 2));
      printf($stream "%s\n", 
	format_output(0, "core core, cutoff -> cutoff}", 20, 2));
    } else {
      printf($stream "%s\n",
	$mode eq "repulsive" ?
	$rmax<=0 ?
	format_output(0, "pair {active -> true, mode -> $mode}", 4, 2) :
	format_output(0, "pair {active -> true, mode -> $mode, rmax -> $rmax}", 4, 2) :
	format_output(0, "pair {active -> true, mode -> $mode, cutoff -> cutoff}", 4, 2));
    }
    printf($stream "%s", format_output(0, "}", 2, 2));
  }
  if ($flag_exclude==2) {
    printf($stream ",\n") if (!$field_exclude);
    write_region($stream, $emc, $phase>1, $phase<$context->{nphases});
  } elsif ($flag) {
    printf($stream ",\n") if (!$field_exclude);
    write_region($stream, $emc, 1, 0) if ($phase<2);
  } else {
    printf($stream "\n");
  }
  printf($stream "};\n\n");
}


sub write_moves {				# <= write_emc_moves
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $phase = shift(@_);
  my $mode = shift(@_);

  my $moves = EMC::Common::element($emc, "context", "moves");
  my @keys = sort(keys(%{$moves}));
  my $active = [];
  my $options = {
    cluster => {
      function => \&write_moves_cluster,
      allowed => {
	both => 1, translate => 1, rotate => 1, false => 0, true => 1,
	none => 1, 0 => 0, 1 => 1
      }
    }
  };
  my $n = 0;

  foreach (@keys) {
    my $key = $_;

    next if (!defined($options->{$key}));
    foreach ($phase, 0) {
      my $move = $moves->{$key};
      my $ptr = $move->{phases}->[$_];
      next if (!defined($options->{$key}->{allowed}->{$ptr->{active}}));
      next if (!$options->{$key}->{allowed}->{$ptr->{active}});
      EMC::Common::array($move, "active")->[$phase] = 1;
      push(@{$active}, {move => $key, phase => $_});
      last;
    }
  }
  return if (!($n = scalar(@{$active})));

  my $i;

  printf($stream "moves\t\t= {\n");
  for ($i=0; $i<$n; ++$i) {
    my $ptr = $active->[$i];
    $options->{$ptr->{move}}->{function}->(
	$stream, $emc, $ptr->{phase}, $i<$n-1, $mode, @_);
  }
  printf($stream "};\n\n");
}


sub write_moves_cluster {			# <= write_emc_moves_cluster
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $phase = shift(@_);
  my $comma = shift(@_);
  my $mode = shift(@_);
  my $cluster = EMC::Common::element($emc, "context", "moves", "cluster");

  return if (ref($cluster->{phases}) ne "ARRAY");

  my $ptr = $cluster->{phases}->[$phase];
  my $limit = join(", ", split(":", $ptr->{limit}));
  my $max = join(", ", split(":", $ptr->{max}));
  my $min = join(", ", split(":", $ptr->{min}));

  if (defined({0 => 1, 1 => 1}->{$ptr->{active}})) {
    $ptr->{active} = EMC::Math::boolean($ptr->{active});
  }
  printf($stream "%s\n", format_output(0, "cluster {", 2, 2));
  if ($mode) {
    printf($stream "%s\n", format_output(0, "active false", 4, 2));
  } else {
    printf($stream "%s", format_output(1, "active ".$ptr->{active}, 4, 2));
    printf($stream "%s", format_output(1, "frequency $ptr->{frequency}", 4, 2));
    
    my $select = [];

    foreach ("clusters", "groups", "sites") {
      next if (!defined($ptr->{$_}));
      my $a = $ptr->{$_};
      if ($ptr->{$_} eq "all") {
	next if ($_ ne "clusters");
	$a = [create_clusters($emc, @_)];
      }
      push(@{$select}, format_output(0, "$_ {".join(", ", @{$a})."}", 6, 2));
    }
    if (scalar(@{$select})) {
      printf($stream "%s\n", format_output(0, "select {", 4, 2));
      printf($stream "%s\n", join(",\n", @{$select}));
      printf($stream "%s", format_output(1, "}", 4, 2));
    }
    printf($stream "%s", format_output(1, "cut $ptr->{cut}", 4, 2)); 
    printf($stream "%s", format_output(1, "min {$min}", 4, 2));
    printf($stream "%s", format_output(1, "max {$max}", 4, 2));
    printf($stream "%s\n", format_output(0, "limit {$limit}", 4, 2));
  }
  printf($stream "%s\n", format_output(0, "}", 2, 2), $comma ? "," : "");
}


sub write_phase {				# <= write_emc_phase
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $phase = shift(@_);
  my @clusters = @_;
  
  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $import = EMC::Common::element($emc, "clusters", "import");
  my $global = EMC::Common::element($emc, "root", "global");
  my $direction = EMC::Common::element($global, "direction");

  my $x = $direction->{x}.$direction->{x};
  my $y = $direction->{y}.$direction->{y};
  my $z = $direction->{z}.$direction->{z};
  my $mode = defined($import->{name}) ? 
	     $import->{type} eq "structure" ? ($phase<2 ? 2 : 1) : 
	     $import->{type} eq "tube" ? ($phase<2 ? 3 : 1) : 1 :
	     ($phase>1 ? 1 : 0);
  my $delete = $context->{delete}->{phases};
  my $fdelete = $phase ? defined($delete->[$phase]) ? 1 : 0 : 0;
  my $split = $context->{split}->{phases};
  my $fsplit = $phase ? defined($split->[$phase]) ? 1 : 0 : 0;
  my $fwall = $global->{flag}->{exclude}==2 ? $phase<$context->{nphases} : 0;

  printf($stream "(* clusters %s *)\n\n", $phase>0 ? "phase $phase" : "system");
  printf($stream "\n") if (write_user($stream, $emc, $phase, 0));
  write_clusters($stream, $emc, "regular", @clusters);
  write_field_apply($stream, $emc);
  printf($stream "\n") if (write_user($stream, $emc, $phase, 1));
  
  printf($stream "(* build %s *)\n\n", $phase>0 ? "phase $phase" : "system");
  
  my @variables = (
    "nphase$phase ntotal()-ntotal",
    "mphase$phase mtotal()-mtotal",
    "vphase$phase ".(
      $global->{flag}->{reduced} ?
      "nphase$phase/" : "mphase$phase/nav/")."density$phase"
  );

  if ($mode == 0) {					# first no import
    push(@variables, (
	"lbox (vphase$phase/fshape)^(1/3)",
	"lphase1 fshape*lbox",
	"lphase lphase1",
	"l$x lphase".($fwall ? "+lwall" : ""),
	"l$y lbox",
	"l$z lbox",
	"lzy 0",
	"lzx 0",
	"lyx 0",
	"ntotal nphase1",
	"mtotal mphase1",
	"vtotal vphase1"
      ));
  } elsif ($mode == 1) {				# surface and standard
    push(@variables, (
	"ntotal ntotal+nphase$phase",
	"mtotal mtotal+mphase$phase",
	"vtotal vtotal+vphase$phase",
	"lprevious lphase",
	"lphase$phase vphase$phase/lbox^2",
	"lphase l$x+lphase$phase",
	"l$x lphase".($fwall ? "+lwall" : "")
      ));
  } elsif ($mode == 2) {				# first structure
    push(@variables, (
	"ntotal ntotal+nphase1",
	"mtotal mtotal+mphase1",
	"vtotal vtotal+vphase1",
	"lbox (vtotal/fshape)^(1/3)",
	"lphase1 fshape*lbox",
	"lphase lphase1",
	"l$x lphase1",
	"l$y lbox",
	"l$z lbox"
      ));
  } elsif ($mode == 3) {				# first tube
    push(@variables, (
	"ntotal ntotal+nphase1",
	"mtotal mtotal+mphase1",
	"vtotal vtotal+vphase1",
	"lprevious lphase",
	"lphase1 vtotal/lbox/lbox",
	"lphase lphase1",
	"l$x lphase1"
      ));
  }
  write_variables($stream, @variables);
  write_interaction($stream, $emc, $phase);
  write_moves($stream, $emc, $phase, 0, @clusters);
  
  write_build($stream, $emc, $phase, @clusters);
  write_delete($stream, $emc, $phase) if ($fdelete);
  write_split($stream, $emc, $phase) if ($fsplit);
  write_moves($stream, $emc, $phase, 1);
  printf($stream "\n") if (write_user($stream, $emc, $phase, 2));

  return if ($flag->{test} || $flag->{exclude}->{build});
  write_force($stream, $emc);
  write_wall($stream, $emc, @clusters);
}


sub write_polymers {				# <= write_emc_polymers
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $typ = shift(@_);
  my $name = shift(@_);
  my $n = shift(@_);

  my $context = EMC::Common::element($emc, "context");
  my $import = EMC::Common::element($emc, "clusters", "import");
  my $polymer = EMC::Common::element($emc, "polymers", "polymer");
  my $polymer_flag = EMC::Common::element($emc, "polymers", "flag");
  my $global = EMC::Common::element($emc, "root", "global");
  my $direction = EMC::Common::element($global, "direction");

  my $poly = $polymer->{$name};
  my $npolys = scalar(@{$poly->{data}});
  my $flag = $npolys>1 ? 1 : 0;
  my %level = (cluster => 4, group => 8);
  my $ipoly = 0;
  my $options = $poly->{options};
  my $lvl;

  if (!defined($level{$typ})) {
    EMC::Message::error("unsupported polymer type '$typ'.\n");
  }
  $lvl = $level{$typ};
  foreach (@{$poly->{data}}) {
    my $i;
    my @g;
    my @w;
    my $mask = $_->{mask};
    my $fraction = $_->{fraction};
    my $nrepeats = join(", ", @{$_->{nrepeats}});
    my $groups = join(", ", create_groups(@{$_->{groups}}));
    my $weights = join(", ", create_groups(@{$_->{weights}}));
    my $type = $poly->{options}->{polymer};
    
    if ($typ eq "group") {
      printf($stream "\n") if ($ipoly<1);
      printf($stream "%s\n", format_output(0, "{", $lvl-2, 2));
      printf($stream "%s", format_output(1, "index ".$ipoly++, $lvl, 2));
      printf($stream "%s", format_output(1, "type $type", $lvl, 2));
      if (defined($options->{link})) {
	printf($stream "%s",
	  format_output(1, "link $options->{link}", $lvl, 2));
      }
      $mask = $type eq "random" ? 0 : 1 if (!defined($mask));
      $mask = EMC::Math::binary($mask);
      printf($stream "%s", format_output(1, "mask $mask", $lvl, 2));
      printf($stream "%s", format_output(1, "fraction $fraction", $lvl, 2));
      if (scalar(@{$options->{connects}})) {
	printf($stream "%s", 
	  format_output(1, "connects {".
	    join(",", @{$options->{connects}})."}", $lvl, 2));
      }
    } else {
      my $id = $name.($flag ? "_".++$ipoly : "");
      printf($stream "%s\n", format_output(0, "polymer {", $lvl-2, 2));
      printf($stream "%s",
	format_output(1, "id $id, system -> $global->{system}->{id}, type -> $type", $lvl, 2));
      printf($stream "%s",
       	format_output(1,
	  scalar(@{$poly->{data}})>1 ?
	    "n int($fraction*n_$name/norm_$name+0.5)" :
	    "n n_$name", $lvl, 2));
    }
    if ($polymer_flag->{niterations}>0) {
      printf($stream "%s",
	format_output(1, "niterations $polymer_flag->{niterations}", $lvl, 2));
    }
    printf($stream "%s", format_output(1, "groups {$groups}", $lvl, 2));
    printf($stream "%s", format_output(1, "weights {$weights}", $lvl, 2));
    printf($stream "%s", format_output(0, "nrepeat {$nrepeats}", $lvl, 2));
    printf($stream "\n%s", format_output(0, "}", $lvl-2, 2));
    printf($stream ",\n") if (--$npolys || $n);
  }
}


sub write_profile {				# <= write_emc_profile
  my $stream = shift(@_);
  my $emc = shift(@_);

  my $global = EMC::Common::element($emc, "root", "global");
  my $convert = EMC::Common::element($emc, "context", "convert");
  my $profiles = EMC::Common::element($global, "profiles");
  my $clusters = EMC::Common::element($emc, "clusters");
  my $cluster = EMC::Common::element($clusters, "cluster");
  my $polymers = EMC::Common::element($emc, "polymers");
  my $polymer = EMC::Common::element($polymers, "polymer");
  my $polymer_id = EMC::Common::element($polymers, "id");

  my @clusters;					# non-polymers through EMC
  foreach (@{$clusters->{index}}) {
    next if (EMC::Common::element($polymer, $_, "options", "group"));
    push(@clusters, $_) if (defined($polymer_id->{$_}));
  }
  my $n = scalar(@clusters);
  my $fcluster = 
	$n && EMC::Common::element($profiles, "flag", "flag") ? 1 : 0;

  $fcluster = 0 if (!$polymers->{flag}->{cluster});	# profiles through EMC
  @clusters = @{$clusters->{index}} if ($fcluster);
  $n = scalar(@clusters);

  return if (!($n || $fcluster));
  
  printf($stream "(* LAMMPS profile variables *)\n\n");
  printf($stream "variables\t= {\n");
  if (0 && defined($convert) && defined($convert->{type})) {
    my $itypes = scalar(keys(%{$convert->{type}}));
    if ($itypes) {
      foreach (sort(keys(%{$convert->{type}}))) {
	my $key = convert_key("type", $_);
	$_ =~ s/\*$/* /g;
	printf($stream 
	  format_output(--$itypes || $n, "type_".$key." type($_)+1", 2, 2));
      }
      printf($stream "\n") if ($n);
    }
  }
  foreach (@clusters) {				# nl_ written out by EMC C
    --$n if (!$fcluster);
    if ($cluster->{$_}->{type} eq "cluster") {
      printf($stream
	format_output($n, "nl_$_ nclusters(clusters -> $_)", 2, 2));
    } else {
      my $name = $_;
      my $poly = $polymer->{$name};
      my $npolys = scalar(@{$poly->{data}});
      my $ipoly = 0;
      my $flag = $npolys>1 ? 1 : 0;

      foreach (@{$poly->{data}}) {
	my $id = $name.($flag ? "_".++$ipoly : "");
	printf($stream "%s",
	  format_output(--$npolys || $n, 
	    "nl_$name ".($ipoly>1 ? "nl_$name+" : "").
	    "nclusters(clusters -> $id)", 2, 2)
	);
      }
    }
  }
  if ($fcluster) {
    printf($stream "\n");
    my $last = "";

    foreach (@{$clusters->{sampling}}) {
      printf($stream "%s",
	format_output(1, "n0_$_ $last"."1", 2, 2));
      printf($stream "%s",
	format_output(--$n, "n1_$_ n0_$_+nl_$_-1", 2, 2));
      $last = "n1_$_+";
    }
  }
  printf($stream "\n};\n\n");
};


sub write_region {				# <= write_emc_region
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $inner = shift(@_);
  my $outer = shift(@_);
  my $full = shift(@_);
  my @flag = ($inner, $outer);
  my $n = $inner+$outer;
  my $index = 0;

  my $region = EMC::Common::element($emc, "context", "region");
  my $direction = EMC::Common::element($emc, "root", "global", "direction");
  
  printf($stream "types\t\t= {\n") if ($full);
  printf($stream "%s\n", format_output(0, "region {", 2, 2));
  printf($stream "%s\n", format_output(0, "lj {active -> true, mode -> repulsive, ", 4, 2));
  printf($stream "%s\n", format_output(0, "data {", 6, 2));

  for (my $i=0; $i<2; ++$i) {
    next if (!@flag[$i]);

    my $l = $i ? "lwall" : "lprevious";
    my $hxx = $direction->{x} eq "x" ? $l : "infinite";
    my $hyy = $direction->{x} eq "y" ? $l : "infinite";
    my $hzz = $direction->{x} eq "z" ? $l : "infinite";

    printf($stream "%s\n", format_output(0, "{", 8, 2));
    printf($stream "%s\n", format_output(0, "index $index, epsilon -> $region->{epsilon}, sigma -> $region->{sigma}, ", 10, 2));
    printf($stream "%s", format_output(1, "region {shape -> cuboid, type -> absolute", 10, 2));
    printf($stream "%s", format_output(0, "h {$hxx, $hyy, $hzz}", 12, 2));
    if ($i==1) {
      my $x = $direction->{x};
      my $l = "0.5*l$x$x";
      my $cx = $x eq "x" ? $l : "0";
      my $cy = $x eq "y" ? $l : "0";
      my $cz = $x eq "z" ? $l : "0";

      printf($stream ",\n%s", format_output(0, "center {$cx, $cy, $cz}", 12, 2));
    }
    printf($stream "\n%s\n", format_output(0, "}", 10, 2));
    printf($stream "%s", format_output($i<$n-1, "}", 8, 2));
    ++$index;
  }
  printf($stream "\n%s\n", format_output(0, "}", 6, 2));
  printf($stream "%s\n", format_output(0, "}", 4, 2));
  printf($stream "%s\n", format_output(0, "}", 2, 2));
  printf($stream "};\n\n") if ($full);
}


sub write_run {					# <= write_emc_run
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $context = EMC::Common::element($emc, "context");

  return if ($context->{run}->{ncycles}<=0);

  my @moves = sort(keys(%{$context->{moves}}));
  my $nmoves = 0;

  foreach (@moves) {
    next if (!defined($context->{moves}->{$_}));
    next if (!EMC::Math::flag($context->{moves}->{$_}->{active}));
    ++$nmoves if ($context->{moves}->{$_}->{frequency}>0);
  }
  return if (!$nmoves);

  my $ntraject = $context->{ntraject} ?
		    $context->{ntraject} : $context->{nblocks};
  
  printf($stream "(* run conditions *)\n\n");
  printf($stream "simulation\t= {\n");
  printf($stream "%s\n", format_output(0, "moves {", 2, 2));

  my $i = 0; foreach(@moves) {
    next if (!defined($context->{moves}->{$_}));
    next if (!EMC::Math::flag($context->{moves}->{$_}->{active}));
    next if ($context->{moves}->{$_}->{frequency}<=0);
    printf($stream "%s\n",
      format_output(0, "$_ {", 4, 2));
    printf($stream "%s",
      format_output(1, "active true", 6, 2));
    printf($stream "%s\n",
      format_output(0, "frequency $context->{moves}->{$_}->{frequency}", 6, 2));
    printf($stream "%s",
      format_output(++$i<$nmoves, "}", 4, 2));
  }
  printf($stream "\n%s\n",
    format_output(0, "}", 2, 2));
  printf($stream "};\n\n");

  my %select;
  my $fselect = 0;

  foreach ("cluster", "group", "site") {
    my %hash;
    foreach (split(":", $context->{run}->{$_."s"})) {
      $hash{$_} = $_ if ($_ ne "all");
    }
    next if (!scalar(keys(%hash)));
    @{$select{$_}} = sort(keys(%hash));
    ++$fselect;
  }

  if ($fselect)
  {
    printf($stream "(* set selection *)\n\n");
    printf($stream "flag\t\t= {\n");
    printf($stream "%s", format_output(1, "oper set", 2, 2));
    printf($stream "%s", format_output(0, "flag fixed", 2, 2));
    printf($stream "\n};\n\n");

    my $count = $fselect;

    printf($stream "flag\t\t= {\n");
    printf($stream "%s", format_output(1, "oper unset", 2, 2));
    printf($stream "%s", format_output(1, "flag fixed", 2, 2));
    foreach (sort(keys(%select))) {
      if (scalar(@{$select{$_}})>1) {
	printf($stream "%s", format_output(--$count, "$_ {".join(", ", @{$select{$_}})."}", 2, 2));
      } else {
	printf($stream "%s", format_output(--$count, "$_ @{$select{$_}}[0]", 2, 2));
      }
    }
    printf($stream "\n};\n\n");
  }

  if ($context->{run}->{nequil}) {
    printf($stream "(* equilibrate *)\n\n");
    printf($stream "run\t\t= {\n");
    printf($stream "%s", format_output(1, "ncycles nequil", 2, 2));
    printf($stream "%s", format_output(0, "nblocks nblocks", 2, 2));
    printf($stream "\n};\n\n");
    write_force($stream, $emc);
  }
  
  printf($stream "(* run *)\n\n");
  if ($context->{traject}->{frequency}) {
    printf($stream "traject\t\t= {\n");
    printf($stream "%s", format_output(1, "mode put", 2, 2));
    printf($stream "%s", format_output(1, "frequency ntraject", 2, 2));
    printf($stream "%s", format_output(1, "name output", 2, 2));
    printf($stream "%s", format_output(0, "append ".
	EMC::Math::boolean(EMC::Math::flag($context->{traject}->{append})),
       	2, 2));
    printf($stream "\n};\n\n");
  }

  printf($stream "run\t\t= {\n");
  printf($stream "%s", format_output(1, "ncycles ncycles", 2, 2));
  printf($stream "%s", format_output(0, "nblocks nblocks", 2, 2));
  printf($stream "\n};\n\n");
  write_force($stream, $emc);

  if ($fselect) {
    printf($stream "(* unset selection *)\n\n");
    printf($stream "flag\t\t= {\n");
    printf($stream "%s", format_output(1, "oper unset", 2, 2));
    printf($stream "%s", format_output(0, "flag fixed", 2, 2));
    printf($stream "\n};\n\n");
  }
}


sub write_simulation {				# <= write_emc_simulation
  my $stream = shift(@_);
  my $emc = shift(@_);

  my $context = EMC::Common::element($emc, "context");
  my $global = EMC::Common::element($emc, "root", "global");
  my $flag = EMC::Common::element($global, "flag");
  my $field = EMC::Common::element($emc, "root", "fields", "field");

  printf($stream "(* define interactions *)\n\n");
  printf($stream "simulation\t= {\n");
  printf($stream "%s\n", format_output(0, "units {", 2, 2));
  if ($flag->{charge}) {
    printf($stream "%s",
      format_output(1, "permittivity $global->{dielectric}", 4, 2));
  }
  printf($stream "%s\n", format_output(0, "seed seed", 4, 2));
  
  if ($flag->{charge}) {
    printf($stream "%s\n", format_output(0, "},", 2, 2));
    printf($stream "%s\n", format_output(0, "types {", 2, 2));
    printf($stream "%s\n", format_output(0, "coulomb {", 4, 2));
    if ($field->{type} eq "dpd") {
      printf($stream "%s\n", format_output(0, "charge {active -> true, k -> kappa, cutoff -> charge_cutoff}", 6, 2));
    } else {
      printf($stream "%s\n", format_output(0, "pair {active -> true, cutoff -> charge_cutoff}", 6, 2));
    }
    printf($stream "%s\n", format_output(0, "}", 4, 2));
  }  
  printf($stream "%s\n", format_output(0, "}", 2, 2));
  printf($stream "};\n\n");
}


sub write_split {				# <= write_emc_split
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $phase = shift(@_);

  my $context = EMC::Common::element($emc, "context");
  my $global = EMC::Common::element($emc, "root", "global");

  my $direction = $global->{direction}->{x};
  my @clusters = $phase ? create_clusters($emc, @{$context->{phases}->[$phase-1]}) : ();
  my $split = $context->{split}->{phases};
  my $unwrap = 1;

  my $hash = $split->[$phase];
  my @focus = ();
  my $thickness = $hash->{thickness};
  my @center = (
    $direction eq "x" ? "0.5" : "0.0",
    $direction eq "y" ? "0.5" : "0.0",
    $direction eq "z" ? "0.5" : "0.0"
  );
  my @h = (
    $direction eq "x" ? $thickness : "infinite",
    $direction eq "y" ? $thickness : "infinite",
    $direction eq "z" ? $thickness : "infinite",
    "0.0", "0.0", "0.0"
  );

  if ($hash->{type} eq "absolute") {
    if ($direction eq "x") {
      @center = ("0.5*lxx", "0.0", "0.0");
    } elsif ($direction eq "y") {
      @center = ("0.5*lyx", "0.5*lyy", "0.0");
    } elsif ($direction eq "z") {
      @center = ("0.5*lzx", "0.5*lzy", "0.5*lzz");
    }
  }
  
  printf($stream "split\t\t= {\n");
  printf($stream format_output(1, "system ".$global->{system}->{id}, 2, 2));
  printf($stream format_output(1, "direction ".$direction, 2, 2));
  printf($stream format_output(1, "mode ".$hash->{mode}, 2, 2));
  printf($stream format_output(1, "unwrap ".EMC::Math::boolean($unwrap), 2, 2));
  printf($stream format_output(1, "fraction ".$hash->{fraction}, 2, 2));
  $unwrap = 0;
  
  foreach ("sites", "groups", "clusters") {
    if ($hash->{$_} ne "all") {
      push(@focus, {$_ => $hash->{$_}});
    } elsif ($_ eq "clusters") {
      push(@focus, {$_ => \@clusters}) if (scalar(@clusters));
    }
  }
  if (scalar(@focus)) {
    my $i;
    my $n = scalar(@focus)-1;

    printf($stream format_output(0, "focus {", 2, 2));
    printf($stream "\n");
    for ($i=0; $i<=$n; ++$i) {
      my $select = @focus[$i];
      my $key = (keys(%{$select}))[0];

      printf($stream format_output($i<$n, "$key {".join(", ", @{$select->{$key}})."}", 4, 2));
      printf($stream "\n") if ($i==$n);
    }
    printf($stream format_output(1, "}", 2, 2));
  }
  printf($stream format_output(0, "region {", 2, 2));
  printf($stream "\n");
  printf($stream format_output(1, "shape cuboid", 4, 2));
  printf($stream format_output(1, "type ".$hash->{type}, 4, 2));
  printf($stream format_output(1, "center {".join(", ", @center)."}", 4, 2));
  printf($stream format_output(0, "h {".join(", ", @h)."}", 4, 2));
  printf($stream "\n");
  printf($stream format_output(0, "}", 2, 2));
  printf($stream "\n};\n\n");
}


sub write_store {				# <= write_emc_store
  my $stream = shift(@_);
  my $emc = shift(@_);

  my $flag = EMC::Common::element($emc, "flag");
  my $context = EMC::Common::element($emc, "context");
  my $insight = EMC::Common::element($emc, "flag", "insight");
  my $global = EMC::Common::element($emc, "root", "global");
  my $field = EMC::Common::element($emc, "root", "fields", "field");

  printf($stream "(* storage *)\n\n");

  #if ($global->{flag}->{charge}) {			# done by EMC params
  #  write_variables($stream, "flag_charged charged()");
  #}
  
  if (!$flag->{test}) {
    printf($stream "put\t\t= {name -> output, compress -> true};\n");
  }

  EMC::Options::write($stream, EMC::Common::element($emc, "root"), "emc");

  if (!$flag->{test}) {
    if ($insight->{write}&&!$flag->{exclude}->{build}) {
      printf($stream "insight\t\t= {name -> output, ");
      printf($stream "compress -> ".EMC::Math::boolean($insight->{compress}).", ");
      printf($stream "forcefield -> $field->{type},\n");
      printf($stream "\t\t   unwrap -> ".EMC::Math::boolean($insight->{unwrap}).", ");
      printf($stream "pbc -> ".EMC::Math::boolean($insight->{pbc}));
      printf($stream "};\n\n");
    }
  }

  if ($context->{export}->{smiles} ne "") {
    printf($stream 
"export		= {
  smiles	-> {name -> output+\"_smiles\", compress -> true, style -> $context->{export}->{smiles}}
};
");
  }
}


sub write_variables {				# <= write_emc_variables
  my $stream = shift(@_);
  my @variables = @_;
  my $n = scalar(@variables);
  my $i;

  while (scalar(@variables) && @variables[-1] eq "") {
    pop(@variables); --$n;
  }
  return if (!scalar(@variables));
  printf($stream "variables\t= {\n");
  for ($i = 0; $i<$n; ++$i) {
    printf($stream "%s", format_output($i<$n-1, $variables[$i], 2, 2));
  }
  printf($stream "\n};\n\n");
}


sub write_variables_header {			# <= write_emc_variables_header
  my $stream = shift(@_);
  my $emc = shift(@_);

  my $context = EMC::Common::element($emc, "context");
  my $clusters = EMC::Common::element($emc, "clusters");
  my $groups = EMC::Common::element($emc, "groups");
  my $variables = EMC::Common::element($emc, "variables", "variable");
  my $build = EMC::Common::element($emc, "context", "build");
  my $global = EMC::Common::element($emc, "root", "global");
  my $field = EMC::Common::element($emc, "root", "fields");
  my $fields = EMC::Common::element($field, "fields");
  my $field_list = EMC::Common::element($field, "list");

  my @fields_collection;
  my @locations;
  my %id = ();
  my $i = 0;
  my @flag;
  
  foreach (sort(keys(%{$fields}))) {
    my $field = $fields->{$_};
    my $s = $field->{location};
    my $i = $field->{ilocation};
    next if (@flag[$i]);
    my $location = substr($s,0,1) eq "\$" ? $s :
		   substr($s,-1,1) eq "/" ? "\"$s\"" : "\"$s/\"";
    push(@locations, "location".($i ? $i : "")." $location");
    @flag[$i] = 1;
  }
  foreach (@{$field_list->{name}}) {
    $id{$field_list->{id}->{$_}} = $_;
  }
  foreach (sort(keys(%id))) {
    push(@fields_collection, "field".($i ? $i : "")." \"$fields->{$_}->{name}\""); ++$i;
  }
  my @variables = (
    "seed $global->{seed}",
    "ntotal $global->{ntotal}",
    "fshape $global->{shape}",
    "output \"$global->{project}->{name}\"",
    @fields_collection, @locations,
    "",
    "nav $global->{nav}",
    "temperature $global->{temperature}",
    "radius $build->{radius}",
    "nrelax $build->{nrelax}",
    "weight_nonbond $build->{weight}->{nonbond}",
    "weight_bond $build->{weight}->{bond}",
    "weight_focus $build->{weight}->{focus}",
    "cutoff $global->{cutoff}->{pair}"
  );
  my $i;
 
  printf($stream "(* define variables *)\n\n");
  push(@variables, "lwall $global->{wall}") if ($global->{flag}->{exclude}==2);
  push(@variables, "core $global->{core}") if ($global->{core}>=0);
  push(@variables, "inner_cutoff $global->{cutoff}->{inner}") if ($global->{cutoff}->{inner}>=0);
  push(@variables, "charge_cutoff $global->{cutoff}->{charge}") if ($global->{flag}->{charge});
  push(@variables, "kappa $global->{kappa}") if ($global->{flag}->{charge});
  if ($context->{run}->{ncycles}) {
    push(@variables, "");
    my $ptr = $context->{run};
    foreach ("nblocks", "nequil", "ncycles") {
      next if ($_ eq "flag");
      push(@variables, "$_ ${$ptr}{$_}") if (${$ptr}{$_});
    }
    $ptr = $context->{traject};
    push(@variables, "ntraject ${$ptr}{frequency}") if (${$ptr}{frequency});
  }
  if (defined($clusters->{import}->{name})) {
    push(@variables, "");
    push(@variables, "import $clusters->{import}->{filename}");
    push(@variables, "n$global->{direction}->{x} $clusters->{import}->{nx}");
  }
  if ($context->{nphases}) {
    push(@variables, "");
    for ($i = 1; $i<=$context->{nphases}; ++$i) { 
      push(@variables, "density$i $global->{densities}->[$i-1]");
    }
    push(@variables,
      "lprevious 0",
      "lphase 0"
    );
  }
  if ($global->{flag}->{omit}) {
    EMC::Message::info("omitting chemistry file fractions\n");
  }
  elsif (scalar(@{$clusters->{index}})) {		# set fractions
    $i = 0;
    push(@variables, "");
    foreach (@{$clusters->{index}}) {
      push(@variables, "f_$_ $clusters->{cluster}->{$_}->{fraction}");
    }
  }
  if (scalar(@{$groups->{index}})) {			# set chemistries
    my $group = $groups->{group};
    push(@variables, "");
    foreach (@{$groups->{index}}) {
      next if (!defined($group->{$_}->{chemistry}));
      push(@variables, "chem_$_ \"".$group->{$_}->{chemistry}."\"");
    }
  }
  if (defined($variables->{data})) {
    my @vars;
    foreach (@{$variables->{data}}) {
      my @a = @{$_};
      my $var = shift(@a);
      push(@vars, "$var ".join(", ", @a));
      foreach (@variables) {
	my @b = split(" ");
	next if ($global->{flag}->{expert});
	EMC::Message::error(
	  "cannot redefine existing variable @b[0]\n") if ($var eq @b[0]);
      }
    }
    if ($variables->{type} == 0) {
      unshift(@variables, @vars, "");
    } else {     
      push(@variables, "", @vars);
    }
  }
  write_variables($stream, @variables);

  #return;

  # bypassed: influences importing of multiple field entries
  # happens when moe than one command appears before importing fields

  my $i = 0;
  my $n = scalar(keys(%{$emc->{flag}->{output}}));

  printf($stream "output\t\t= {\n");
  foreach (sort(keys(%{$emc->{flag}->{output}}))) {
    if ($_ eq "flag") {
      --$n; next
    }
    my $option = "$_ ".EMC::Math::boolean($emc->{flag}->{output}->{$_});
    printf($stream "%s", format_output(++$i<$n, $option, 2, 2));
  }
  printf($stream "\n};\n\n");
}


#
# HERE: integrate routines from here on
#

sub write_variables_polymer {			# <= write_emc_variables_polymer
  my $var = shift(@_);
  my $poly = shift(@_);
  my $cluster = shift(@_);
  my $name = shift(@_);
  my $t = shift(@_);
  my $int = shift(@_);
  my $skip = shift(@_);
  my $i = shift(@_);
  my $expert = shift(@_);

  if (ref($poly) ne "HASH") {
    EMC::Message::error("missing polymer definition for cluster '$name'\n")
  }
  my $data = $poly->{data};
  my $npolys = scalar(@{$data});

  if (EMC::Common::element($poly, "options", "group") ? 1 :
      scalar(@{$data})>1 ? 0 :				# regular clusters
      scalar(@{$data->[0]->{groups}})>1 ? 0 :
      $data->[0]->{nrepeats}->[0]>1 ? 0 : 
      scalar(split(":", $data->[0]->{groups}->[0]))>1 ? 0 : 1
    ) {
    return if ($int);
    push(@{$var}, $t."_$name ".$t."g_$data->[0]->{groups}->[0]");
  } else {
    my $f = 1;
    if (scalar(@{$data})>1) {				# polymers
      my $norm = ""; $f = 0;
      push(@{$var}, "") if ($i);
      if (!$int) {
	foreach (@{$data}) {
	  $norm .= ($norm eq "" ? "" : "+").
		   ($int ? "int($_->{fraction}*n_$name)" : $_->{fraction});
	}
	push(@{$var}, "norm_$name $norm") if (!$int);
	push(@{$var}, "norm $norm") if ($int);
	push(@{$var}, "");
      }
      push(@{$var}, $t."_$name 0") if ($npolys>1);
    }
    foreach (@{$data}) {
      my $fraction = $_->{fraction};
      my @n = @{$_->{nrepeats}};
      my @groups = @{$_->{groups}};
      my @weights = @{$_->{weights}};
      my $result;
      $i = -1;
      if (!$skip) {
	foreach (@groups) {
	  my $m = $n[++$i];
	  next if ($expert ? 0 : !$m);
	  my $v;
	  my @g = split(":", $_);
	  my @w = split(":", @weights[$i]);
	  if (scalar(@g)>1) {
	    my @a;
	    my $s;
	    my $i = 0;
	    my $fnumber = 1;
	    foreach (@w) { 
	      if (EMC::Math::number_q($_)) {
	       	$_ = eval($_);
	      } else {
	       	$fnumber = 0;
	      }
	    }
	    foreach (@w) {
	      my $u = $_;
	      if ($fnumber) { $s += $u; } else {
		if ($u =~ /\+/ || $u =~ /\-/) { $u = "($u)"; }
		$s .= $s eq "" ? $u : "+$u";
	      }
	    }
	    $s = 1.0 if ($fnumber && !$s);
	    foreach (@g) {
	      my $u = @w[$i++];
	      if (!EMC::Math::number_q($u) && 
		  ($u =~ /\+/ || $u =~ /\-/)) { $u = "($u)"; }
	      push(@a, $u."*".$t."g_$_");
	    }
	    $v = "(".join("+", @a).")";
	    $v .= "/($s)" if (!$fnumber);
	    $v .= "/$s" if ($fnumber && $s!=1);
	  } else {
	    $v = $t."g_$_";
	  }
	  $result .= ($result eq "" ? "" : "+").(
	    $expert ? "$m*" : $m>1 ? "$m*" : "").$v;
	}
	next if ($result eq "");
      }
      push(@{$var}, $t."_$name ".
	($npolys>1 ? $t."_$name+" : "").
	($f ? $result :
	  ($i>0 ? "($result)" : $result).
	  ($result eq "" ? "" : "*").
	  ($int ? "int($fraction*n_$name/norm_$name+0.5)" : "$fraction").
	  ($int ? "" : "/norm_$name")));
    }
  }
}


sub obtain_index {
  my $items = shift(@_);
  my $item = shift(@_);
  my $type = shift(@_);
  my $index = [];

  foreach (@{$items->{index}}) {
    next if (!EMC::Common::element($item, $_, "flag", $type));
    push(@{$index}, $_);
  }
  return $index;
}


sub write_variables_sizing {			# <= write_emc_variables_sizing
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $type = shift(@_);

  my $context = EMC::Common::element($emc, "context");
  my $clusters = EMC::Common::element($emc, "clusters");
  my $cluster = EMC::Common::element($emc, "clusters", "cluster");
  my $groups = EMC::Common::element($emc, "groups");
  my $group = EMC::Common::element($emc, "groups", "group");
  my $polymers = EMC::Common::element($emc, "polymers");
  my $polymer = EMC::Common::element($emc, "polymers", "polymer");
  my $global = EMC::Common::element($emc, "root", "global");
  my $flag = EMC::Common::element($clusters, "flag");

  my $expert = $global->{flag}->{expert};
  my $flag_import = EMC::Common::element($clusters, "import", "name") ? 1 : 0;
  
  my $flag_polymer = 0;
  my $index = {
    clusters => obtain_index($clusters, $cluster, $type),
    groups => obtain_index($groups, $group, $type)};
  my $nclusters = scalar(@{$index->{clusters}});
  my $ngroups = scalar(@{$index->{groups}});
  my %groups = ();
  my @variables;
  my $ntotal;
  my $mtotal;
  my $vtotal;
  my $i;
  my $s;
  my $n;

  foreach (@{$clusters->{index}}) {
    my $poly = $polymer->{$_};

    if (ref($poly) ne "HASH") {
      EMC::Message::error("missing polymer definition for cluster '$_'\n");
    }
    if (EMC::Common::element($poly, "options", "group") ? 0 :
        scalar(@{$poly->{data}})>1 ? 1 : 
        scalar(@{$poly->{data}->[0]->{nrepeats}})>1 ? 1 : 0) {
      $flag_polymer = 1;
    }
  }

  # lengths

  if ($ngroups||$nclusters) {
    push(@variables, "");
    push(@variables, "(* lengths *)\n");
    if ($ngroups) {
      foreach (@{$index->{groups}}) {
	push(@variables, "lg_$_ nsites($group->{$_}->{id})");
      }
    }
    if ($nclusters) {
      $i = 0;
      push(@variables, "");
      foreach (@{$index->{clusters}}) {
	write_variables_polymer(
	  \@variables, $polymer->{$_}, $cluster, $_, "l", 0, 0, $i++, $expert);
      }
    }
  }

  # masses

  if ($flag->{mol}||$flag->{mass}||$flag->{number}||$flag->{volume}) {
    if ($ngroups) {
      push(@variables, "");
      push(@variables, "(* masses *)\n");
      foreach (@{$index->{groups}}) {
	my $mass = $group->{$_}->{mass};
	push(@variables, "mg_$_ ".($mass eq "" ? "mass($group->{$_}->{id})" : $mass));
      }
    }
    if ($nclusters) {
      $i = 0;
      push(@variables, "");
      foreach (@{$index->{clusters}}) {
	if ($cluster->{$_}->{mass}) {
	  push(@variables, "m_$_ ".$cluster->{$_}->{mass});
	} else {
	  write_variables_polymer(
	    \@variables, $polymer->{$_}, $cluster, $_, "m", 0, 0, $i++, $expert);
	}
      }
    }
  }

  # volumes

  if ($flag->{volume} && $nclusters) {
    push(@variables, "");
    push(@variables, "(* volumes *)\n");
    $i = 0;
    foreach (@{$index->{clusters}}) {
      if (!$cluster->{$_}->{volume}) {
	my $script = $global->{script};
	EMC::Message::error(
	  "volume not set in $script->{name}$script->{extension} for \'$_\'\n");
      }
      push(@variables, "v_$_ $cluster->{$_}->{volume}");
    }
  }

  # fractions

  if ($nclusters && $type ne "graft") {
    push(@variables, "");
    if ($flag->{mol}) {					# mol fractions
      EMC::Message::info("assuming mol fractions\n");
      push(@variables, "(* mol fractions *)\n");
      foreach (@{$index->{clusters}}) {
	push(@variables, "f_$_ f_$_*l_$_");
      }
    }
    elsif ($flag->{mass}) {				# mass fractions
      EMC::Message::info("assuming mass fractions\n");
      push(@variables, "(* mass fractions *)\n");
      foreach (@{$index->{clusters}}) {
	push(@variables, "f_$_ m_$_ ? f_$_*l_$_/m_$_ : 0");
      }
    }
    elsif ($flag->{volume}) {				# volume fractions
      EMC::Message::info("assuming volume fractions\n");
      push(@variables, "(* volume fractions *)\n");
      foreach (@{$index->{clusters}}) {
	push(@variables, "f_$_ m_$_ ? f_$_*v_$_/m_$_ : 0");
      }
    }
  }

  # normalization

  if ($nclusters && !$flag->{number} && $type ne "graft")
  {
    $i = 0;
    $s = "";
    push(@variables, "");
    push(@variables, "(* normalization *)\n");
    foreach (@{$index->{clusters}}) {
      $s .= (($i++)>0 ? "+" : "")."f_".$_;
    }
    push(@variables, "norm $s") if ($s ne "");
    push(@variables, "");
    foreach (@{$index->{clusters}}) {
      push(@variables, "f_$_ f_$_/norm");
    }
  }

  # determine nmols

  if ($nclusters) {
    push(@variables, "");
    push(@variables, "(* sizing *)\n");
    foreach (@{$index->{clusters}}) {
      if (defined($cluster->{$_}->{flag}->{graft})) {
	push(@variables, "n_$_ nclusters(clusters -> $_)");
      } elsif ($flag->{number}) {
	push(@variables, "n_$_ f_$_");
      } else {
	push(@variables, "n_$_ int(f_$_*ntotal/l_$_+0.5)");
      }
    }
  }

  # polymer rescale

  if ($flag_polymer && $nclusters && $type ne "graft") {
    $i = 0;
    push(@variables, "");
    foreach (@{$index->{clusters}}) {
      my $poly = $polymer->{$_};
      next if (scalar(@{$poly->{data}})>1 ? 0 : 1);
      write_variables_polymer(
	\@variables, $poly, $cluster, $_, "tmp_n", 1, 1, $i++, $expert);
      push(@variables, "n_$_ tmp_n_$_");
      write_variables_polymer(
	\@variables, $poly, $cluster, $_, "m", 1, 0, $i++, $expert);
      push(@variables, "m_$_ n_$_ ? m_$_/n_$_ : 0");
      write_variables_polymer(
	\@variables, $poly, $cluster, $_, "l", 1, 0, $i++, $expert);
      push(@variables, "l_$_ n_$_ ? l_$_/n_$_ : 0");
    }
  }

  if ($type ne "graft") {
    push(@variables, "");
    push(@variables, "(* system sizing *)\n");
    push(@variables, "ntotal 0");
    push(@variables, "mtotal 0");
    push(@variables, "vtotal 0");
  }

  # write variables

  if (scalar(@variables)) {
    printf($stream "(* determine simulation sizing *)\n\n");
    write_variables($stream, @variables);
  }
}


sub write_user {
  write_user_variables(@_);
  write_user_verbatim(@_);
}


sub write_user_variables {
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $phase = shift(@_); $phase = 0 if ($phase<0);
  my $sub = shift(@_);
  my $n = undef;

  my @ptr = (EMC::Common::element($emc, "variables", "item"));

  return if (!defined(@ptr[0]));
  foreach ($phase eq "0" ? ("default", "0") : ($phase)) {
    @ptr[1] = EMC::Common::element(@ptr[0], $_);
    next if (!defined(@ptr[1]));
    foreach ($sub eq "1" ? ("default", "1") : ($sub)) {
      @ptr[2] = EMC::Common::element(@ptr[1], $_);
      next if (!defined(@ptr[2]));
      write_variables($stream, @{@ptr[2]->{data}});
      $n += scalar(@{$ptr[2]->{data}});
    }
  }
  return $n;
}


sub write_user_verbatim {			# <= write_emc_verbatim
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $phase = shift(@_); $phase = 0 if ($phase<0);
  my $sub = shift(@_);
  my $n = undef;

  my @ptr = (EMC::Common::element($emc, "verbatim"));

  return if (!defined(@ptr[0]));
  foreach ($phase eq "1" ? ("default", "1") : ($phase)) {
    @ptr[1] = EMC::Common::element(@ptr[0], $_);
    next if (!defined(@ptr[1]));
    foreach ($sub eq "0" ? ("default", "0") : ($sub)) {
      @ptr[2] = EMC::Common::element(@ptr[1], $_);
      next if (!defined(@ptr[2]));
      foreach(@{@ptr[2]->{data}}) {
	printf($stream "%s\n", $_);
      }
      $n += scalar(@{$ptr[-1]->{data}});
    }
  }
  return $n;
}


sub write_wall {
  my $stream = shift(@_);
  my $emc = shift(@_);
  my $global = EMC::Common::element($emc, "root", "global");

  return if ($global->{flag}->{exclude}!=2);

  my @clusters = create_clusters($emc, @_);

  #printf($stream "(* wall exclusion *)\n\n");
  printf($stream
"flag		= {
  oper		-> set,
  flag		-> wall,
  cluster	-> {".join(", ", @clusters)."}
};

");
}


# EMC execute

sub execute {
  my $root = shift(@_);
  my $emc = EMC::Common::element($root, "emc");
  my $mflag = EMC::Message::get_flag();
  my $build = EMC::Common::element($emc, "context", "build");
  my $flag = EMC::Common::element($root, "emc", "flag");
  my $fenv = EMC::Common::element($root, "environment", "flag", "active");

  return if ($fenv || !EMC::Common::element($flag, "execute"));

  my $executable;

  if ($^O eq "MSWin32") {
    $executable = EMC::IO::scrub_dir(
      dirname($0)."/../bin/".$flag->{executable}.".exe");
  } else {
    $executable = (split("\n", `which $flag->{executable}`))[0];
  }
  EMC::Message::error(
    "cannot find '$flag->{executable}' in path\n") if (! -e $executable);
  EMC::Message::info("executing '$executable'\n\n");
  if ($^O eq "MSWin32") {
    system("$executable $build->{name}.emc");
  } elsif ($mflag->{info}) {
    system("$executable $build->{name}.emc 2>&1 | tee $build->{name}.out");
  } else {
    system("$executable $build->{name}.emc &> $build->{name}.out");
  }
  return 1;
}

