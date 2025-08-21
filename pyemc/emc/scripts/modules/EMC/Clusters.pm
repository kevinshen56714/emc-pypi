#!/usr/bin/env perl
#
#  module:	EMC::Clusters.pm
#  author:	Pieter J. in 't Veld
#  date:	September 21, 2022.
#  purpose:	Clusters structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "clusters_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20220921	Inception of v1.0
#

package EMC::Clusters;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Clusters'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::Math;
use EMC::Types;
use File::Basename;

# defaults

$EMC::Clusters::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 21, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $clusters = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($clusters, $attr);
  set_defaults($clusters);
  set_commands($clusters);
  return $clusters;
}


# initialization

sub set_defaults {
  my $clusters = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $clusters = EMC::Common::attributes(
    $clusters,
    {
      # C

      check		=> {
	first		=> 1,
	mass		=> 0,
	volume		=> 0
      },
      cluster		=> {},

      # F

      fractions		=> [],
      flag		=> {
	mass		=> 0,
	mol		=> 1,
	number		=> 0,
	percolate	=> 0,
	volume		=> 0
      },

      # I

      id		=> {},
      import		=> {},
      import_default	=> {
	charges		=> -1,
	density		=> "mass",
	depth		=> -1,
	direction	=> "y",
	exclude		=> "box",
	flag		=> "rigid",
	focus		=> 1,
	formal		=> 1,
	guess		=> -1,
	map		=> 0,
	mode		=> undef,
	name		=> undef,
	ncells		=> "1:auto:auto",
	ntrials		=> 10000,
	percolate	=> -1,
	translate	=> 0,
	type		=> "surface",
	unwrap		=> 0
      },
      import_nparallel	=> 0,
      index		=> [],

      # M

      mol_mass		=> [],
      mol_volume	=> [],

      # N

      n			=> {
	clusters	=> 0,
	grafts		=> 0,
	regulars	=> 0
      },
      n_clusters	=> [],

      # S

      sampling		=> [],

      # T

      tighten		=> undef
    }
  );
  $clusters->{identity} = EMC::Common::attributes(
    EMC::Common::hash($clusters, "identity"),
    $EMC::Clusters::Identity
  );
  return $clusters;
}


sub transfer {
  my $clusters = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($clusters, "flag");
  my $context = EMC::Common::element($clusters, "context");
  my $cluster = EMC::Common::element($clusters, "cluster");
  
  EMC::Element::transfer(shift(@_),
    [\%::EMC::ClusterFlag,		\$clusters->{check}],
    [\@::EMC::Clusters,			\$clusters->{index}],
    [\@::EMC::ClusterSampling,		\$clusters->{sampling}],
    [\$::EMC::Flag{mass},		\$clusters->{flag}->{mass}],
    [\$::EMC::Flag{mol},		\$clusters->{flag}->{mol}],
    [\$::EMC::Flag{number},		\$clusters->{flag}->{number}],
    [\$::EMC::Flag{percolate},		\$clusters->{flag}->{percolate}],
    [\$::EMC::Flag{volume},		\$clusters->{flag}->{volume}],
    [\@::EMC::Fractions,		\$cluster->{name}->{fraction}],
    [\%::EMC::Import,			\$clusters->{import}],
    [\%::EMC::ImportDefault,		\$clusters->{import_default}],
    [\$::EMC::ImportNParallel,		\$clusters->{import_nparallel}],
    [\@::EMC::MolMass,			\$cluster->{name}->{mass}],
    [\@::EMC::MolVolume,		\$cluster->{name}->{volume}],
    [\@::EMC::NClusters,		\$cluster->{name}->{n}],
    [\$::EMC::Tighten,			\$clusters->{tighten}],
    [\%::EMC::XRef,			\$cluster->{name}->{id}],
  );
}


