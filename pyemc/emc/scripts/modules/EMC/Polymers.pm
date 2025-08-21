#!/usr/bin/env perl
#
#  module:	EMC::Polymers.pm
#  author:	Pieter J. in 't Veld
#  date:	September 21, 2022.
#  purpose:	Polymers structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "polymers_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#    id			HASH	reference to cluster ID
#    index		ARRAY	list of polymer IDs
#    
#    polymer		HASH of ARRAY
#      0		VALUE	fraction
#      1		VALUE	nrepeats
#      2		ARRAY	contributing groups
#      3		ARRAY	weights of groups
#      4		STRING	either 'cluster' or 'group'
#
#  notes:
#    20220921	Inception of v1.0
#

package EMC::Polymers;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Polymers'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::Math;


# defaults

$EMC::Polymers::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 21, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $polymers = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($polymers, $attr);
  set_defaults($polymers);
  set_commands($polymers);
  return $polymers;
}


# initialization

sub set_defaults {
  my $polymers = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $context = EMC::Common::hash($polymers, "context");
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $polymers = EMC::Common::attributes(
    $polymers,
    {
      id		=> {},
      index		=> [],
      polymer		=> {}
    }
  );
  $polymers->{flag} = EMC::Common::attributes(
    EMC::Common::hash($polymers, "flag"),
    {
      bias		=> "none",
      cluster		=> undef,
      connects		=> [],
      fraction		=> "number",
      link		=> "-",
      niterations	=> -1,
      order		=> "list",
      polymer		=> undef,
      type		=> undef,
      ignore		=> ["cluster", "connects", "polymer", "type"]
    }
  );
  $polymers->{context} = EMC::Common::attributes(
    $context,
    {
      flory		=> {
	avg		=> 1,
	cut		=> 1e-5,
	min		=> 1,
	max		=> 1e5
      },
      poisson		=> {
	avg		=> 1,
	cut		=> 1e-5,
	min		=> 1,
	max		=> 1e5
      }
    }
  );
  $polymers->{identity} = EMC::Common::attributes(
    EMC::Common::hash($polymers, "identity"),
    $EMC::Polymers::Identity
  );
  return $polymers;
}


sub transfer {
  my $polymers = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($polymers, "flag");
  my $context = EMC::Common::element($polymers, "context");
  
  EMC::Element::transfer(shift(@_),
    [\%::EMC::Polymer,			\$polymers->{polymer}],
    [\%::EMC::PolymerFlag,		\$polymers->{flag}],
    [\%::EMC::Polymers,			\$polymers->{id}],
  );
}


sub set_context {
  my $polymers = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $units = EMC::Common::element($root, "global", "units");
  my $flag = EMC::Common::element($polymers, "flag");
  my $context = EMC::Common::element($polymers, "context");
}


sub set_commands {
  my $polymers = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($polymers, "set");
  my $context = EMC::Common::element($polymers, "context");
  my $flag = EMC::Common::element($polymers, "flag");

  $flag->{cluster} = EMC::Math::boolean($flag->{cluster});
  EMC::Options::set_command(
    $polymers->{commands} = EMC::Common::attributes(
      EMC::Common::hash($polymers, "commands"),
      {
	# P

	polymer		=> {
	  comment	=> "default polymer settings for groups",
	  default	=> EMC::Hash::text($flag, "string"),
	  gui		=> ["list", "chemistry", "top", "ignore"]},
	polymer_link	=> {
	  comment	=> "set polymer linking default",
	  default	=> $flag->{link},
	  gui		=> ["list", "chemistry", "top", "ignore"]},
	polymer_niters	=> {
	  comment	=> "number of iterations for polymer construction",
	  default	=> $flag->{niterations},
	  gui		=> ["list", "chemistry", "top", "ignore"]},
	polymer_flory	=> {
	  comment	=> "set Flory-Schulz distribution defaults",
	  default	=> EMC::Hash::text($context->{flory}),
	  gui		=> ["list", "chemistry", "top", "ignore"]},
	polymer_poisson	=> {
	  comment	=> "set Poisson distribution defaults",
	  default	=> EMC::Hash::text($context->{poisson}),
	  gui		=> ["list", "chemistry", "top", "ignore"]}
      }
    ),
    {
      set		=> \&EMC::Polymers::set_options
    }
  );
  $flag->{cluster} = EMC::Math::flag($flag->{cluster});
  $polymers->{items} = EMC::Common::attributes(
    EMC::Common::hash($polymers, "items"),
    {
      polymers	=> {
	chemistry	=> 1,
	environment	=> 1,
	order		=> 1,
	set		=> \&set_item_polymers
      }
    }
  );  
  return $polymers;
}


