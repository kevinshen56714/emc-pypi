#!/usr/bin/env perl
#
#  module:	EMC::Fields.pm
#  author:	Pieter J. in 't Veld
#  date:	December 25, 2021, January 15, 2022, April 30,
#  		November 30, 2024.
#  purpose:	Field routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
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
#        indicator	BOOLEAN	include "field_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#    mass		see 'specific members' below
#    equivalence	see 'specific members' below
#    bond		see 'specific members' below
#    angle		see 'specific members' below
#    improper		see 'specific members' below
#    torsion		see 'specific members' below
#
#  specific members:
#    data		HASH	field data
#      type			data types
#	[type]
#	  [...]
#	    keyword1		data descriptors
#	    [keyword2]
#
#    define		HASH	options for define paragraph
#
#    flag		HASH
#      array		BOOLEAN	data as array of hashed in case of indexation
#      index		ARRAY	index descriptors
#      ntypes		INTEGER	number of types
#      table  		BOOLEAN	data contains a table
#
#    index		ARRAY
#      type1		STRING	type 1
#      [type2]		STRING	type 2
#      [...]			...
#      keyword1		STRING	constant 1 keyword
#      [keyword2]	STRING	constant 2 keyword
#      [...]
#
#  notes:
#    20211225	Inception of v1.0
#    20220115	Inclusion of commands, defaults, and functions
#    20240430	Inclusion of field selection
#    		Renaming from Field to Fields
#    20241130	Added assign_field() for setting field definitions
#    		Added item structure interpretors for bonded, define,
#    		references, and stream
#

package EMC::Fields;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use File::Basename;
use EMC::Common;
use EMC::Item;
use EMC::Mass;
use EMC::Message;
use EMC::Residues;
use EMC::Struct;
use EMCField;
use Cwd;


# defaults 

$EMC::Fields::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "April 30, 2024",
  version	=> "1.0"
};

$EMC::Fields::Guide = {
  index => [
    "header", "define", "references", "mass", "precedence", "rules",
    "templates", "equivalence", "increment", "nonbond", "bond", "angle",
    "torsion", "improper", "cmap"],
  order => {
    define => 1},
  table => {
    nonbond => 1, bond => 1, angle => 1, torsion => 1, improper => 1,
    cmap => 1},
  auto => {
    equivalence => 1, nonbond => 1, bond => 1, angle => 1, torsion => 1,
    improper => 1},
  ntypes => {
    define => 1, mass => 1, equivalence => 1, rules => 0, nonbond => 2,
    increment => 2, bond => 2, angle => 3, torsion => 4, improper => 4,
    cmap => 5, templates => 1, rules => 1}
};

$EMC::Fields::Options = {
  angle => {
    error => 1, ignore => 1, warn => 1},
  density => {
    "g/cc" => 1, "kg/m^3" => 1, "reduced" => 1},
  energy => {
    "j/mol" => 1, "kj/mol" => 1, "cal/mol" => 1, "kcal/mol" => 1,
    "kelvin" => 1, "reduced" => 1},
  length => {
    angstrom => 1, nanometer => 1, micrometer => 1, meter => 1,
    reduced => 1},
  mix => {
    none => 1, berthelot => 1, arithmetic => 1, geometric => 1,
    sixth_power => 1},
  fftype => {
    atomistic => 1, united => 1, coarse => 1},
  torsion => {
    error => 1, ignore => 1, warn => 1},
};

$EMC::Fields::masks = {
  dpd => {
    nonbond => [{method => "log"}, {method => "avg"}, {method => "avg"}],
    bond => [{method => "log"}, {method => "avg"}],
    angle => [{method => "log"}, {method => "avg"}],
    torsion => [{method => "log"}, {method => "avg"}],
    improper => [{method => "log"}, {method => "avg"}]
  }
};


# construct

sub construct {
  my $fields = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes({commands => 1}, @_);
 
  set_functions($fields, $attr);
  set_defaults($fields);
  if (EMC::Common::element($attr, "commands")) {
    set_commands($fields, undef, $attr);
  }
  return $fields;
}


# initialization

sub set_defaults {
  my $fields = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");
  my $root_dir = EMC::IO::emc_root();

  $fields = {} if (!defined($fields));
  
  $fields = EMC::Common::attributes(
    $fields,
    {
      # D
      
      define		=> {
	angle		=> "warn",
	density		=> "g/cc",
	energy		=> "kcal/mol",
	ffapply		=> "all",
	ffmode		=> "table",
	fftype		=> "coarse",
	length		=> "angstrom",
	nbonded		=> "1",
	torsion		=> "warn",
	version		=> "1.0"
      },

      # F

      field		=> {
	dpd		=> {auto => 0, bond => 0},
	flag		=> 0,
	"format"	=> "%15.10e",
	id		=> "opls-ua",
	inverse		=> 0.001,
	name		=> EMC::IO::scrub_dir("opls/2012/opls-ua"),
	type		=> "opls",
	location	=> EMC::IO::scrub_dir("$root_dir/field/"),
	verbatim	=> undef,
	write		=> 1
      },
      fields		=> undef,
      flag		=> {
	angle		=> 0,
	bond		=> 0,
	charge		=> 1,
	check		=> 1,
	debug		=> "false",
	emc		=> 0,
	error		=> 1,
	group		=> 0,
	improper	=> 0,
	increment	=> 0,
	nbonded		=> 0,
	special		=> 0,
	torsion		=> 0
      },
      flags		=> {
	complete	=> 1,
	empty		=> 1,
	error		=> 1,
	false		=> 1,
	first		=> 1,
	ignore		=> 1,
	reduced		=> 1,
	true		=> 1,
	"warn"		=> 1
      },

      # I

      identity		=> $EMC::Fields::Identity,

      # L

      list		=> {
	id		=> {},
	name		=> [],
	location	=> undef
      }
    }
  );
  $fields->{list}->{location} = $root->{global}->{location}->{field_list};
  
  return $fields;
}


sub assign_field {
  my $field = EMC::Common::hash(shift(@_));

  $field = EMC::Common::attributes(
    $field,
    {
      index => [
	"define",
	"references",
	"mass",
	"equivalence_auto",
	"equivalence",
	"increment",
	"nonbond",
	"bond",
	"angle_auto",
	"angle",
	"torsion_auto",
	"torsion",
	"improper_auto",
	"improper"
      ],
      define		=> {
	data		=> {
	  ANGLE		=> "ERROR",
	  CREATED	=> uc(EMC::Common::date_short()),
	  DENSITY	=> "G/CC",
	  ENERGY	=> "KCAL/MOL",
	  FFAPPLY	=> "ALL",
	  FFCHARGE	=> "ALL",
	  FFDEPTH	=> 4,
	  FFINDEX	=> "TYPES",
	  FFMODE	=> undef,
	  FFSTRICT	=> "TRUE",
	  FFTYPE	=> "ATOMISTIC",
	  LENGTH	=> "ANGSTROM",
	  MIX		=> "GEOMETRIC",
	  NBONDED	=> 3,
	  PAIR14	=> "INCLUDE",
	  RULE		=> "ERROR",
	  RULE_NARGS	=> 7,
	  SHAKE		=> "NONE",
	  TORSION	=> "ERROR",
	  VERSION	=> undef
	},
	flag		=> {
	  ntypes	=> 1
	},
	order		=> [
	  "FFMODE",
	  "FFTYPE",
	  "FFAPPLY",
	  "FFINDEX",
	  "FFDEPTH",
	  "FFCHARGE",
	  "FFSTRICT",
	  "VERSION",
	  "CREATED",
	  "LENGTH",
	  "ENERGY",
	  "DENSITY",
	  "MIX",
	  "RULE",
	  "RULE_NARGS",
	  "NBONDED",
	  "ANGLE",
	  "PAIR14",
	  "TORSION",
	  "SHAKE"
	]
      },
      references	=> {
	flag		=> {
	  ntypes	=> undef
	},
	index		=> [
	  "year",
	  "volume",
	  "page",
	  "journal",
	]
      },
      mass		=> {
	flag		=> {
	  ntypes	=> 1
	},
	index		=> [
	  "type",
	  "mass",
	  "element",
	  "ncons",
	  "charge",
	  "index",
	  "comment"
	]
      },
      equivalence	=> {
	flag		=> {
	  ntypes	=> 1
	},
	index		=> [
	  "type",
	  "pair",
	  "incr",
	  "bond",
	  "angle",
	  "torsion",
	  "improper"
	]
      },
      increment		=> {
	flag		=> {
	  ntypes	=> 2
	},
	index		=> [
	  "type1",
	  "type2",
	  "delta12",
	  "delta21"
	]
      },
      nonbond		=> {
	flag		=> {
	  ntypes	=> 2
	},
	index		=> [
	  "type1",
	  "type2",
	  "sigma",
	  "epsilon"
	]
      },
      bond		=> {
	flag		=> {
	  ntypes	=> 2
	},
	index		=> [
	  "type1",
	  "type2",
	  "k",
	  "l0"
	]
      },
      angle		=> {
	flag		=> {
	  ntypes	=> 3
	},
	index		=> [
	  "type1",
	  "type2",
	  "type3",
	  "k",
	  "theta0"
	]
      },
      torsion		=> {
	flag		=> {
	  ntypes	=> 4
	},
	index		=> [
	  "type1",
	  "type2",
	  "type3",
	  "type4",
	  "k",
	  "n",
	  "delta",
	  "[...]"
	]
      },
      improper		=> {
	flag		=> {
	  ntypes	=> 4
	},
	index		=> [
	  "type1",
	  "type2",
	  "type3",
	  "type4",
	  "k",
	  "psi0"
	]
      }
    }
  );
  foreach ("equivalence", "bond", "angle", "torsion", "improper") {
    $field->{$_."_auto"} = EMC::Element::deep_copy($field->{$_});
  }
  return $field;  
}