sub set_commands {
  my $clusters = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($clusters, "set");
  my $context = EMC::Common::element($clusters, "context");
  my $flag = EMC::Common::element($clusters, "flag");

  EMC::Options::set_command(
    $clusters->{commands} = EMC::Common::attributes(
      EMC::Common::hash($clusters, "commands"),
      {
	# M

	mass		=> {
	  comment	=> "assume mass fractions in chemistry file",
	  default	=> EMC::Math::boolean($flag->{mass}),
	  gui		=> ["boolean", "chemistry", "top", "standard"]},
	mol		=> {
	  comment	=> "assume mol fractions in chemistry file",
	  default	=> EMC::Math::boolean($flag->{mol}),
	  gui		=> ["boolean", "chemistry", "top", "standard"]},

	# N

	nparallel	=> {
	  comment	=> "set number of surface parallel repeat unit cells",
	  default	=> "auto",
	  gui		=> ["integer", "chemistry", "emc", "ignore"]},
	number		=> {
	  comment	=> "assume number of molecules in chemistry file",
	  default	=> EMC::Math::boolean($flag->{number}),
	  gui		=> ["boolean", "chemistry", "top", "standard"]},

	# P

	percolate	=> {
	  comment	=> "import percolating InsightII structure",
	  default	=> EMC::Math::boolean($flag->{percolate}),
	  gui		=> ["boolean", "chemistry", "emc", "advanced"]},

	# T

	tighten		=> {
	  comment	=> "set tightening of simulation box for imported structures",
	  default	=> $context->{tighten} eq "" ? "false" : $context->{tighten},
	  gui		=> ["real", "chemistry", "emc", "standard"]},

	# V

	volume		=> {
	  comment	=> "set recalculation based on molecular volume",
	  default	=> EMC::Math::boolean($flag->{volume}),
	  gui		=> ["boolean", "chemistry", "lammps", "advanced"]}
      }
    ),
    {
      set		=> \&EMC::Clusters::set_options
    }
  );
  $clusters->{items} = EMC::Common::attributes(
    EMC::Common::hash($clusters, "items"),
    {
      clusters	=> {
	chemistry	=> 1,
	environment	=> 1,
	order		=> 10,
	set		=> \&EMC::Clusters::set_item_clusters
      }
    }
  ); 
  return $clusters;
}


sub set_context {
  my $clusters = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));

  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($root, "global", "units");
  my $flag = EMC::Common::element($clusters, "flag");
  my $context = EMC::Common::element($clusters, "context");

  my $groups = EMC::Common::element($root, "groups");
  my $cluster = EMC::Common::element($clusters, "cluster");
  my $polymer = EMC::Common::element($root, "polymers", "polymer");

  $clusters->{tighten} = (
    $field->{type} eq "dpd" ? 1.0 : 
    $field->{type} eq "gauss" ? 1.0 : 3.0) if (!defined($clusters->{tighten}));
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $clusters = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($clusters, "flag");
  my $set = EMC::Common::element($clusters, "set");

  # M

  if ($option eq "mass") { 
    if (($flag->{mass} = EMC::Math::flag($args->[0]))) {
      $flag->{mol} = $flag->{number} = $flag->{volume} = 0;
    }
    return $flag->{mass};
  }
  if ($option eq "mol") { 
    if (($flag->{mol} = EMC::Math::flag($args->[0]))) {
      $flag->{mass} = $flag->{number} = $flag->{volume} = 0;
    }
    return $flag->{mol};
  }

  # N

  if ($option eq "nparallel") {
    my $value = EMC::Math::eval($args->[0])->[0];
    return $clusters->{import_nparallel} = $value<1 ? 0 : $value;
  }
  if ($option eq "number") {
    if (($flag->{number} = EMC::Math::flag($args->[0]))) {
      $flag->{mass} = $flag->{mol} = $flag->{volume} = 0;
    }
    return $flag->{number};
  }

  # P

  if ($option eq "percolate") {
    return $flag->{percolate} = EMC::Math::flag($args->[0]); }

  # T

  if ($option eq "tighten") { 
    if ($args->[0] eq "false" || $args->[0] eq "-") {
      $clusters->{tighten} = undef;
    } else {
      my $value = EMC::Math::eval($args->[0])->[0];
      $clusters->{tighten} = $value<0 ? undef : $value;
    }
    return 1; #$context->{tighten};
  }

  # V

  if ($option eq "volume") { 
    if (($flag->{volume} = EMC::Math::flag($args->[0]))) {
      $flag->{mass} = $flag->{mol} = $flag->{number} = 0;
    }
    return $flag->{volume};
  }
  
  return undef;
}


