#!/usr/bin/env perl
#
#  module:	EMC::Types.pm
#  author:	Pieter J. in 't Veld
#  date:	September 22, 2022.
#  purpose:	Types structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "types_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20220922	Inception of v1.0
#

package EMC::Types;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Types'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::List;
use EMC::Math;
use EMC::Parameters;
use EMC::References;
use EMCField;
use File::Path;


# defaults

$EMC::Types::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 22, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $parent = shift(@_);
  my $types = EMC::Common::element($parent);
  my $attr = EMC::Common::attributes(@_);
  my $modules = {
    parameters => [\&EMC::Parameters::construct, $attr],
    references => [\&EMC::References::construct, $attr]
  };
  
  foreach (keys(%{$modules})) {
    my $ptr = $modules->{$_};
    $types->{$_} = EMC::Common::hash($types->{$_});
    $types->{$_}->{parent} = $parent;
    $types->{$_}->{root} = $types->{root} if (defined($types->{root}));
    $types->{$_} = (scalar(@{$ptr})>1 ? defined($attr) : 0) ? 
	    $ptr->[0]->(\$types->{$_}, $ptr->[1]) : $ptr->[0]->(\$types->{$_});
  }
  
  set_functions($types, $attr);
  set_defaults($types);
  set_commands($types);
  return $types;
}


# initialization

sub set_defaults {
  my $types = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");
  my $root_dir = EMC::IO::emc_root();
  my $root = EMC::Common::element($types, "root");

  $types = EMC::Common::attributes(
    $types,
    {
      # A

      angle_constants	=> "5,180",
      angles		=> undef,

      # B

      bond_constants	=> "20,1",
      bonds		=> undef,

      # C

      cutoff		=> {},

      # I

      impropers		=> undef,
      inverse		=> {},

      # M

      mass		=> {},

      # N

      nonbonds		=> undef,

      # P

      pair_constants	=> undef,
      pair_constants_default => {
        dpd		=> {a => 25, r => 1, gamma => 4.5, cutoff => 1,
			    flag => "dpd"},
	gauss		=> {a => 1, d => 0.4, r0 => 0, cutoff => 2.8,
			    flag => "gauss"}
      },
      
      # R

      replicas		=> undef,

      # T

      torsions		=> undef,
      type		=> {}
    }
  );
  $types->{identity} = EMC::Common::attributes(
    EMC::Common::hash($types, "identity"),
    $EMC::Types::Identity
  );
  $types->{pair_constants} =
    EMC::Element::deep_copy($types->{pair_constants_default}->{dpd});
  
  return $types;
}


sub transfer {
  my $types = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($types, "flag");
  my $context = EMC::Common::element($types, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::AngleConstants,		\$types->{angle_constants}],
    [\%::EMC::Angles,			\$types->{angle}],
    [\$::EMC::BondConstants,		\$types->{bond_constants}],
    [\%::EMC::Bonds,			\$types->{bond}],
    [\%::EMC::Cutoff,			\$types->{cutoff}],
    [\%::EMC::Flag,			\$types->{flag}],
    [\%::EMC::Impropers,		\$types->{impropers}],
    [\%::EMC::InverseType,		\$types->{inverse}],
    [\%::EMC::Mass,			\$types->{mass}],
    [\%::EMC::Nonbonds,			\$types->{nonbond}],
    [\%::EMC::PairConstants,		\$types->{pair_constants}],
    [\%::EMC::PairConstantsDefault,	\$types->{pair_constants_default}],
    [\%::EMC::Parameters,		\$types->{parameters}],
    [\%::EMC::Reference,		\$types->{references}],
    [\@::EMC::Replica,			\$types->{replicas}],
    [\%::EMC::Torsions,			\$types->{torsions}],
    [\%::EMC::Type,			\$types->{type}]
  );
}


sub set_context {
  my $types = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($root, "global", "units");
  my $flag = EMC::Common::element($global, "flag");
  my $context = EMC::Common::element($types, "context");
 
  # B

  $types->{bond_constants} = (
    $field->{type} eq "dpd" ? "25,1" : 
    $field->{type} eq "gauss" ? "5,0" : undef) if ($flag->{bond}<0);
}