sub check_bounds {
  my $hash = shift(@_);
  my $line = shift(@_);
  my $name = shift(@_);
  my $bound = {
    avg => {low => 1, high => undef},
    min => {low => 1, high => undef},
    max => {low => 1, high => undef},
    cut => {low => 0, high => 1, equal => 1}
  };

  foreach (keys(%{$hash}))
  {
    next if (!defined($bound->{$_}));
    my $b = $bound->{$_};
    if (defined($b->{equal})) {
      if (defined($b->{low}) && $hash->{$_}<=$b->{low}) {
	EMC::Message::error_line($line, "$name $_ <= $b->{low}\n");
      } elsif (defined($b->{high}) && $hash->{$_}>=$b->{high}) {
	EMC::Message::error_line($line, "$name $_ >= $b->{high}\n");
      }
    } else {
      if (defined($b->{low}) && $hash->{$_}<$b->{low}) {
	EMC::Message::error_line($line, "$name $_ < $b->{low}\n");
      } elsif (defined($b->{high}) && $hash->{$_}>$b->{high}) {
	EMC::Message::error_line($line, "$name $_ > $b->{high}\n");
      }
    }
  }
  if (defined($hash->{min}) && defined($hash->{max})) {
    if ($hash->{min}>$hash->{max}) {
      EMC::Message::error_line($line, "min $hash->{min} > max $hash->{max}\n");
    }
  }
  return $hash;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $polymers = EMC::Common::element($struct, "module");
  my $context = EMC::Common::element($polymers, "context");
  my $flag = EMC::Common::hash($polymers, "flag");
  my $set = EMC::Common::element($polymers, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  # P

  if ($option eq "polymer") {
    return EMC::Polymers::set_list($line, $flag, @{$args}); }
  if ($option eq "polymer_link") {
    return $flag->{link} = set_link($line, $args->[0]); }
  if ($option eq "polymer_niters") {
    return $flag->{niterations} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "polymer_flory") {
    EMC::Hash::set($line, $context->{flory}, "real", "", [], @{$args});
    return check_bounds($context->{flory}, $line, "Flory-Schulz");
  }
  if ($option eq "polymer_poisson") {
    EMC::Hash::set($line, $context->{poisson}, "real", "", [], @{$args});
    return check_bounds($context->{poisson}, $line, "Poisson");
  }
  return undef;
}


sub set_functions {
  my $polymers = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($polymers, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Polymers::set_commands;
  $set->{context} = \&EMC::Polymers::set_context;
  $set->{defaults} = \&EMC::Polymers::set_defaults;
  $set->{options} = \&EMC::Polymers::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $polymers;
}


sub set_link {
  my $line = shift(@_);
  my $text = shift(@_);
  my $type = shift(@_);
  my $allowed = {
    random => 1, sequential => 1, directional => 1, consecutive => 1};
  my $default = {
    random => "random", alternate => "directional", block => "directional"};

  if (defined($text) ? $text eq "-" : 1) {
    if (!defined($default->{$type})) {
      EMC::Message::error_line($line, "cannot determine default link option\n");
    }
    return $default->{$type};
  } elsif (!defined($allowed->{$text})) {
    EMC::Message::error_line($line, "unallowed link option \'$text\'\n");
  }
  return $text;
}


sub set_list {					# <= set_list_polymer
  my $line = shift(@_);
  my $hash = shift(@_);
  my %allowed = (
    bias => {none => 1, binary => 1, accumulative => 1},
    fraction => {number => 1, mass => 1},
    order => {list => 1, random => 1}
  );

  EMC::Hash::set($line, $hash, "string", "", [], @_);
  foreach (sort(keys(%allowed))) {
    if (!defined($allowed{$_}->{$hash->{$_}})) {
      EMC::Message::error_line($line, "illegal option for keyword '$_'\n");
    }
  }
  $hash->{cluster} = EMC::Math::flag($hash->{cluster});
  return $hash;
}


# functions

sub is_polymer {
  my $text = shift(@_);
  my $allowed = {
    alternate => 1, block => 2, random => 3, sequence => 4};

  return defined($allowed->{$text}) ? $allowed->{$text} : 0;
}


sub func_flory {
  my $default = shift(@_);
  my $var = shift(@_);
  my $line = shift(@_);
  my $fractions = [];
  
  foreach (keys(%{$default})) {
    $var->{$_} = $default->{$_} if (!defined($var->{$_}));
  }
  check_bounds($var, $line, "Flory-Schulz");

  my $p = exp(-2.0/$var->{avg});
  my $cut = $var->{cut};
  my $min = $var->{min};
  my $max = $var->{max};
  my $f = log($p)**2;
  my $l = 1;

  while (1) {
    $f *= $p;
    if ($l >= $min) {
      push(@{$fractions}, {l => $l, fraction => $f*$l}) if ($f >= $cut);
      last if ($f < $cut);
    }
    last if ($l >= $max);
    ++$l;
  }
  return $fractions;
}


sub func_poisson {
  my $default = shift(@_);
  my $var = shift(@_);
  my $line = shift(@_);
  my $fractions = [];
  
  foreach (keys(%{$default})) {
    $var->{$_} = $default->{$_} if (!defined($var->{$_}));
  }
  check_bounds($var, $line, "Poisson");

  my $lavg = $var->{avg};
  my $cut = $var->{cut};
  my $min = $var->{min};
  my $max = $var->{max};
  my $exp = exp(-$lavg);
  my $l = 1;
  my $a = 1;

  while (1) {
    $a *= $lavg/$l;
    if ($l >= $min) {
      my $f = $exp*$a;
      push(@{$fractions}, {l => $l, fraction => $f}) if ($f >= $cut);
      last if ($f < $cut);
    }
    last if ($l >= $max);
    ++$l;
  }
  return $fractions;
}


sub function {
  my $context = shift(@_);
  my $attr = shift(@_);
  my $line = shift(@_);
  my $name = $attr->{name};
  my $function = {flory => \&func_flory, poisson => \&func_poisson};

  if (!defined($function->{$attr->{name}})) {
    EMC::Message::error_line($line,
      "illegal polymer distribution function '$name'\n");
  }
  return $function->{$name}->($context->{$name}, $attr, $line);
}


sub attributes {
  my @arg = split(":", shift(@_));
  my $name = shift(@arg);
  my $attr = EMC::Hash::variables(split(",", shift(@arg)));

  $attr->{name} = $name;
  return $attr;
}


# ITEM POLYMERS
#   line 1: 	name,fraction[,mass[,volume]]
#   fraction -> mole, mass, or volume fraction
#   line 2:	fraction,group,n[,group,n[,...]]
#   fraction -> mole fraction
#   line ...:	same as line 2

sub set_item_polymers {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $option = EMC::Common::element($struct, "option");
  my $polymers = EMC::Common::element($struct, "module");
  my $context = EMC::Common::element($polymers, "context");
  my $emc = EMC::Common::element($polymers, "parent");
  my $cluster = EMC::Common::element($emc, "clusters", "cluster");
  my $flag = EMC::Common::element($root, "global", "flag");

  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $options = {};
  my $iline = 0;
  my $polymer_data;
  my $polymer;
  my $name;

  my $allowed_link = {
    random => 1, sequential => 1, directional => 1};

  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$iline++];

    if (scalar(@arg)==1||				# first line
        defined($polymers->{polymer}->{@arg[0]})) {
      
      $options = EMC::Element::deep_copy($polymers->{flag});
      $name = EMC::EMC::check_name($emc, shift(@arg), $line, 2);
      $polymer = EMC::Common::hash($polymers, "polymer", $name);
      EMC::Polymers::set_list($line, $options, @arg);
      $options->{link} = set_link(
	$line, $options->{link}, $polymer->{options}->{polymer});
      if (ref($options->{connects}) eq "") {
	$options->{connects} = [sort(split(":", $options->{connects}))];
      }
      if (!defined($polymer->{options}->{type})) {
	EMC::Message::error_line(
	  $line, "undefined polymer \'$name\'\n") if (!$flag->{expert});
      } elsif (!$polymer->{options}->{type}) {
	EMC::Message::expert_line($line, "\'$name\' is not a polymer\n");
	undef($polymer);
      } else {
	$polymer->{data} = $polymer_data = [];
	$polymer->{options} = EMC::Common::attributes(
	  $options, $polymer->{options});
	if (defined($cluster->{$name})) {
	  $polymer->{cluster} = $cluster->{$name};
	}
      }
    } elsif (defined($polymer)) {			# subsequent lines
      my $fraction = shift(@arg);
      my $attr = attributes($fraction);
      my $mask = defined($attr->{mask}) ?
	EMC::Math::eval($attr->{mask})->[0] : undef;
      my $fractions = 
	EMC::Math::number_q($fraction = $attr->{name}) ? 
	[{l => 1, fraction => $fraction}] :
       	function($context, $attr, $line);

      foreach (@{$fractions}) {
	my $fraction = $_->{fraction};
	my $l = $_->{l};
	my $groups = [];
	my $nrepeats = [];
	my $weights = [];

	push(
	  @{$polymer->{data}}, {
	    fraction => $fraction,
	    groups => $groups,
	    mask => $mask,
	    nrepeats => $nrepeats,
	    weights => $weights
	  }
	);
	my @tmp = @arg;
	while (scalar(@tmp)) {
	  my $name = shift(@tmp);
	  my $n = shift(@tmp);
	  my @a = split("=", $name);
	  my @t = split(":", @a[0]);

	  $n = $l if ($n eq "\$\@");
	  foreach(@t[0]) {
	    EMC::EMC::check_name($emc, $_, $line, 0);
	  }
	  push(@{$nrepeats}, $flag->{expert} ? $n : EMC::Math::eval($n)->[0]);
	  push(@{$groups}, @a[0]);
	  if (!$flag->{expert} && !(substr($n,0,1) =~ m/[0-9]/)) {
	    EMC::Message::error_line($line, "number expected\n");
	  }
	  $n = scalar(@t);
	  if (scalar(@a)>1) {
	    @t = split(":", @a[1]);
	    if (scalar(@t)!=$n) {
	      EMC::Message::error_line(
		$line, "number of groups and weights are not equal\n");
	    }
	  } else {
	    foreach(@t) { $_ = 1; }
	  }
	  push(@{$weights}, join(":", @t));
	}
      }
    }
  }
  return $root;
}