sub set_functions {
  my $clusters = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($clusters, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Clusters::set_commands;
  $set->{context} = \&EMC::Clusters::set_context;
  $set->{defaults} = \&EMC::Clusters::set_defaults;
  $set->{options} = \&EMC::Clusters::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $clusters;
}


# set item

sub set_item_clusters {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $option = EMC::Common::element($struct, "option");
  my $module = EMC::Common::element($struct, "module");
  my $emc = EMC::Common::element($struct, "parent");

  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $iline = 0;

  foreach (@{$data}) {
    $struct->{args} = $_;
    $struct->{line} = $lines->[$iline++];
    if (scalar(@{$_})<3) {
      EMC::Message::error_line(
	$struct->{line}, "too few cluster entries (< 3)\n");
    }
    if ($_->[1] eq "import") {
      set_import($struct);
    } else {
      set_cluster($struct);
    }
  }
  return $root;
}


# functions

sub check {					# <= cluster_flag
  my $clusters = shift(@_);
  my $check = $clusters->{check};
  my $line = shift(@_);
  my $name = shift(@_);
  my $mass = shift(@_);
  my $volume = shift(@_);

  if ($check->{first}) {
    $check->{mass} = $mass ne "" ? 1 : 0;
    $check->{volume} = $volume ne "" ? 1 : 0;
    $check->{first} = 0;
  } else {
    if (($mass ne "" ? 1 : 0)^$check->{mass}) {
      EMC::Message::error_line(
	$line, "inconsistent mass entry for cluster '$name'\n");
    }
    if (($volume ne "" ? 1 : 0)^$check->{volume}) {
      EMC::Message::error_line(
	$line, "inconsistent volume entry for cluster '$name'\n");
    }
  }
}


sub set_cluster {
  my $struct = shift(@_);
  
  my $root = EMC::Common::element($struct, "root");
  my $global = EMC::Common::element($root, "global");
  my $flag = EMC::Common::element($global, "flag");
  my $field = EMC::Common::element($root, "fields", "field");

  my $clusters = EMC::Common::element($struct, "module");
  my $cluster = EMC::Common::hash($clusters, "cluster");
  my $emc = EMC::Common::element($struct, "parent");

  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $line = EMC::Common::element($struct, "line");
  
  my @arg = ref($args) eq "ARRAY" ? @{$args} : ();
  my $name = EMC::EMC::check_name($emc, shift(@arg), $line, 1);
  my $group_name = EMC::Common::convert_name(shift(@arg))->[0];
  my $fraction = shift(@arg);
  my $mass = shift(@arg);
  my $volume = shift(@arg);

  if (!defined($clusters->{index})) {
    $clusters->{index} = [];
  }
  if (defined($cluster->{$name})) {
    $cluster = $cluster->{$name};
  } else {
    $cluster = $cluster->{$name} = {};
    $cluster->{id} = scalar(@{$clusters->{index}});
    push(@{$clusters->{index}}, $name);
    push(@{$clusters->{mol_mass}}, $mass);
  }
  check($clusters, $line, $name, $mass, $volume);

  # check mass
  
  if (defined($mass) && !$flag->{mass_entry}) {
    EMC::Message::error_line(
      $line, "mass entry not allowed for field '$field->{type}'\n");
  }

  # check group

  my $emc = EMC::Common::element($root, "emc");
  my $groups = EMC::Common::element($emc, "groups");
  my $group = EMC::Common::element($groups, "group");
  my $fpoly = EMC::Polymers::is_polymer($group_name);

  if ($fpoly ? 0 : !defined($group->{$group_name})) {
    my $added = EMC::Common::element($root, "global", "flag", "expert");

    if ($flag) {
      $flag = EMC::Groups::add_group($root, $group_name, $line);
    }
    if (!$flag) {
      EMC::Message::expert_line($line, "undefined group '$group_name'\n");
    }
  }

  my $profiles = EMC::Common::element($global, "profiles");
  my $profile_flag = EMC::Common::element($profiles, "flag");
  my $profile_check = EMC::Common::element($profiles, "check");

  if ($profile_flag->{density} ? defined($profile_check->{$name}) : 0) {
    EMC::Message::error_line(
      $line, "cluster name '$name' already taken by a profile\n");
  }
  $profile_check->{$name} = 1 if ($profile_flag->{density});

  $cluster = {
    name => $name,
    id => $cluster->{id},
    fraction => $fraction,
    mass => $mass,
    volume => $volume,
    type => $fpoly ? $group_name : "cluster",
    n => $fpoly ? 1 : $group->{$group_name}->{nextra}+1,
    profile => $profile_flag->{density} ? 1 : 0
  };
  $cluster->{group} = $group->{$group_name} if (!$fpoly);

  my $polymers = $emc->{polymers} = EMC::Common::hash($emc, "polymers");
  my $polymer = $polymers->{polymer} = EMC::Common::hash($polymers, "polymer");

  if ($fpoly && EMC::Common::element($polymer, $name, "options", "group")) {
    EMC::Message::error_line(
      $line, "Group polymer already exists with name '$name'\n");
  }
  if (!defined($polymer->{$name})) {
    $polymer = $polymer->{$name} = {};
    if ($fpoly) {
      $polymers->{id}->{$name} = $cluster->{id};
      $polymer->{options}->{cluster} = 1;
      $polymer->{options}->{type} = $fpoly;
      $polymer->{options}->{polymer} = $group_name;
    } else {
      $polymer->{options}->{type} = 0;
      $polymer->{options}->{polymer} = undef;
      $polymer->{data} = [{
	fraction => 1,
	groups => [$group_name],
	nrepeats => [1],
	weights => [1]
      }];
    }
  } else {
    $polymer = $polymer->{name};
    $polymers->{id}->{$name} = $cluster->{id};		# from $:: EMC :: XRef
    if ($fpoly) {
      $polymer->{options}->{type} = $cluster->{type};
    }
  }
  if (EMC::Common::element($polymer, "data")) {
    my $group = $polymer->{data}->[0]->{groups}->[0];
    my $fgraft = $groups->{group}->{$group}->{flag}->{graft};

    $cluster->{flag}->{graft} = 1 if ($fgraft);
    $cluster->{flag}->{regular} = 1 if (!$fgraft);
  } else {
    $cluster->{flag}->{regular} = 1;
  }
  $clusters->{cluster}->{$name} = $cluster;
}


sub set_import {
  my $struct = shift(@_);
  
  my $root = EMC::Common::element($struct, "root");
  my $global = EMC::Common::element($root, "global");
  my $flag = EMC::Common::element($global, "flag");
  my $fields = EMC::Common::element($root, "fields");
  my $field = EMC::Common::element($fields, "field");

  my $clusters = EMC::Common::element($struct, "module");
  my $cluster = EMC::Common::element($clusters, "cluster");
  my $emc = EMC::Common::element($clusters, "parent");
  my $context = EMC::Common::element($emc, "context");
  my $flag = EMC::Element::deep_copy(
    EMC::Common::element($clusters, "import_default"));

  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $line = EMC::Common::element($struct, "line");

  my @arg = @{$args};
  my $name = EMC::EMC::check_name($emc, shift(@arg), $line, 1);
  my $group = EMC::Common::convert_name(shift(@arg))->[0];
  my $import = $clusters->{import} = {};

  my %mode = (
    ".emc" => "emc", ".car" => "insight", ".mdf" => "insight",
    ".pdb" => "pdb", ".psf" => "pdb"
  );
  my @order = (
    "ncells", "name", "mode", "type", "flag", "density", "focus",
    "tighten", "ntrials", "periodic", "field", "exclude", "depth",
    "percolate", "unwrap", "guess", "charges", "formal", "translate",
    "map", "debug"
  );
  my %allowed = (
    charges => {charges => 1},
    debug => {debug => 1},
    density => {mass => 1, number => 1},
    depth => {depth => 1},
    direction => {x => 1, y => 1, z => 1},
    exclude => {box => 1, contour => 1, none => 1},
    field => {field => 1},
    flag => {fixed => 1, rigid => 1, mobile => 1},
    focus => {focus => 1},
    formal => {formal => 1},
    guess => {guess => 1},
    map => {map => 1},
    mode => {get => 1, emc => 1, insight => 1, pdb => 1},
    name => {name => 1},
    ncells => {ncells => 1},
    ntrials => {ntrials => 1},
    periodic => {x => 1, y => 1, z => 1},
    tighten => {tighten => 1},
    percolate => {percolate => 1},
    translate => {translate => 1},
    type => {
      crystal => 1, surface => 1, tube => 1, structure => 1, system => 1},
    unwrap => {unwrap => 1}
  );
  my %flags = (debug => 1, focus => 1, formal => 1, guess => 1, unwrap => 1);
  my @ncells = split(":", $flag->{ncells});
  my $i = 0;
 
  $flag->{density} = "number" if ($field->{type} eq "dpd");
  foreach (@arg) {
    my @a = split("=");
    if (scalar(@a)==1) {
      if ($i==scalar(@order)) {
	EMC::Message::error_line($line, "too many arguments for import\n");
      } else {
	if ($i<2) {
	  $flag->{@order[$i++]} = @a[0];
	} elsif (!defined(${$allowed{@order[$i]}}{@a[0]})) {
	  EMC::Message::error_line($line, 
	    "import @order[$i] option '@a[0]' not allowed\n");
	} else {
	  $flag->{@order[$i++]} = @a[0];
	}
      }
    } else {
      if (!defined($allowed{@a[0]})) {
	EMC::Message::error_line($line, "import id '@a[0]' unknown\n");
      } elsif (defined(${$allowed{@a[0]}}{@a[0]})) {
	$flag->{@a[0]} = @a[1];
      } elsif (!defined(${$allowed{@a[0]}}{@a[1]})) {
	EMC::Message::error_line(
	  $line, "import @a[0] option '@a[1]' not allowed\n");
      } else {
	$flag->{@a[0]} = @a[1];
      }
    }
  }

  $i = 0;
  foreach (split(":", $flag->{ncells})) {
    @ncells[$i++] = $global->{flag}->{expert}||($_ eq "auto") ? $_ : eval($_);
    last if ($i==3); }
  delete($flag->{n});
 
  if ($flag->{name} eq "") {
    EMC::Message::error_line($line, "import filename not set\n");
  }

  my $filename = $flag->{name}; delete($flag->{name});
  my ($tmp, $path, $suffix) = File::Basename::fileparse($filename, '\.[^\.]*');
  if ($flag->{mode} eq "") {
    $suffix =~ s/(.*)"$/$1/g;
    if ($suffix eq ".gz") {
      ($tmp, $tmp, $suffix) = File::Basename::fileparse($tmp, '\.[^\.]*');
    }
    if (!defined($mode{$suffix})) {
      EMC::Message::error_line($line, "unsupported suffix '$suffix'\n");
    }
    $flag->{mode} = $mode{$suffix};
  }

  my @fields;
  foreach (split(":", $flag->{field})) {
    my $id = EMC::Fields::id($fields, $line, $_)->[0];
    push(@fields, $id);
  }

  my @periodic = 
      $flag->{type} eq "crystal" ? (1, 1, 1) :
      $flag->{type} eq "surface" ? (0, 1, 1) :
      $flag->{type} eq "tube" ? (0, 0, 1) :
      $flag->{type} eq "structure" ? (0, 0, 0) :
      $flag->{type} eq "system" ? (1, 1, 1) : (0, 0, 0);

  if ($flag->{type} eq "system" || $flag->{type} eq "structure") {
    $flag->{unwrap} = 1;
  }
  foreach (keys(%{$flag})) {
    if ($_ eq "ncells") {
      my @n = @ncells;
      my @m = split(":", $flag->{$_});
      if (scalar(@m)==1) {
	@n[0] = @m[0];
      } elsif (scalar(@m)==3) {
	my %index = (x => 0, y => 1, z => 2);
	@n[0] = @m[$index{$global->{direction}->{x}}];
	@n[1] = @m[$index{$global->{direction}->{y}}];
	@n[2] = @m[$index{$global->{direction}->{z}}];
      } else {
	EMC::Message::spot("{", join(", ", @m), "}\n");
	EMC::Message::error_line(
	  $line, "ncells can only have 1 or 3 entries\n");
      }
    } elsif ($_ eq "ntrials") {
      $import->{$_} = $flag->{$_}>0 ? $flag->{$_} : 1;
    } elsif ($_ eq "periodic") {
      my %index = (x => 0, y => 1, z => 2);
      foreach (split(":", $flag->{$_})) { @periodic[$index{$_}] = 1; }
    } elsif ($_ eq "tighten") {
      my $value = 
	$flag->{$_} eq "" || 
	$flag->{$_} eq "true" ? $context->{tighten} : eval($flag->{$_});
      if ($value eq "") {
	if (!$global->{flag}->{expert}) {
	  EMC::Message::error_line(
	    $line, "option tighten does not have a value\n");
	}
	$value = $flag->{$_};
      }
      $import->{$_} = $value if ($flag->{$_} ne "false");
    } elsif (defined($flags{$_})) {
      $import->{$_} = $flag->{$_}<0 ? -1 : EMC::Math::flag($flag->{$_});
    } else {
      $import->{$_} = $flag->{$_};
    }
  }
  $import->{periodic} = [@periodic];
  for ($i=0; $i<scalar(@ncells); ++$i) {
    if ($i && @ncells[$i] eq "auto") {
      next if ($import->{type} ne "crystal");
      @ncells[$i] = 1;
    }
    if (!$global->{flag}->{expert} && @ncells[$i]<1) {
      EMC::Message::error("n < 1 for import '$name' in line $line of input\n");
    }
  }
  if ($filename eq "") {
    EMC::Message::error_line($line, "missing file name for import '$name'\n"); }
  
  $import->{name} = $name;
  $import->{field} = [@fields];
  $import->{filename} = $filename;
  $import->{nx} = @ncells[0];
  $import->{ny} = @ncells[1];
  $import->{nz} = @ncells[2];
  if ($import->{depth}<0) {
    $import->{depth} = $context->{depth};
  }
  if ($global->{flag}->{crystal}<0) {
    $import->{crystal} = $import->{type} eq "crystal" ? 1 : 0;
  } else {
    $import->{crystal} = $global->{flag}->{crystal};
  }
}