sub set_commands {
  my $types = EMC::Common::hash(shift(@_));
  
  my $set = EMC::Common::element($types, "set");
  my $context = EMC::Common::element($types, "context");
  my $flag = EMC::Common::element($types, "flag");
  
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated = $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "types_" : "";

  $types->{commands} = EMC::Common::attributes(
    EMC::Common::hash($types, "commands"),
    {
      # A

      angle		=> {
	comment		=> "set DPD angle constants k and theta or set angle field option (see below)",
	default		=> $types->{angle_constants},
	gui		=> ["list", "chemistry", "field", "advanced", "general"]},
      auto		=> {
	comment		=> "add wildcard entry to mass and nonbond sections in DPD .prm",
	default		=> EMC::Math::boolean($types->{field}->{dpd}->{auto}),
	gui		=> ["boolean", "chemistry", "field", "advanced", "general"]},

      # B

      bond		=> {
	comment		=> "set bond constants k,l",
	default		=> $types->{bond_constants},
	gui		=> ["list", "chemistry", "field", "advanced", "general"]},

      # P

      pair		=> {
	comment		=> "set pair constant defaults",
	default		=> EMC::Hash::text($types->{pair_constants}, "real"),
	gui		=> ["list", "chemistry", "field", "advanced", "dpd"]},
      parameters	=> {
	comment		=> "set parameters file name",
	default		=> $types->{parameters}->{name},
	gui		=> ["browse", "chemistry", "field", "advanced", "dpd"]}
    }
  );

  foreach (keys(%{$types->{commands}})) {
    my $ptr = $types->{commands}->{$_};
    $ptr->{set} = \&EMC::Types::set_options if (!defined($ptr->{set}));
  }

  EMC::Options::set_command(
    $types->{items} = EMC::Common::attributes(
      EMC::Common::hash($types, "items"),
      {
	# A

	angles		=> {
	  set		=> \&set_item_angles
	},

	# B

	bonds		=> {
	  set		=> \&set_item_bonds
	},
	
	# I

	impropers	=> {
	  set		=> \&set_item_impropers
	},

	# M

	masses		=> {
	  set		=> \&set_item_masses
	},

	# R

	replicas	=> {
	  set		=> \&set_item_replicas
	},

	# T

	torsions	=> {
	  set		=> \&set_item_torsions
	},
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0
    }
  );

  $types->{notes} = [
    "Reference and parameter file names are assumed to have .csv extensions"
  ];

  return $types;
}


sub set_options {
  my $struct = shift(@_);

  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $types = EMC::Common::element($struct, "module");

  my $flag = EMC::Common::element($root, "global", "flag");
  my $field = EMC::Common::element($root, "fields", "field");

  # A

  if ($option eq "angle") {
    my $value = EMC::Math::eval($args);
    my $n = scalar(@{$args});
    $flag->{angle} = 1;
    if ($n==2) { $types->{angle_constants} = join(",", $value->[0,1]); }
    elsif ($n=5) {
      $types->{angles}->{join("\t", $args->[0,1,2])} = join(",", $value->[3,4]);
    }
    return 1;
  }
  if ($option eq "auto") {
    return $field->{dpd}->{auto} = EMC::Math::flag($args->[0]); }
  
  # B

  if ($option eq "bond") {
    my $value = EMC::Math::eval($args);
    my $n = scalar(@{$args});
    $flag->{bond} = 1; 
    if ($n==2) { $types->{bond_constants} = join(",", $value->[0,1]); }
    elsif ($n=4) {
      $types->{bond}->{join("\t", $args->[0,1])} = join(",", $value->[2,3]); }
  }

  # P

  if ($option eq "pair") {
    my $value = EMC::Math::eval($args);
    EMC::Hash::set(
      $line, $types->{pair_constants}, "real", "-1", [], @{$value});
    return $flag->{pair} = 1;
  }
  if ($option eq "parameters") {
    $types->{parameters}->{name} = $args->[0]; 
    return $types->{parameters}->{read} = 1;
  }
  if ($option eq "params") {
    reset_flags($types);
    return $field->{write} = EMC::Math::flag($args->[0]);
  }

  return undef;
}


sub set_functions {
  my $types = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($types, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Types::set_commands;
  $set->{context} = \&EMC::Types::set_context;
  $set->{defaults} = \&EMC::Types::set_defaults;
  $set->{options} = \&EMC::Types::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $types;
}


# set item

sub set_item_angles {
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

  my $angle =
     $module->{angle} = EMC::Common::hash($module, "angle");
  
  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$i++];

    if (scalar(@arg)==5) {
      $angle->{
	join("\t", @arg[0] lt @arg[2] ?
	  @arg[0,1,2] : @arg[2,1,0])} = join("\t", EMC::List::eval(@arg[3,4]));
    }
  }
  return $root;
}