sub transfer {
  my $fields = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($fields, "flag");
  my $context = EMC::Common::element($fields, "context");
  
  EMC::Element::transfer(shift(@_),
    [\%::EMC::Field,			\$fields->{field}],
    [\@::EMC::Fields,			\$fields->{fields}],
    [\%::EMC::FieldFlag,		\$fields->{flag}],
    [\%::EMC::FieldFlags,		\$fields->{flags}],
    [\%::EMC::FieldList,		\$fields->{list}],
    [\$::EMC::Verbatim{field},		\$fields->{verbatim}]
  );
}


sub set_context {
  my $fields = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $flag = EMC::Common::element($global, "flag");
 
  # F

  EMC::Common::attributes($fields, {
    list => EMC::Common::hash($fields, "list")});
  EMC::Common::attributes($fields->{list}, {
    location => EMC::Common::array($fields->{list}, "location")});
  EMC::IO::path_prepend(
    $fields->{list}->{location}, ".");
  EMC::IO::path_append(
    $fields->{list}->{location}, 
    $global->{work_dir}."/chemistry/field", $global->{env}->{root}."/field");
  
  $fields->{field}->{name} = join(",", @{$fields->{list}->{name}});

  foreach (@{$fields->{list}->{name}}) {
    if ($fields->{field}->{type} eq "opls" && substr($_, -6) eq "opls-aa") {
      $flag->{atomistic} = 1;
    }
  }
}


sub set_commands {
  my $fields = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::element(shift(@_));
  my $attr = EMC::Common::attributes(@_);
  my $include = {
    emc => EMC::Common::element($attr, "emc"),
    special => EMC::Common::element($attr, "special")
  };
  my $flag = EMC::Common::element($fields, "flag");
  my $set = EMC::Common::element($fields, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
 
  if ($include->{special}) {
    $flag->{special} = 1;
    $indicator = $indicator ? "field_" : "";
    $fields->{commands} = EMC::Common::attributes(
      EMC::Common::hash($fields, "commands"),
      {
	$indicator."angle"	=> {
	  comment	=> "field error handling for angles",
	  default	=> $fields->{define}->{angle},
	  gui		=> ["option", "chemsitry", "field", "ignore"]
	},
	$indicator."energy"	=> {
	  comment	=> "field units of energy",
	  default	=> $fields->{define}->{energy},
	  gui		=> ["option", "chemsitry", "field", "ignore"]
	},
	$indicator."length"	=> {
	  comment	=> "field units of length",
	  default	=> $fields->{define}->{length},
	  gui		=> ["option", "chemsitry", "field", "ignore"]
	},
	$indicator."nbonded"	=> {
	  comment	=> "number of bonded sites",
	  default	=> $fields->{define}->{nbonded},
	  gui		=> ["option", "chemsitry", "field", "ignore"]
	},
	$indicator."torsion"	=> {
	  comment	=> "field error handling for torsions",
	  default	=> $fields->{define}->{torsion},
	  gui		=> ["option", "chemsitry", "field", "ignore"]
	},
	$indicator."version"	=> {
	  comment	=> "field version",
	  default	=> $fields->{define}->{version},
	  gui		=> ["option", "chemsitry", "field", "ignore"]
	}
      }
    );
  }

  if ($include->{emc}) {
    $flag->{emc} = 1;
    $fields->{commands} = EMC::Common::attributes(
      EMC::Common::hash($fields, "commands"),
      {
	# F

	field		=> {
	  comment	=> "set force field type and name based on root location",
	  default	=> "",
	  gui		=> ["list", "chemistry", "top", "standard", "born,basf,charmm,compass,dpd,gauss,martini,opls,pcff,sdk,trappe"]
	},
	field_angle	=> {
	  comment	=> "set angle field option (see below)",
	  default	=> "-",
	  gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]
	},
	field_bond	=> {
	  comment	=> "set bond field option (see below)",
	  default	=> "-",
	  gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]
	},
	field_charge	=> {
	  comment	=> "check system charge after applying force field ",
	  default	=> EMC::Math::boolean($fields->{flag}->{charge}),
	  gui		=> ["option", "chemistry", "field", "advanced"]
	},
	field_check	=> {
	  comment	=> "check force field compatibility",
	  default	=> EMC::Math::boolean($fields->{flag}->{check}),
	  gui		=> ["option", "chemistry", "field", "advanced"]
	},
	field_debug	=> {
	  comment	=> "set debug field option",
	  default	=> EMC::Math::boolean($fields->{flag}->{debug}),
	  gui		=> ["boolean", "chemistry", "field", "ignore", "general"]
	},
	field_dpd	=> {
	  comment	=> "set various DPD options",
	  default	=> EMC::Hash::text($fields->{field}->{dpd}, "boolean"),
	  gui		=> ["string", "chemistry", "field", "ignore", "general"]
	},
	field_error	=> {
	  comment	=> "override field errors (used for debugging)",
	  default	=> EMC::Math::boolean($fields->{flag}->{error}),
	  gui		=> ["boolean", "chemistry", "field", "ignore", "general"]
	},
	field_format	=> {
	  comment	=> "parameter format of generated force field ",
	  default	=> $fields->{field}->{format},
	  gui		=> ["string", "chemistry", "field", "advanced"]
	},
	field_group	=> {
	  comment	=> "set group field option (see below)",
	  default	=> "-",
	  gui		=> ["option", "chemistry", "field", "ignore", "complete,empty,ignore,error,warn"]
	},
	field_id	=> {
	  comment	=> "set force field id",
	  default	=> $fields->{field}->{id},
	  gui		=> ["string", "chemistry", "top", "advanced"]
	},
	field_improper	=> {
	  comment	=> "set improper field option (see below)",
	  default	=> "-",
	  gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]
	},
	field_increment	=> {
	  comment	=> "set increment field option (see below)",
	  default	=> "-",
	  gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]
	},
	field_inverse	=> {
	  comment	=> "set force field inverse cutoff",
	  default	=> $fields->{field}->{inverse},
	  gui		=> ["string", "chemistry", "top", "advanced"]
	},
	field_location	=> {
	  comment	=> "set force field location",
	  default	=> $fields->{field}->{location},
	  gui		=> ["string", "chemistry", "top", "advanced"]
	},
	field_name	=> {
	  comment	=> "set force field name",
	  default	=> $fields->{field}->{name},
	  gui		=> ["string", "chemistry", "top", "advanced"]
	},
	field_nbonded	=> {
	  comment	=> "set number of excluded bonded interactions",
	  default	=> $fields->{flag}->{nbonded},
	  gui		=> ["boolean", "chemistry", "field", "ignore", "general"]
	},
	field_reduced	=> {
	  comment	=> "set force field reduced units flag",
	  default	=> EMC::Math::boolean($flag->{reduced}),
	  gui		=> ["boolean", "chemistry", "top", "ignore"]
	},
	field_torsion	=> {
	  comment	=> "set torsion field option (see below)",
	  default	=> "-",
	  gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]
	},
	field_type	=> {
	  comment	=> "set force field type",
	  default	=> $fields->{field}->{type},
	  gui		=> ["string", "chemistry", "top", "ignore"]
	},
	field_write	=> {
	  comment	=> "create field parameter file",
	  default	=> EMC::Math::boolean($fields->{field}->{write}),
	  gui		=> ["boolean", "chemistry", "field", "ignore"]},

	# P

	params		=> {
	  comment	=> "create field parameter file",
	  default	=> EMC::Math::boolean($fields->{field}->{write}),
	  gui		=> ["boolean", "chemistry", "field", "ignore"]}
      }
    );
  }

  if (defined($fields->{commands})) {
    foreach (keys(%{$fields->{commands}})) {
      my $ptr = $fields->{commands}->{$_};
      $ptr->{set} = \&EMC::Fields::set_options if (!defined($ptr->{set}));
    }
  }

  EMC::Options::set_command(
    $fields->{items} = EMC::Common::attributes(
      EMC::Common::hash($fields, "items"),
      {
	# F

	field		=> {
	  chemistry	=> 1,
	  environment	=> 1,
	  order		=> 31,
	  set		=> \&set_item_field
	}
      }
    )
  );
  return $fields;
}