sub set_item_bonds {
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

  my $bond =
     $module->{bond} = EMC::Common::hash($module, "bond");
  
  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$i++];

    if (scalar(@arg)==4) {
      $bond->{
	join("\t",
	  sort(@arg[0,1]))} = join("\t", EMC::List::eval(@arg[2,3]));
    }
  }
  return $root;
}


sub set_item_impropers {
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

  my $impropers =
     $module->{impropers} = EMC::Common::hash($module, "impropers");
  
  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$i++];

    if (scalar(@arg)==6) {
      @arg[0..3] = @arg[0,2,3,1] if (@arg[2]<@arg[1]);
      @arg[0..3] = @arg[0,3,1,2] if (@arg[3]<@arg[1]);
      @arg[0..3] = @arg[0,3,1,2] if (@arg[3]<@arg[2]);
      $impropers->{
	join("\t", @arg[0..3])} = join("\t", EMC::List::eval(splice(@arg, 4)));
    }
  }
  return $root;
}


sub set_item_replicas {
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

  my $replicas = 
     $module->{replicas} = EMC::Common::array($module, "replicas");
  
  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$i++];
    my $n = scalar(@arg);

    EMC::Message::error_line($line, "missing extra types\n") if ($n<2);
    push(@{$replicas}, [@arg]);
  }
  return $root;
}


sub set_item_torsions {
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

  my $torsions = 
     $module->{torsions} = EMC::Common::hash($module, "torsions");
  
  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$i++];

    if (scalar(@arg)>6) {
      if ((@arg[0]<@arg[3]) ||
	  (@arg[0]==@arg[3] && @arg[1]<@arg[2])) { @arg = reverse(@arg); }
      $torsions->{
	join("\t", @arg[0..3])} = join("\t", EMC::List::eval(splice(@arg, 4)));
    }
  }
  return $root;
}


# functions

sub create_replicas {
  my $types = shift(@_);

  return if (!defined($types->{references}));

  my $inverse = EMC::Common::hash($types, "inverse");
  my $references = EMC::Common::hash($types, "references");
  my $cutoff = EMC::Common::hash($types, "cutoff");
  my $mass = EMC::Common::hash($types, "mass");

  my $rm = ($references->{mass}>0 ? $references->{mass} : 1);
  my $rl = ($references->{length}>0 ? $references->{length} : 1);

  foreach (@{$types->{replicas}}) {
    my @arg = @{$_};
    next if (scalar(@arg)<2);
    my @a = split(":", shift(@arg));
    my $type = @a[0];
    my $factor = scalar(@a)>1 ? @a[1] : 1;
    @a = split(":", @arg[-1]);
    my $offset = defined($inverse->{@a[0]}) ? 0 : pop(@arg);
    my $fmass = defined($mass->{$type}) ? 0 : 1;
    my $norm = 1;
    my $n = 0;

    $inverse->{$type} = $types->{type}->{$type} = $type;
    $cutoff->{$type} = 0;
    $mass->{$type} = 0 if ($fmass);
    my @types;
    foreach (@arg) {
      my @a = split(":");
      my $t = shift(@a);
      if (!defined($inverse->{$t})) {
	EMC::Message::error("type $t is undefined.\n");
      }
      push(@types, $t);
      my $f = defined(@a[0]) ? eval(shift(@a)) : 1;
      my $flag = EMC::Math::flag(defined(@a[0]) ? shift(@a) : 1);
      my $src = $inverse->{$t};
      $f = 1 if ($f<=0);
      $norm = 0 if (!$flag);
      $cutoff->{$type} += $f*$cutoff->{$src};
      $mass->{$type} += $f*($references->{mass}>0 ? $mass->{$src} : 1) if ($fmass);
      $n += $f;
    }
    my $f = (scalar(@arg)>1 ? 1 : 0);
    my $text = ((!$n)||(!$norm) ? sprintf("%g\% ", 100*$n) : "")."replica of ";
    $n = 1 if ((!$n)||(!$norm));
    $references->{data}->{$type} = [
      $type, $type, 
      $fmass ? ($mass->{$type} /= $n)/$rm : $mass->{$type}/$rm, 
      ($cutoff->{$type} /= $n)/$rl,
      1, 0, 0,
      $text.($f ? "{" : "").join(", ", @types).($f ? "}" :"")];
  }
}


sub replica_settings {
  my $i;
  my %default;
  my %settings;
  my $type = shift(@_);
  my @df = ("", 1, 0, 1, 1);
  my @id = ("type", "fraction", "norm", "a", "r");
  $i = 0; foreach (@id) { $settings{$_} = @df[$i++]; }

  $i = 0;
  foreach (split(":")) {
    my @a = split("=");
    if (scalar(@a)==1) {
      $settings{@id[$i]} = @a[0];
    } else {
      if (!defined($default{@a[0]})) {
	EMC::Message::error("illegal keyword for replica '$type'.\n");
      }
      $settings{@a[0]} = @a[1];
    }
    last if (++$i==scalar(@id));
  }
  return %settings;
}


# field file

sub write_field {
  my $types = shift(@_);
  
  my $parameters = EMC::Common::element($types, "parameters");
  my $replace = EMC::Common::element($types, "root", "global", "replace");
  my $name = shift(@_);

  my $root = EMC::Common::element($types, "root");
  my $field = EMC::Common::element($root, "fields", "field");

  return if (!$field->{write});

  my %allowed = (dpd => 1, gauss => 1);

  if ((-e "$name.prm")&&!$replace->{flag}) {
    EMC::Message::warning(
      "\"$name.prm\" exists; use -replace flag to overwrite\n");
    return;
  }

  if (defined($field->{verbatim})) {
    EMC::Message::info("creating field parameter file \"$name.prm\"\n");
    EMCField::main("-quiet", "-input", $field->{verbatim}, $name);
    return;
  }

  return if (!($parameters->{flag} && defined($allowed{$field->{type}})));

  my $stream = EMC::IO::open("$name.prm", "w");

  EMC::Message::info("creating field parameter file \"$name.prm\"\n");
  write_field_header($stream, $types);
  write_field_masses($stream, $types);
  write_field_parameters($stream, $types);
  write_field_footer($stream, $types);

  close($stream);
}