sub set_options {
  my $struct = shift(@_);

  my $option = EMC::Common::element($struct, "option");
  my $options = EMC::Common::element($struct, "options");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");

  my $fields = EMC::Common::element($struct, "module");
  my $define = EMC::Common::hash($fields, "define");
  my $flag = EMC::Common::element($fields, "flag");
  my $flags = EMC::Common::element($fields, "flags");
  my $list = EMC::Common::element($fields, "list");
  my $set = EMC::Common::element($fields, "set");
  
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $fields->{global} = \$root->{global};

  if ($flag->{special}) {
    $indicator = $indicator ? "field_" : "";
    if ($option eq $indicator."angle") {
      return $define->{angle} = EMC::Fields::set_select($struct); }
    if ($option eq $indicator."density") {
      return $define->{density} = EMC::Fields::set_select($struct); }
    if ($option eq $indicator."energy") {
      return $define->{energy} = EMC::Fields::set_select($struct); }
    if ($option eq $indicator."length") {
      return $define->{length} = EMC::Fields::set_select($struct); }
    if ($option eq $indicator."nbonded") {
      return $define->{nbonded} =
	  EMC::Math::bound(int(EMC::Math::eval($args->[0])->[0]), 0, 3); }
    if ($option eq $indicator."torsion") {
      return $define->{torsion} = EMC::Fields::set_select($struct); }
    if ($option eq $indicator."version") {
      return $define->{version} = $args->[0]; }
  }

  # F

  if ($flag->{emc}) {
    if ($option eq "field") {
      return set_field($fields, $line, $options->{warnings}, @{$args}); }
    if ($option eq "field_angle") {
      return set_flag($fields, "angle", $args->[0]); }
    if ($option eq "field_bond") { 
      return set_flag($fields, "bond", $args->[0]); }
    if ($option eq "field_charge") {
      return $flag->{charge} = EMC::Math::flag($args->[0]); }
    if ($option eq "field_check") {
      return $flag->{check} = EMC::Math::flag($args->[0]); }
    if ($option eq "field_dpd") {
      EMC::Hash::set($line, $fields->{field}->{dpd}, "boolean", "", [], @{$args});
      return 1;
    }
    if ($option eq "field_debug") {
      my $value = EMC::Math::eval($args);
      $flags->{debug} = 1;
      if ($args->[0] eq "0" || $args->[0] eq "false") { 
	$flags->{debug} = 0;
	$flag->{debug} = "false"; }
      elsif ($value->[0]==1 || $args->[0] eq "true" || $args->[0] eq "full") {
	$flag->{debug} = "full"; }
      elsif ($value->[0]==2 || $args->[0] eq "reduced") {
	$flag->{debug} = "reduced"; }
      else {
	EMC::Message::error_line($line, "illegal field_debug option\n"); }
      return 1;
    }
    if ($option eq "field_error") {
      return $flag->{error} = EMC::Math::flag($args->[0]) ? "true" : "false";
    }
    if ($option eq "field_format") {
      return $fields->{field}->{format} = $args->[0]; }
    if ($option eq "field_group") {
      return set_flag("group", $args->[0]); }
    if ($option eq "field_id" ) { 
      update_field($fields, $fields->{field}, "id", $args->[0]);
      update_fields($fields, $fields->{field});
      return 1;
    }
    if ($option eq "field_improper") {
      return set_flag($fields, "improper", $args->[0]); }
    if ($option eq "field_increment") {
      return set_flag($fields, "increment", $args->[0]); }
    if ($option eq "field_inverse") {
      my $value =  EMC::Math::eval($args->[0])->[0];
      return $fields->{field}->{inverse} = $value; }
    if ($option eq "field_location" ) {
      foreach (@{$args}) { $_ = EMC::IO::scrub_dir($_); }
      EMC::IO::path_prepend($list->{location}, reverse(@{$args}), ".");
      update_field($fields, $fields->{field}, "location", $args->[0]);
      return 1;
    }
    if ($option eq "field_name" ) {
      $list->{name} =
	[EMC::List::unique($line, @{$list->{name}}, @{$args})];
      update_field($fields, $fields->{field}, "name", $args->[0]);
      update_fields($fields, $fields->{field});
      return 1;
    }
    if ($option eq "field_nbonded") {
      my $value = EMC::Math::eval($args->[0])->[0];
      return $flag->{nbonded} = $value<0 ? 0 : int($value); }
    if ($option eq "field_reduced") {
      return $flag->{reduced} = EMC::Math::flag($args->[0]); }
    if ($option eq "field_torsion") {
      return set_flag($fields, "torsion", $args->[0]); }
    if ($option eq "field_type" ) {
      update_field($fields, $fields->{field}, "type", $args->[0]);
      update_fields($fields, $fields->{field});
      return $fields->{field}->{type};
    }
    if ($option eq "field_write") {
      reset_flags(); 
      return $fields->{field}->{write} = EMC::Math::flag($args->[0]);
    }
  }
  
  return undef;
}


sub set_select {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");

  if (defined($EMC::Fields::Options->{$option})) {
    if (defined($EMC::Fields::Options->{$option}->{$args->[0]})) {
      return $args->[0];
    }
    EMC::Message::error_line([$file, $line], "illegal argument '$args->[0]'");
  }
  EMC::Message::error_line([$file, $line], "illegal option '$option'");
}


sub set_functions {
  my $fields = EMC::Common::hash(shift(@_));
  my $attr = EMC::Common::attributes(@_);
  my $set = EMC::Common::hash($fields, "set");
  my $flags = {commands => 1, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Fields::set_commands;
  $set->{context} = \&EMC::Fields::set_context;
  $set->{defaults} = \&EMC::Fields::set_defaults;
  $set->{options} = \&EMC::Fields::set_options;
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $fields;
}


# set item

sub set_item_field {
  my $struct = shift(@_);
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Common::element($item, "options");
  my $arg = EMC::Hash::arguments($options);

  return if (EMC::Common::element($arg, "comment"));
  
  my $root = EMC::Common::element($struct, "root");
  my $global = EMC::Common::element($root, "global");
  my $flag = EMC::Common::element($global, "flag");
  my $fenv = EMC::Common::element($root, "environment", "flag", "active");
  
  my $module = EMC::Common::element($struct, "module"); 
  my $fields = EMC::Common::element($module, "fields");

  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my ($name, $line) = split(":", $lines->[0]);
  my $pwd = cwd();
  
  my $location;
  my $source;

  $name = defined($arg->{name}) ? $arg->{name} : $global->{project}->{name};
  if ($fenv) {
    mkpath("chemistry") if (! -e "chemistry");
    chdir("chemistry");
    mkpath("field") if (! -e "field");
    $location = cwd();
    $name = "field/$name";
    EMC::Message::info("creating chemistry \"$name\"\n");
  } else {
    $location = ".";
    EMC::Message::info("creating field parameter file \"$name\"\n");
  }
  if (defined($fields)) {
    if (!defined($arg->{field}) && defined($options) && scalar(@{$options})) {
      my $a = EMC::List::extract("=", $options, {not => 1});
      $arg->{field} = $a->[0] if (defined($a));
    }
    if (defined($arg->{field})) {
      $source = EMC::Common::element($fields, $arg->{field});
    } else {
      if (scalar(keys(%{$module->{fields}}))>1) {
	EMC::Message::error_line(
	  $line, "adaptation of only one field allowed\n");
      }
      $source = EMC::Common::element($fields, (keys(%{$fields}))[0]);
    }
    if (!defined($source)) {
      EMC::Message::error_line($line, "field undefined\n");
    }
    $source->{field} = EMC::Fields::item_field(
      EMC::Fields::get("$source->{location}/$source->{name}"),
      {name => $name, line => $line, data => $data});
    EMC::Fields::put($name.".prm", $source->{field});
    $source->{location} = $location;
    $source->{name} = $name;
    EMC::Fields::update_locations($fields);
  } else {
    my $verbatim = [];				# compatibility with EMCField
    my @a = split(":", $lines->[0]);
    foreach (@{$data}) { 
      push(@{$verbatim}, {line => "@a[0]:".@a[1]++, verbatim => $_});
    }
    $flag->{rules} = EMCField::main("-quiet", "-input", $verbatim, $name);
  }
  chdir($pwd);
  return $root;
}


# functions

sub compare {
  return 0 if (@_[0] eq "*");
  return 1 if (@_[1] eq "*");
  return @_[0] lt @_[1] ? 1 : 0;
}


sub arrange {
  return @_ if (scalar(@_)<2);
  return @_ if (compare(@_[0, -1]));
  if (@_[0] eq @_[-1]) {
    return @_ if (scalar(@_)<4);
    return @_ if (compare(@_[1, 2]));
    return @_[3,2,1,0];
  }
  return @_[1,0] if (scalar(@_) == 2);
  return @_[2,1,0] if (scalar(@_) == 3);
  return @_[3,2,1,0];
}


sub arrange_imp {
  return @_[0,2,3,1] if (
    (compare(@_[2,3])||(@_[2] eq @_[3])) && compare(@_[2, 1]));
  return @_[0,3,1,2] if (
    (compare(@_[3,1])||(@_[3] eq @_[1])) && compare(@_[3, 2]));
  return @_;
}


sub arrange_t {
  my $arrange = shift(@_);
  my $ntypes = shift(@_);

  if ($ntypes<scalar(@_)) {
    my $t = pop(@_);
    return ($arrange->(@_), $t);
  }
  return $arrange->(@_);
}


sub arrange_none {
  return @_;
}


sub index {
  my $index = [];
  my $guide = $EMC::Fields::Guide;

  foreach (@{$guide->{index}}) {
    if (defined($guide->{auto}->{$_})) {
      push(@{$index}, $_."_auto");
    }
    push(@{$index}, $_);
  }
  return $index;
}


# import

# separate items for .define

sub item_bonded {
  my $items = shift(@_);
  my $attr = shift(@_);

  my $root = EMC::Common::element($attr, "root");
  my $field = EMC::Common::element($attr, "field");
  my $index = EMC::Common::element($attr, "index");
  my $data = EMC::Common::element($items, $index, "data");
  my $lines = EMC::Common::element($items, $index, "lines");

  return if (!($root && $field && $index && $data && $lines));

  my $equivalence = EMC::Common::element($field, "equivalence", "data");
  my $mass = EMC::Common::element($field, "mass", "data");

  my $line = -1;
  my $ntypes = {bond => 2, angle => 3, torsion => 4, improper => 4}->{$index};
  my $ieqv = {bond => 2, angle => 3, torsion => 4, improper => 5}->{$index};
  my $arrange = $index eq "improper" ? 
    \&EMC::Fields::arrange_imp : \&EMC::Fields::arrange;
  my $register;
  my $auto;

  foreach (@{$data}) {
    my $arg = EMC::List::extract("", @{$_}, {last => "#", not => 1});

    ++$line;
    next if (ref($arg) ne "ARRAY");
    my @type = splice(@{$arg}, 0, $ntypes);
    my $fauto = 0;
    foreach (@type) {
      if ($_ =~ m/\*/) {
	$fauto = 1;
	next;
      }
      if (!defined($mass->{$_})) {
	EMC::Message::error_line($lines->[$line], "undefined type '$_'\n");
      }
      if (ref($equivalence->{$_}) eq "ARRAY") {
	$_ = $equivalence->{$_}->[$ieqv];
      }
    }
    if ($fauto) {
      $auto = EMC::Common::hash($field, $index."_auto", "data") if (!$auto);
    } elsif (!$register) {
      $register = EMC::Common::hash($field, $index, "data");
    }
    my $list = EMC::Common::list($fauto ? $auto : $register, @type);
    push(@{$list}, @{$arg});
  }
}


sub item_define {
  my $items = shift(@_);
  my $attr = shift(@_);

  my $field = EMC::Common::element($attr, "field");
  my $index = EMC::Common::element($attr, "index");
  my $data = EMC::Common::element($items, $index, "data");
  my $lines = EMC::Common::element($items, $index, "lines");

  return if (!($field && $index && $data && $lines));

  my $line = -1;
  my $define = EMC::Common::hash($field, "define", "data");

  foreach (@{$data}) {
    my $arg = EMC::List::extract("", @{$_}, {last => "#", not => 1});

    ++$line;
    next if (ref($arg) ne "ARRAY");
    if (!defined($define->{uc($arg->[0])})) {
      EMC::Message::error_line($lines->[$line],
	"unsupported define keyword '$arg->[0]'\n");
    }
    if (scalar(@{$arg}!=2)) {
      EMC::Message::error($lines->[$line], "incorrect number of entries\n");
    }
    $define->{uc($arg->[0])} = uc($arg->[1]);
  }
}


sub item_equivalence {
  my $items = shift(@_);
  my $attr = shift(@_);

  my $root = EMC::Common::element($attr, "root");
  my $field = EMC::Common::element($attr, "field");
  my $index = EMC::Common::element($attr, "index");
  my $data = EMC::Common::element($items, $index, "data");
  my $lines = EMC::Common::element($items, $index, "lines");

  return if (!($root && $field && $data && $lines));

  my $equivalence = EMC::Common::hash($field, "equivalence", "data");

  my $line = -1;

  foreach (@{$data}) {						# storage
    my $arg = EMC::List::extract("", @{$_}, {last => "#", not => 1});

    ++$line;
    next if (ref($arg) ne "ARRAY");
    if (scalar(@{$arg}!=7)) {
      EMC::Message::error_line($lines->[$line],
       	"incorrect number of entries\n");
    }
    my $list = EMC::Common::list($equivalence, shift(@{$arg}));
    push(@{$list}, @{$arg});
  }
}


sub item_increment {
  my $items = shift(@_);
  my $attr = shift(@_);

  my $root = EMC::Common::element($attr, "root");
  my $field = EMC::Common::element($attr, "field");
  my $index = EMC::Common::element($attr, "index");
  my $data = EMC::Common::element($items, $index, "data");
  my $lines = EMC::Common::element($items, $index, "lines");

  return if (!($root && $field && $data && $lines));

  my $mass = EMC::Common::element($field, "mass", "data");
  my $increment = EMC::Common::hash($field, "increment", "data");

  my $line = -1;

  foreach (@{$data}) {						# storage
    my @a;

    foreach (@{$_}) {
      last if (substr($_,0,1) eq "#");
      push(@a, $_);
    }

    my $arg = EMC::List::extract("", @a, {not => 1});

    ++$line;
    next if (ref($arg) ne "ARRAY");
    if (scalar(@{$arg}!=4)) {
      EMC::Message::error_line($lines->[$line],
       	"incorrect number of entries\n");
    }

    my @type = (shift(@{$arg}), shift(@{$arg}));

    foreach (@type) {
      next if ($_ =~ m/\*/);
      if (!defined($mass->{$_})) {
	EMC::Message::error_line($lines->[$line], "undefined type '$_'\n");
      }
    }
    $increment->{@type[0]}->{@type[1]} = join("\t", @{$arg});
  }
}


sub item_mask {
  my $items = shift(@_);
  my $attr = shift(@_);

  my $field = EMC::Common::element($attr, "field");
  my $data = EMC::Common::element($items, "mask", "data");
  my $lines = EMC::Common::element($items, "mask", "lines");

  my $mode = EMC::Common::element($field, "define", "data", "FFMODE");
  my $mask = EMC::Common::hash($EMC::Fields::masks, lc($mode));
  my $allowed = {avg => 0, comment => 0, log => 0, none => 1, "-" => 1};
  my @keys = ("method", "offset");
  my $line = 0;

  return $mask if (!defined($data));

  foreach (@{$data}) {
    my @a = @{$_};
    my $ptr = EMC::Common::list($mask, lc(shift(@a)));
    my $i = 0;

    foreach (@a) {
      my $j = -1;
      foreach (split(":", lc($_))) {
	last if (!defined(@keys[++$j]));
	if (!$j) {
	  if (!defined($allowed->{$_})) {
	    EMC::Message::error_line(
	      $lines->[$line], "unallowed keyword '$_'\n");
	  }
	  if ($allowed->{$_}) {
	    $ptr->[$i]->{@keys[$j]} = undef;
	    last;
	  }
	}
	$ptr->[$i]->{@keys[$j]} = $_;
      }
      ++$i;
    }
    ++$line;
  }
  return $mask;
}


sub item_references {
  my $items = shift(@_);
  my $attr = shift(@_);

  my $field = EMC::Common::element($attr, "field");
  my $index = EMC::Common::element($attr, "index");
  my $data = EMC::Common::element($items, $index, "data");
  my $lines = EMC::Common::element($items, $index, "lines");

  return if (!($field && $index && $data && $lines));

  my $references = EMC::Common::list($field, "references", "data");

  my $line = -1;

  foreach (@{$data}) {
    my $arg = EMC::List::extract("", @{$_}, {not => 1});

    ++$line;
    next if (ref($arg) ne "ARRAY");
    next if (substr($arg->[0],0,1) eq "#");
    if (scalar(@{$arg})!=4) {
      EMC::Message::error($lines->[$line], "incorrect number of entries\n");
    }
    push(@{$references}, [@{$arg}]);
  }
}


# item field in .esh

sub item_field {
  my $field = shift(@_);
  my $attr = shift(@_);

  my $name = EMC::Common::element($attr, "name").".esh";
  my $line = EMC::Common::element($attr, "line");
  my $data = EMC::Common::element($attr, "data");
  my $source = EMC::Common::element($attr, "source");

  my $raw = {data => $data, lines => {0 => {name => "$name", line => $line}}};
  my $items = EMC::Item::read({data => $raw, flag => {split => 1}});
  my $field =  EMC::Fields::from_item($items, {field => $field});

  return $field if (!defined($items->{replica}));

  my $mask = EMC::Fields::item_mask($items, {field => $field});

  if (!defined($mask)) {
    EMC::Message::error_line("$name:$line", "undefined combinatorial mask\n");
  }

  my $replicas = $items->{replica};
  my $adaptations = [
    "mass", "equivalence", "nonbond", "bond", "angle", "torsion", "improper"];
  my $visits = {};

  $line = (split(":", $replicas->{lines}->[0]))[-1];
  foreach (@{$replicas->{data}}) {
    my @args = @{$_};
    my ($target, $factor) = split(":", shift(@args));
    my $offset = scalar(@args)>1 ? pop(@args) : 0;
    my (@source, @fraction);
    my $flag = 1;

    $factor = 1 if (!defined($factor));
    foreach (@args) {
      my @a = split(":");

      push(@source, shift(@a));
      push(@fraction, defined(@a[0]) ? shift(@a) : 1);
      $flag = 0 if (defined(@a[0]) && !EMC::Math::flag(shift(@a)));
    }
    if ($flag) {
      my $norm = 0;
      foreach (@fraction) { $norm += $_; }
      if ($norm) { foreach (@fraction) { $_ /= $norm; } }
    }
    foreach (@{$adaptations}) {
      next if (!defined($field->{$_}));

      my $adapt = $_;
      my $visit = EMC::Common::hash($visits, $_);
      my $method = EMC::Common::element($mask, $_);
      my $n = $field->{$_}->{flag}->{ntypes};
      my $index = EMC::List::hash($field->{$_}->{index});
      my $ptr = [$field->{$_}->{data}];
      my $keys = [[sort(keys(%{$ptr->[0]}))]];
      my @key = ();
      my $i;

      next if (!defined($method));
      push(@{$keys}, map([], (1..$n)));
      while (1) {
	last if (!scalar(@{$keys->[0]}));
	
	for ($i=$n; $i>1; --$i) { 			# advance
	  last if(scalar(@{$keys->[$i-1]}));
	}
	@key[$i-1] = shift(@{$keys->[$i-1]});
	for (; $i<$n; ++$i) { 
	  $ptr->[$i] = $ptr->[$i-1]->{@key[$i-1]};
	  $keys->[$i] = [sort(keys(%{$ptr->[$i]}))];
	  @key[$i] = shift(@{$keys->[$i]});
	}
	$ptr->[$i] = $ptr->[$i-1]->{@key[-1]};

	#$i = 0; foreach(@key) { last if (($i = defined($exclude->{$_}))); }
	#next if ($i);

	next if (!EMC::List::check(\@source, \@key));
	my $index = -1;
	foreach (@source)				# deal with averaging
	{
	  ++$index;
	  next if (!EMC::List::check($_, \@key));
	  my $change = $_;
	  my @t = @key;

	  foreach (@t) {
	    next if ($_ ne $change);
	    $_ = $target;

	    my $data = $ptr->[0];
	    my @tmp = arrange(@t);
	    my $key = join("\t", @tmp);
	    my $flag = 1;

	    $i = 0;
	    foreach (arrange(@tmp)) {
	      $data = ++$i==$n ?
		EMC::Common::list($data, $_) : EMC::Common::hash($data, $_);
	    }
	    if (!defined($visit->{$key})) {		# apply function
	      last if (scalar(@{$data}));
	      my $i = 0;
	      @{$data} = @{$ptr->[-1]};
	      foreach (@{$method}) {
		if (EMC::List::check($_->{method}, ["avg", "log"])) {
		  $data->[$i] = 0.0;
		}
		++$i;
	      }
	      ++$visit->{$key};
	      $flag = 0;
	    }
	    my $i = 0;
	    foreach (@{$method}) {
	      if ($_->{method} eq "avg") {
		$data->[$i] += 
		  @fraction[$index]*($ptr->[-1]->[$i]-$_->{offset});
	      } elsif ($_->{method} eq "log") {
		$data->[$i] +=
		  defined($visit->{join("\t", @key)}) ?
		    @fraction[$index]*$ptr->[-1]->[$i] :
		    @fraction[$index]*log($ptr->[-1]->[$i]);
	      }
	      ++$i;
	    }
	  }
	}
      }
    }
  }
  foreach (keys(%{$visits})) {				# post processing
    my $visit = $visits->{$_};
    my $ptr = $field->{$_}->{data};
    my $method = EMC::Common::element($mask, $_);

    foreach (keys(%{$visit})) {
      my @key = split("\t");
      my $data = $ptr;
      my $i = 0;

      foreach (@key) {
	$data = ++$i==scalar(@key) ?
	  EMC::Common::list($data, $_) : EMC::Common::hash($data, $_);
      }
      $i = 0;
      foreach (@{$method}) {
	if ($_->{method} eq "avg") {
	  $data->[$i] += $_->{offset};
	} elsif ($_->{method} eq "log") {
	  $data->[$i] = sprintf("%.6g", exp($data->[$i]));
	}
	++$i;
      }
    }
  }
  return $field;
}


# item struct

sub from_item {
  my $item = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $indexed = defined($attr->{indexed}) ? $attr->{indexed} ? 1 : 0 : 0;
  my $field = defined($attr->{field}) ? $attr->{field} : undef;
  my $guide = $EMC::Fields::Guide;

  foreach (@{$guide->{index}}) {
    my $class = $_;
    my $define = $class eq "define";

    foreach (defined($guide->{auto}->{$class}) ? ("_auto", "") : ("")) {
      my $key = $class.$_;
      my $index;
      my $array;
      
      next if (!defined($item->{$key}));

      $field->{$key}->{flag} = {} if (!defined($field->{$key}->{flag}));

      my $ftable = defined($guide->{table}->{$class}) ? 1 : 0;
      my $entry = $item->{$key};
      my $flag = $field->{$key}->{flag};
      my $fcmap = $flag->{cmap} = $key eq "cmap" ? 1 : 0;
      my $ntypes = defined($guide->{ntypes}) ? $guide->{ntypes}->{$class} : 0;

      $flag->{array} = 0;
      $flag->{ntypes} = $ntypes;
      if (defined($item->{$key}->{header})) {
	$field->{$key}->{header} = [@{$item->{$key}->{header}}];
      }
      if ($ntypes) {

	# section with data indexed by types

	my $arrange = $class eq "improper" ? \&arrange_none : \&arrange;
	my $table;
	my $order;
	my $n;

	if (defined($guide->{order}->{$key})) {
	  $order = EMC::Common::array($field, $key, "order");
	}
	foreach (@{$entry->{data}}) {
	  my $arg = [];

	  foreach (@{$_}) {				# filter out empty
	    push(@{$arg}, $_) if ($_ ne "");
	  }
	  if (defined($table)) {			# populate table
	    push(@{$table}, @{$arg});
	    next if (scalar(@{$table})<$n);
	    undef($table);
	    undef($n);
	  } elsif (substr($_->[0],0,1) eq "#") {	# create index
	    if (!defined($index)) {
	      $index = [@{$arg}];
	      $index->[0] =~ s/^# //g;
	      if ($index->[-1] eq "[...]") {
		$flag->{array} = $array = 1;
		pop(@{$index});
	      }
	      $field->{$key}->{index} = [@{$index}];
	      for (my $i=0; $i<$ntypes; ++$i) {
		shift(@{$index});
	      }
	      $flag->{index} = [@{$index}] if ($indexed);
	    }
	  } else {					# deal with data
	    my $t = [];
	    
	    for (my $i=0; $i<$ntypes; ++$i) {
	      push(@{$t}, shift(@{$arg}));
	    }
	    $t = [$arrange->(@{$t})];
	    $field->{$key}->{data} = {} if (!defined($field->{$key}->{data}));

	    my $ptr = $field->{$key}->{data};
	    my $lptr;

	    if (defined($order)&&!defined($ptr->{$t->[0]})) {
	      push(@{$order}, $t->[0]);
	    }
	    if ($arg->[0] eq "T") {			# data contains temp
	      shift(@{$arg});
	      push(@{$t}, shift(@{$arg}));
	      $flag->{ntypes} = $ntypes+1;
	      $flag->{t} = 1;
	    } 
	    if ($define) {
	      $ptr = \$ptr->{$t->[0]};
	    } else {
	      foreach (0..$#{$t}) {			# hash
		my $s = $t->[$_];
		if (!defined($ptr->{$s}) || $_==$#{$t}) {
		  $ptr->{$s} = $_==$#{$t} && 
			       (defined($array) || !$indexed) ? [] : {};
		}
		$ptr = $ptr->{$s};
	      }
	    }
	    if ($ftable && $arg->[0] eq "TABLE") {	# data contains table
	      shift(@{$arg});
	      $n = shift(@{$arg});
	      if ($indexed) {
		$ptr->{n} = $n;
		$ptr->{x0} = shift(@{$arg}) if (defined($arg->[0]));
		$ptr->{dx} = shift(@{$arg}) if (defined($arg->[0]));
		$table = $ptr->{table} = [];
	      } else {
		push(@{$ptr}, $n);
		push(@{$ptr}, shift(@{$arg})) if (defined($arg->[0]));
		push(@{$ptr}, shift(@{$arg})) if (defined($arg->[0]));
		push(@{$ptr}, $table = []);
	      }
	      $flag->{table} = 1;
	    } elsif ($fcmap) {
	      $n = shift(@{$arg});
	      if ($indexed) {
		$ptr->{n} = $n;
		$table = $ptr->{table} = [];
	      } else {
		push(@{$ptr}, $n);
		push(@{$ptr}, $table = []);
	      }
	      $n *= 24;
	      $flag->{table} = 1;
	    } else {
	      if ($indexed && defined($index)) {	# index exists

		if (defined($array)) {			# data is array
		  my $entry;
		  my $i = 0;

		  foreach (@{$arg}) {
		    $entry->{$index->[$i]} = $_;
		    if ($i==$#{$index}) {
		      push(@{$ptr}, $entry);
		      undef($entry);
		      $i = 0;
		    } else {
		      ++$i;
		    }
		  }
		  if (defined($entry)) {
		    push(@{$ptr}, $entry);
		  }
		} else {				# regular data
		  foreach (0..$#{$index}) {
		    $ptr->{$index->[$_]} = $arg->[$_];
		    last if (!defined($arg->[$_]));
		  }
		}
	      } else {					# unindexed data
		if ($define) {
		  ${$ptr} = $arg->[0];
		} else {
		  push(@{$ptr}, @{$arg});
		}
	      }
	    }
	  }
	}
      } else {

	# section without indexed data
	
	my $data;

	foreach (@{$entry->{data}}) {
	  my $arg = [];

	  foreach (@{$_}) {				# filter out empty
	    push(@{$arg}, $_) if ($_ ne "");
	  }
	  if(substr($_->[0],0,1) eq "#") {		# determine index
	    if (!defined($index)) {
	      $index = [@{$arg}];
	      $index->[0] =~ s/^# //g;
	      $field->{$key}->{index} = [@{$index}];
	      $flag->{index} = [@{$index}] if ($indexed);
	    }
	  } else {					# collect data
	    $data = [] if (!defined($data));
	    if ($indexed && defined($index)) {
	      my $ptr;
	      foreach (0..$#{$index}) {
		$ptr->{$index->[$_]} = $arg->[$_];
		last if (!defined($arg->[$_]));
	      }
	      push(@{$data}, $ptr);
	    } else {
	      push(@{$data}, [@{$arg}]);
	    }
	  }
	}
	if (defined($data)) {				# store data
	  $field->{$key}->{data} = $data;
	}
      }
    }
  }

  return EMC::Struct::set_index($field, EMC::Fields::index());
}


# export

sub append_table {
  my $data = shift(@_);
  my $table = shift(@_);
  my $entry = shift(@_);
  my $flag = shift(@_);
  my $n = 5;
  my $i = $n-1;

  push(@{$data}, []) if (!$flag->{first});
  $flag->{first} = 0;
  foreach (@{$table}) {
    if (++$i==$n) {
      push(@{$data}, $entry) if (scalar(@{$entry}));
      $entry = [];
      $i = 0;
    }
    push(@{$entry}, $_);
  }
  return $entry;
}

sub append_index {
  my $data = shift(@_);
  my $ptr = shift(@_);
  my $index = shift(@_);
  my $entry = shift(@_);

  foreach (@{$index}) {
    if ($_ eq "table") {
      $entry = append_table($data, $ptr->{$_}, $entry);
    } else {
      push(@{$entry}, $ptr->{$_});
    }
  }
  return $entry;
}


sub append_entry {
  my $data = shift(@_);
  my $type = shift(@_);
  my $ptr = shift(@_);
  my $flag = shift(@_);
  my $array = defined($flag->{array}) ? $flag->{array} : 0;
  my $index = defined($flag->{index}) ? $flag->{index} : undef;
  my $table = defined($flag->{table}) ? $flag->{table} : 0;
  my $cmap = defined($flag->{cmap}) ? $flag->{cmap} : 0;
  my $entry = [];

  $ptr = $ptr->{data} if ((ref($ptr) eq "HASH") && (defined($ptr->{data})));
  if (defined($type) && scalar(@{$type})) {
    if (defined($flag->{t})) {
      my @t = @{$type};
      my $temp = pop(@t);
      push(@{$entry}, @t, "T", $temp);
    } else {
      push(@{$entry}, @{$type});
    }
  }
  push(@{$entry}, "TABLE") if ($table && !$cmap);
  if (defined($index)) {
    if (ref($ptr) eq "ARRAY") {
      foreach (@{$ptr}) {
	$entry = append_index($data, $_, $index, $entry);
      }
    } else {
      $entry = append_index($data, $ptr, $index, $entry);
    }
  } elsif (defined($ptr)) {
    if ($table) {
      if (ref($ptr) eq "ARRAY") {
	foreach (@{$ptr}) {
	  if (ref($_) eq "ARRAY") {
	    $entry = append_table($data, $_, $entry, $flag);
	  } else {
	    push(@{$entry}, $_);
	  }
	}
      } else {
	push(@{$entry}, $ptr);
      }
    } else {
      push(@{$entry}, ref($ptr) eq "ARRAY" ? @{$ptr} : $ptr);
    }
  }
  push(@{$data}, $entry) if (scalar(@{$entry}));
}


sub order_rules {
  my $field = shift(@_);
  my $rules = EMC::Common::element($field, "rules");
  my $data = EMC::Common::element($field, "rules", "data");
  my $hash;

  return if (!$rules || !$data);
  
  my $id = 0;
  foreach (sort(
    {EMC::List::compare($a, $b, 1)}
    map($data->{$_}, sort({$a<=>$b} keys(%{$data}))))) {
    $hash->{$id++} = $_;
  }
  $rules->{data} = $hash;
  $rules->{order} = [map($_-1, (1..$id))];
}


sub add_type {
  my $hash = shift(@_);
  my $type = shift(@_);
  my $order = EMC::Common::list($hash, "order");

  push(@{$order}, $type) if (!defined($hash->{$type}));
  return EMC::Common::hash($hash, "data", $type);
}


sub indent {
  my $n = shift(@_);

  return ("\t" x int($n/4)).("  " x ($n % 4));
}

sub to_item_precedence {
  my $key = "precedence";
  my $field = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $item = defined($attr->{item}) ? $attr->{item} : undef;

  my $sub = $field->{$key};
  my $hash = {data => {}, order => []};
  my $stack = [];
  my $level = 0;
  my $type;
  
  foreach (@{$sub->{data}}) {
    foreach (@{$_}) {
      foreach (split("")) {
	if ($_ eq "(") {
	  $hash = add_type($hash, $type) if ($type);
	  push(@{$stack}, $hash);
	  $type = undef;
	  ++$level;
       	}
	elsif ($_ eq ")") { 
	  if (--$level<0) {
	    EMC::Message::error(
	      "unmatching parenthesis in precedence section\n");
	  }
	  add_type($hash, $type) if ($type);
	  $type = undef;
	  $hash = pop(@{$stack}) if (@{$stack});
       	}
	elsif ($_ eq " ") { 
	  $hash = add_type($hash, $type) if ($type);
	  $type = undef;
       	}
	else {
	  $type .= $_;
       	}
      }
      $hash = add_type($hash, $type) if ($type);
      $type = undef;
    }
  }
  
  my $item = EMC::Common::element($attr, "item");
  my $data = EMC::Common::list($item, $key, "data");
  my $flag = EMC::Common::element($field, $key, "flag");
  my $i = $hash->{i} = 0;
  my $entry;
  my $type;

  $level = 0;
  $stack = [];
  while (1) {
    if (defined($hash->{order}) ? $hash->{i}==@{$hash->{order}} : 1) {
      last if (!$level);
      append_entry($data, undef, [$entry.")"], $flag);
      $hash = pop(@{$stack});
      --$level;
      $entry = indent($level-1);
      next;
    }
    $type = $hash->{order}->[$hash->{i}++];
    $entry = indent($level)."($type";
    
    push(@{$stack}, $hash);
    $hash = $hash->{data}->{$type};
    $hash->{i} = 0;
    ++$level;
    if (defined($hash->{order})) {
      append_entry($data, undef, [$entry], $flag);
    }
  }
  return $item;
}


sub to_item {
  my $field = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $item = defined($attr->{item}) ? $attr->{item} : undef;
  my $guide = $EMC::Fields::Guide;

  order_rules($field);
  foreach (@{$guide->{index}}) {
    my $class = $_;
    my $define = $class eq "define";

    foreach (defined($guide->{auto}->{$class}) ? ("_auto", "") : ("")) {
      my $key = $class.$_;
      
      next if (!defined($field->{$key}));
      
      my $sub = $field->{$key};
      my $ptr = [$sub->{data}];
      my $flag = defined($sub->{flag}) ? $sub->{flag} : undef;
      my $ntypes = defined($flag->{ntypes}) ? $flag->{ntypes} : 0;
      my $nt = defined($guide->{ntypes}) ? $guide->{ntypes}->{$class} : 0;

      $item->{$key} = {} if (!defined($item->{$key}));
      my $data = defined($item->{$key}->{data}) ? $item->{$key}->{data} : [];
      my $type = [];
      my $i = 0;

      if (defined($sub->{header})) {
	$item->{$key}->{header} = [@{$sub->{header}}];
      }
      if (defined($sub->{index})) {
	my @arg = @{$sub->{index}};
	@arg[0] = "# ".@arg[0];
	append_entry($data, undef, \@arg, undef);
      }
      if ($ntypes>0) {
	my $arrange = $class eq "improper" ? \&arrange_none : \&arrange;
	my $order = defined($sub->{order}) ? $sub->{order} : undef;
	my $keys = [[$order ? @{$order} : sort(keys(%{$ptr->[0]}))]];
	my @key = ();
	my $i;

	$flag->{first} = 1;
	push(@{$keys}, map([], (1..$ntypes)));
	while (1) {
	  last if (!scalar(@{$keys->[0]}));
	  for ($i=$ntypes; $i>1; --$i) { 		# advance
	    last if(scalar(@{$keys->[$i-1]}));
	  }
	  @key[$i-1] = shift(@{$keys->[$i-1]});
	  for (; $i<$ntypes; ++$i) { 
	    $ptr->[$i] = $ptr->[$i-1]->{@key[$i-1]};
	    $keys->[$i] = [sort(keys(%{$ptr->[$i]}))];
	    @key[$i] = shift(@{$keys->[$i]});
	  }
	  $ptr->[$i] = $ptr->[$i-1]->{@key[-1]};
	  append_entry(
	    $data, [arrange_t($arrange, $nt, @key)], $ptr->[-1], $flag);
	}
      } else {
	if (ref($ptr->[-1]) eq "ARRAY") {
	  if ($key eq "precedence") {
	    to_item_precedence($field, {item => $item});
	  } else {
	    foreach (@{$ptr->[-1]}) {
	      append_entry($data, $type, $_, $flag);
	    }
	  }
	} else {
	  append_entry($data, $type, $ptr->[-1], $flag);
	}
      }
      $item->{$key}->{data} = $data if (scalar(@{$data}));
    }
  }
  return EMC::Struct::set_index($item, EMC::Fields::index());
}


# I/O

sub header {
  my $stream = shift(@_);
  my $name = shift(@_);

  $name = basename($name, ".gz");
  print ($stream "#EMC/FIELD/$EMC::Identity->{version}
#
#   file:	$name
#   author:	EMC v$EMC::Identity->{version}
#   date:	".EMC::Common::date_full()."
#   purpose:	Force field file
#

"
  );
}


sub get {
  my @extensions = (".prm", ".top");
  my $name = EMC::IO::strip(shift(@_), @extensions);
  my $attr = EMC::Common::attributes(shift(@_));
  my $field = EMC::Common::hash($attr, "field");
  my $flag = 0;
  my $stream;
  my $field;

  foreach (@extensions) {
    my $ext = $_;
    foreach (".gz", "") {
      next if (! -f EMC::IO::expand("$name$ext$_"));
      EMC::Message::info("reading field from '$name$ext$_'\n");
      $stream = EMC::IO::open("$name$ext$_", "r");
      $attr = EMC::Common::attributes($attr, {field => $field});
      $field = EMC::Fields::read($stream, $attr);
      EMC::IO::close($stream, $name);
      $flag = 1;
      last;
    }
  }
  return $field;
}


sub read {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $item = EMC::Item::read($stream, {flag => {header => 1}});
  my $field = from_item($item, $attr);

  #EMC::Message::dumper("item = ", $item);
  #EMC::Message::dumper("field = ", $field);
  return $field;
}


sub put {
  my $name = shift(@_);
  my $field = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $stream;

  EMC::Message::info("writing field to '$name'\n");
  $stream = EMC::IO::open($name, "w");
  EMC::Fields::header($stream, $name);
  $field = EMC::Fields::write($stream, $field, $attr);
  EMC::IO::close($stream, $name);
  
  return $field;
}


sub write {
  my $stream = shift(@_);
  my $field = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $item = to_item($field, $attr);

  #EMC::Message::dumper("field = ", $field); # exit(-1);
  #EMC::Message::dumper("item = ", $item); # exit(-1);
  EMC::Item::write($stream, $item);
  return $field;
}


# application

sub id {
  my $fields = shift(@_);
  my $line = shift(@_);
  my @fld = @_;
  my $list = EMC::Common::element($fields, "list");


  foreach (@fld) {
    my $f = $_;
    my $error = 1;
    foreach (keys(%{$list->{id}})) {
      if (index($list->{id}->{$_}, $f)>=0) {
	$f = $list->{id}->{$_};
	$error = 0;
      }
    }
    EMC::Message::error_line(
      $line, "unknown field reference '$f'\n") if ($error);
    $_ = $f;
  }
  return [@fld];
}


sub type {
  my $name = shift(@_);
  my $add = shift(@_);
  my $global = shift(@_);
  my $stream = EMC::IO::open($name, "r");
  my $define = 0;
  my @arg = split("\.", (split($^O eq "MSWin32" ? "\\\\" : "/", $name))[-1]); pop(@arg);
  my $type = join("\.", @arg);
  my $read = 0;

  foreach (<$stream>) {
    chop();
    @arg = split(" ");
    return "cff" if (uc(join(" ", @arg)) eq "!BIOSYM FORCEFIELD 1");
    @arg[0] = uc(@arg[0]);
    if (@arg[0] eq "ITEM") {
      $read = 1 if (@arg[1] eq "DEFINE");
      last if (@arg[1] eq "END");
      next;
    }
    next if (!$read);
    if (@arg[0] eq "FFMODE" || @arg[0] eq "FFNAME") {
      $type = lc(@arg[1]);
    } elsif (@arg[0] eq "CUTOFF") {
      $global->{cutoff}->{pair} = eval(@arg[1]) if (defined($global));
    }
  }
  return $type;
}


sub assign_fields {
  my $fields = shift(@_);
  my $fields_fields = EMC::Common::hash($fields, "fields");

  foreach (keys(%{$fields_fields})) {
    my $field = $fields_fields->{$_};
    
    next if (defined($field->{field}));
    $field->{field} = EMC::Fields::get("$field->{location}/$field->{name}");
  }
  return $fields;
}


sub find_group {
  my $fields = EMC::Fields::assign_fields(shift(@_))->{fields};
  my $name = shift(@_);
  my $result = [];

  foreach (sort(keys(%{$fields}))) {
    my $field = $fields->{$_};
    my $templates = EMC::Common::element($field, "field", "templates", "data");

    if (defined($templates->{$name})) {
      push(@{$result}, {
	  id => $_,
	  name => $name,
	  field => $field,
	  chemistry => $templates->{$name}->[0]
	}
      );
    }
  }
  return $result;
}


sub output_fields {
  my $fields = EMC::Common::hash(shift(@_), "fields");
  my $id = shift(@_);
  my %entries;
  my @entries;

  foreach (keys(%{$fields})) { 
    my $ptr = $fields->{$_};
    $entries{$ptr->{$id}} = 1;
  }
  foreach (sort(keys(%entries))) {
    push(@entries, "\"$_\"");
  }
  if (scalar(@entries)>1) {
    EMC::Message::info("force field $id"."s = {".join(", ", @entries)."}\n");
  } else {
    EMC::Message::info("force field $id = ".@entries[0]."\n");
  }
}


sub set_field {
  my $fields = shift(@_);
  my $line = shift(@_);
  my $warning = shift(@_);
  my @string = @_;

  my $field_list = EMC::Common::element($fields, "list");
  my $location = EMC::Common::element($fields, "list", "location");
  my $global = EMC::Common::element($fields, "global");

  my @extension = ("frc", "prm", "field");
  my @path = defined($location) ? @{$location} : ();
  my $last_type;
  my @names;
  my %flag;

  my $debug = 0;
  my $message_flag;
  
  if ($debug) {
    $message_flag = EMC::Element::deep_copy(EMC::Message::get_flag());
    EMC::Message::set_flag({debug => 1});
  }

  push(@path, $fields->{field}->{location}) if (!scalar(@path));
  EMC::Message::tdebug(__LINE__.":", @path);
  EMC::Message::tdebug(__LINE__.":", @string);
  foreach (@string) {
    EMC::Message::tdebug(__LINE__.":", $_);
    my @arg = split(":");
    my $string = @arg[0];
    my $style = @arg[1];
    my $index = index($string, "-");
    my $name = "";
    my %result;

    $index = index($string, "/") if ($index<0);
    my $field_type = $index>0 ? substr($string, 0, $index) : $string;
    foreach (".", @path) {
      my $ext;
      my $root = EMC::IO::scrub_dir($_);
      my $split = $root;
      if (substr($_,0,6) eq "\$root+") {
	my $tmp = EMC::IO::scrub_dir("$split/$field_type");
	$root = $tmp if (-d $tmp);
      } else {
	my $tmp = $split = EMC::IO::scrub_dir($_);
	$tmp =~ s/~/$ENV{HOME}/g if ($^O ne "MSWin32");
	$root = $split if (-d $tmp);
      }
      $split .= "/" if (length($split));
      my %styles = {};

      if ($style ne "" && !defined($styles{$style})) {
	EMC::Message::error_line($line, "illegal field style '$style'\n");
      }

      my $add = $index>0 ? substr($string, $index) : "";
      my %type = ("prm" => $field_type, "frc" => "cff", "field" => "get");
      my %convert = (basf => "cff", pcff => "cff", compass => "cff");
      my $offset = scalar(split("/", $root.$add));

      $root =~ s/~/$ENV{HOME}/g if ($^O ne "MSWin32");
      
      EMC::Message::tdebug(__LINE__.":", "string", $string);
      EMC::Message::tdebug(__LINE__.":", "root", $root);
      if (-d "$root") {
	foreach ("/$field_type", "") {
	  my $dir = "$root$_";
	  next if (! -d "$dir");
	  foreach (@extension) {
	    $ext = $_;
	    foreach ("", ".gz") {
	      my $compress = $_;
	      foreach (sort(
		  {$b cmp $a} EMC::IO::find($dir."/", "*.$ext$compress"))) {
		next if (m/\/src\//);
		next if (index($_, $field_type.$add)<0);
		$field_type = EMC::Fields::type($name = $_, $add, $global);
		last;
	      }
	      last if ($name ne "");
	    }
	    last if ($name ne "");
	  }
	  last if ($name ne "");
	}
	#if ($name eq "") {
	#  foreach (@extension) {
	#    $ext = $_;
	#    foreach (sort(ffind($root."/", "*$field_type*.$ext"))) {
	#      next if (m/\/src\//);
	#      $name = $_; last;
	#    }
	#    last if ($name ne "");
	#  }
	#}
	if ($name ne "") {
	  $name = EMC::IO::scrub_dir($name);
	  $result{type} = defined($convert{$field_type}) ?
				  $convert{$field_type} : $field_type;
	  $result{name} = (split("\.$ext", substr($name, length($split))))[0];
	  $result{location} = EMC::IO::scrub_dir($split);
	  EMC::Message::tdebug(__LINE__.":", "SUCCESS", "$name($result{type})", "\n");
	  last;
	} else {
	  EMC::Message::tdebug(__LINE__.":", "FAILURE\n");
	}
      }
    }
    if ($name eq "") {
      push(@{$warning}, "field '$string' not found; no changes"); }
    else {
      if ($last_type ne "" && $last_type ne $result{type}) {
	EMC::Message::error_line($line, 
	  "unsupported merging of field types $last_type and $result{type}\n");}
      my $field = $fields->{field};
      $field->{flag} = 1;
      $field->{id} = $string;
      $field->{name} = $result{name};
      $field->{location} = $result{location};
      $field->{type} = $last_type = $result{type};
      update_fields($fields, $field);
    }
  }
  EMC::Message::set_flag($message_flag) if ($debug);
  return 1;
}


sub set_flag {
  my $fields = shift(@_);
  my $flags = 
     $fields->{flags} = EMC::Common::hash($fields, "flags");
  my $type = shift(@_);
  my $flag = shift(@_);
  my $types = {
    bond => 0, angle => 0, torsion => 1, improper => 1, increment => 1,
    group => 1};
  
  if (!defined($types->{$type})) {
    EMC::Message::error("illegal field flag type [$type]\n");
  }
  if (!defined($flags->{$flag})) {
    if ($types->{$type}) {
      EMC::Message::error("unknown field flag [$flag]\n");
    }
    return 0;
  }
  $fields->{flag}->{$type} = $flag;
  return 1;
}


sub set_fields {
  my $fields = shift(@_);
  
  return if (defined($fields->{fields}));
  
  my $field = $fields->{field};
  my $list = $fields->{list};
  my $project = EMC::Common::element($fields, "global", "project");

  if (!defined($list->{name})) {
    $list->{name} = [$project->{name}];
    $list->{id} = {$project->{name} => $project->{name}};
  }

  foreach (@{$list->{name}}) {
    $field->{id} = $list->{id}->{$_};
    $field->{name} = $_;
    $field->{type} = $field->{type};
    $fields->{fields}->{$field->{id}} = EMC::Element::deep_copy($field);
  }
}


sub update_field {
  my $fields = shift(@_);

  $fields->{field} = EMC::Common::hash($fields, "field");
  $fields->{fields} = EMC::Common::hash($fields, "fields");

  my $field = ref(@_[0]) eq "HASH" ? shift(@_) : $fields->{field} ;
  my $flag = 0;

  if (defined($fields->{fields}->{$field->{id}})) {
    $fields->{fields}->{$field->{id}}->{@_[0]} = @_[1];
    $flag = 1;
  }
  $field->{@_[0]} = @_[1];
  return $flag;
}


sub update_fields {
  my $fields = shift(@_);
  my $field = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
     $field = $fields->{field} if (!defined($field));
  my $option = shift(@_);

  my $flag = EMC::Common::element($fields, "global", "flag");
  my $id = defined($field) ? $field->{id} : undef;
  my $ilocation = 0;
  my $location = {};
  my @locations; 
  my @names;
  my %ids;

  $fields->{fields} = {} if ($option eq "reset");
  $fields->{fields}->{$id} = EMC::Element::deep_copy($field) if ($option ne "list");
  if (defined($fields->{list}->{location})) {
    foreach (reverse(@{$fields->{list}->{location}})) {
      $location->{$_} = $ilocation++;
      push(@locations, $_);
    }
  }
  
  foreach (sort(keys(%{$fields->{fields}}))) {
    my $ptr = $fields->{fields}->{$_};
    push(@names, $ptr->{name});
    $ids{$ptr->{name}} = $_;
    $ptr->{location} = EMC::IO::scrub_dir($ptr->{location});
    if (defined($location->{$ptr->{location}})) {
      $ptr->{ilocation} = $location->{$ptr->{location}};
    } else {
      $location->{$ptr->{location}} = $ptr->{ilocation} = $ilocation++;
      push(@locations, $ptr->{location});
    }
  }
  #return if ($option ne "list");
  $fields->{list}->{location} = [@locations];
  $fields->{list}->{name} = [sort(@names)];
  $fields->{list}->{id} = {%ids};

  if (defined($fields->{pair_constants}) ?
      $flag->{pair_type} ne $field->{type} : 1) {
    $fields->{pair_constants} = 
      defined($fields->{pair_constants_default}->{$field->{type}}) ? 
      EMC::Element::deep_copy(
	$fields->{pair_constants_default}->{$field->{type}}) : {};
    $flag->{pair_type} = $field->{type};
  }
  return $fields;
}


sub update_locations {
  my $fields = shift(@_);
  my $ilocation = 0;
  my $location = {};

  foreach (sort(keys(%{$fields}))) {
    my $field = $fields->{$_};
    my $l = $field->{location};

    if (defined($location->{$l})) {
      $field->{ilocation} = $location->{$l};
    } else {
      $field->{ilocation} = $location->{$l} = $ilocation++;
    }
  }
}


# application

sub equivalence_index {
  return [
      "type", "pair", "incr", "bond", "angle", "torsion", "improper"
    ];
}


sub equivalence {
  my $field = shift(@_);
  my $attr = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $equivalence = EMC::Common::hash($field, "equivalence");

  if (!defined($equivalence->{index})) {
    $equivalence->{flag} = {
      array => 0, cmap => 0, first => 1, ntypes => 1
    };
    $equivalence->{index} = equivalence_index();
  }
 
  my $i;
  my $type = shift(@_);
  my $data = EMC::Common::list($equivalence, "data", $type);

  for ($i=0; $i<scalar(@_); ++$i) {
    $type = $data->[$i] = @_[$i];
  }
  for (; $i<6; ++$i) {
    $data->[$i] = $type;
  }
  return $field;
}