sub write_field_header {
  my $stream = shift(@_);
  my $types = shift(@_);
  
  my $pair_constants = EMC::Common::element($types, "pair_constants");
  my $identity = EMC::Common::element($types, "root", "global", "identity");

  my $root = EMC::Common::element($types, "root");
  my $fields = EMC::Common::element($root, "fields");
  my $field = EMC::Common::element($root, "fields", "field");

  my $date = EMC::Common::date_full();
  my $t = Time::Piece::localtime();
  my $dpd = $field->{type} eq "dpd" ? 1 : 0; 
  my $gauss = $field->{type} eq "gauss" ? 1 : 0; 
  my $extra =
    $dpd ?  "\nGAMMA\t\t$pair_constants->{gamma}" : 
    $gauss ? "\nDIAMETER\t$pair_constants->{d}".
	     "\nR0\t\t$pair_constants->{r0}" : "";

  printf($stream
"#
#  ".uc($field->{type})." interaction parameters
#  to be used in conjuction with EMC v$identity->{emc}->{version} or higher
#  created by $identity->{script} v$identity->{version}, $identity->{date}
#  on $date
#

# Force field definition

ITEM	DEFINE

FFMODE		".uc($field->{type})."
FFTYPE		COARSE
VERSION		V$identity->{version}
CREATED		".$t->dmy()."
MIX		NONE
DENSITY		REDUCED
ENERGY		REDUCED
LENGTH		REDUCED
NBONDED		$fields->{flag}->{nbonded}
CUTOFF		$pair_constants->{cutoff}
DEFAULT		$pair_constants->{a}".$extra."
ANGLE		".(defined($types->{angles}) ? "WARN" : "IGNORE")."
TORSION		".(defined($types->{torsions}) ? "WARN" : "IGNORE")."
IMPROP		".(defined($types->{impropers}) ? "WARN" : "IGNORE")."

ITEM	END

");
}


sub write_field_masses {
  my $stream = shift(@_);
  my $types = shift(@_);

  my $references = EMC::Common::element($types, "references");

  my $root = EMC::Common::element($types, "root");
  my $field = EMC::Common::element($root, "fields", "field");

  printf($stream
"# Masses

ITEM	MASS

# type	mass	element	ncons	charge	comment\n\n".
($field->{dpd}->{auto} ?  "*	1.0000	*	2	0	Anything\n" : ""));
  
  my %ref; foreach (sort(keys(%{$references->{data}}))) {
    my @a = @{$references->{data}->{$_}}; shift(@a);
    @{$ref{shift(@a)}} = @a;
  }
  foreach (sort(keys(%ref))) {
    my $type = $_ eq "" ? "*" : $_;
    my @a = @{$ref{$_}};
    if ($type eq "*") {
      @a = ("*", "1", "*", "2", "0", "Anything") if (!scalar(@a));
    } else {
      @a[1] = eval(@a[1]);
    }
    printf($stream "%s\t%.4f\t%s\t%ld\t%g\t%s\n", $type,@a[1],$type,@a[3,4,-1]);
  }
  printf($stream
"
ITEM	END

# Typing equivalences

ITEM	EQUIVALENCE

# type	pair	bond	angle	torsion	improper

ITEM	END

");
}


sub write_field_parameters {
  my $stream = shift(@_);
  my $types = shift(@_);
  
  my $flag = EMC::Common::element($types, "flag");
  my $type = EMC::Common::element($types, "type");
  my $nonbond = EMC::Common::hash($types, "nonbond");
  my $bond = EMC::Common::hash($types, "bond");
  my $angle = EMC::Common::hash($types, "angle");

  my $parameters = EMC::Common::hash($types, "parameters");
  my $pdata = EMC::Common::hash($parameters, "data");
  
  my $root = EMC::Common::element($types, "root");
  my $field = EMC::Common::element($root, "fields", "field");

  if ($field->{dpd}->{auto}) {
    my $ptr = $types->{pair_constants};
    $nonbond->{"*\t*"} =  join("\t", $ptr->{a}, $ptr->{r}, $ptr->{gamma});
  }
  if (!defined($bond->{"*\t*"})) {
    $bond->{"*\t*"} = join("\t", split(",", $types->{bond_constants}));
  }
  if ($flag->{angle} && !defined($angle->{"*\t*\t*"})) {
    $angle->{"*\t*\t*"} = join("\t", split(",", $types->{angle_constants}));
  }
  foreach(sort(keys(%{$pdata}))) {
    my @t = split(":");
    next if (scalar(@t) != 2);
    my @a = @{$pdata->{$_}};
    my $flag = 0;
    foreach (@t) {
      $_ = defined($type->{$_}) ? $type->{$_} :
	   ($_ =~ m/\*/) ? $_ : "";
      last if (($flag = $_ eq "" ? 1 : 0));
    }
    next if ($flag);
    @t = reverse(@t) if (@t[1] lt @t[0]);
    $nonbond->{join("\t", @t)} = join("\t", @a);
  }

  write_field_item($stream, $types, "nonbond");
  write_field_item($stream, $types, "bond");
  write_field_item($stream, $types, "angle");
  write_field_item($stream, $types, "torsion");
  write_field_item($stream, $types, "improper");
}


sub write_field_item {
  my $stream = shift(@_);
  my $types = shift(@_);
  
  my $root = EMC::Common::element($types, "root");
  my $field = EMC::Common::element($root, "fields", "field");
  
  my $item = lc(shift(@_));
  my $Item = ucfirst($item);
  my %header = (
    nonbond => "type1\ttype2\t".(
      $field->{type} eq "dpd" ? "a\tcutoff\tgamma" :
      $field->{type} eq "gauss" ? "a\td\tr0\tcutoff" : "epsilon\tsigma"
    ),
    bond => "type1\ttype2\tk\tl0",
    angle => "type1\ttype2\ttype3\tk\ttheta0",
    torsion => "type1\ttype2\ttype3\ttype4\tk\tn\tdelta\t[...]",
    improper => "type1\ttype2\ttype3\ttype4\tk\tpsi0");
  my @n = (0,0);
  my $flag;

  foreach (keys(%{$types->{$item}})) { ++@n[($_ =~ m/\*/) ? 0 : 1]; }
  for ($flag=0; $flag<2; ++$flag) {
    next if (!@n[$flag]);
    printf($stream "# %s%s parameters\n\n", $Item, $flag ? "" : " wildcard");
    printf($stream "ITEM\t%s%s\n\n", uc($item), $flag ? "" : "_AUTO");
    printf($stream "# %s\n\n", $header{$item});
    foreach (sort(keys(%{$types->{$item}}))) {
      next if ((($_ =~ m/\*/) ? 0 : 1)^$flag);
      my @constants = split("\t",  ${$types->{$item}}{$_});
      printf($stream "%s", $_);
      foreach(@constants) { printf($stream "\t%.5g", $_); }
      printf($stream "\n");
    }
    printf($stream "\nITEM\tEND\n\n");
  }
}


sub write_field_footer {
  my $stream = shift(@_);
  my $types = shift(@_);

  printf($stream
"# Templates

ITEM	TEMPLATES

# name	smiles

ITEM	END
");
}

