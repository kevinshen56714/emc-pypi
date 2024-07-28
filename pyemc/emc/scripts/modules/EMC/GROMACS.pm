#!/usr/bin/env perl
#
#  module:	EMC::GROMACS.pm
#  author:	Pieter J. in 't Veld
#  date:	May 2, 2024.
#  purpose:	GROMACS structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2024 Pieter J. in 't Veld
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

  $gromacs->{context} = EMC::Common::attributes(
    EMC::Common::hash($gromacs, "context"),
    {
      pdamp		=> 1000,
      tdamp		=> 100,
      trun		=> 1e8
    }
  );
  $gromacs->{flag} = EMC::Common::attributes(
    EMC::Common::hash($gromacs, "flag"),
    {
      atom		=> "index",
      compress		=> 0,
      fixed		=> 1,
      hexadecimal	=> 0,
      parameters	=> 1,
      pbc		=> 1,
      residue		=> "index",
      rigid		=> 1,
      segment		=> "index",
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

    $indicator."segment"	=> {
      comment		=> "set segment name behavior",
      default		=> $flag->{segment},
      gui		=> ["option", "chemistry", "emc", "advanced", "detect,index,series"]},

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
    $indicator."trun"	=> {
      comment		=> "set run time",
      default		=> $context->{trun},
      gui		=> ["string", "chemistry", "gromacs", "advanced"]}
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
      $gromacs->{items},
      {
      }
    ),
    {
      set		=> \&EMC::GROMACS::set_items
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
    return $flag->{atom} = set_flag("atom", $args->[0], $line); }

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
  
  # P

  if ($option eq $indicator."pdamp") {
    $defined->{pdamp} = 1;
    return $context->{pdamp} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."parameters") {
    return $flag->{parameters} = EMC::Math::flag($args->[0]); }
  if ($option eq $indicator."pbc") {
    return $flag->{pbc} = EMC::Math::flag($args->[0]); }

  # R

  if ($option eq $indicator."rank") {
    return $flag->{rank} = EMC::Math::flag($args->[0]); }
  if ($option eq $indicator."residue") {
    return $flag->{residue} = set_flag("residue", $args->[0], $line); }
  if ($option eq $indicator."rigid") {
    return $flag->{rigid} = EMC::Math::flag($args->[0]); }

  # S

  if ($option eq $indicator."segment") {
    return $flag->{segment} = set_flag("segment", $args->[0], $line); }

  # T

  if ($option eq $indicator."tdamp") {
    $defined->{tdamp} = 1;
    return $context->{tdamp} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq $indicator."tequil") {
    $defined->{tequil} = 1;
    return $context->{tequil} = EMC::Math::eval($args->[0])->[0]; }
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
  #$write->{job} = \&EMC::GROMACS::write_job;
  #$write->{script} = \&EMC::GROMACS::write_script;

  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $gromacs;
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
  printf($stream " rank -> ".EMC::Math::boolean($flag->{rank}).",");
  printf($stream " cut -> ".EMC::Math::boolean($flag->{cut}).",");
  printf($stream "\n\t\t  ");
  printf($stream " fixed -> ".EMC::Math::boolean($flag->{fixed}).",");
  printf($stream " rigid -> ".EMC::Math::boolean($flag->{rigid}).",");
  #printf($stream "\n\t\t  ");
  printf($stream " parameters -> ".EMC::Math::boolean($flag->{parameters}));
  printf($stream "};\n");
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


sub read {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $kconstraint = defined($attr->{kconstraint}) ? $attr->{kconstraint} : 20000;
  my $gromacs = defined($attr->{gromacs}) ? $attr->{gromacs} : {};
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
    impropers => {item => "improper", func => \&read_bonded},
    pairs => {item => "nonbond", func => \&read_pairs},
    pairs_nb => {item => "nonbond", func => \&read_pairs_nb}
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
	2 => {type => "g96", nconstants => 2, constants => ["theta", "k"],
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
	10 => {type => "restrict", nconstants => 2, constants => ["theta", "k"],
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
	1 => {type => "harmonic", nconstants => 1, constants => ["l0", "k"],
	  units => [$unit->{length}], k => $kconstraint},
	2 => {type => "harmonic", nconstants => 1, constants => ["l0", "k"],
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
    }
  };
  my $comment;
  my $name;
  my $func;
  my $item;
  my $key;
  my $line;
  my $header;
  my $global = {};

  foreach (keys(%{$similar})) {
    $functions->{$_} = $functions->{$similar->{$_}};
  }

  foreach (ref($stream) eq "" ? split("\n", $stream) : <$stream>) {
    ++$line;
    chomp();

    #printf("%4d: %s\n", $line, $_);
    if (substr($_,0,1) eq ";") {
      my $arg = [split(" ")];
      my $tmp = shift(@{$arg});
      $comment = join(" ", @{$arg});
      $header = $comment if ($tmp eq ";;;;;;");
      next;
    }
    if (substr($_,0,1) eq "[") {
      $key = EMC::Common::trim(EMC::Common::strip($_));
      #EMC::Message::spot("key = $key\n");
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
    $func->(
      $stream, {
	line => $line, gromacs => $gromacs, key => $key, item => $item, 
	functions => $functions, arg => $arg, name => $name, 
	comment => $comment,
	global => $global
      }
    );
  }
  #EMC::Message::dumper("gromacs = ", $gromacs);
  return $gromacs;
}  


# read types

sub read_angletypes {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));

}


sub read_atomtypes {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};
  my $item = $attr->{item};
  my $arg = $attr->{arg};

  if (!defined($item->{index})) {
    $item->{flag}->{ntypes} = 1;
    $item->{index} = ["type", @{$functions->{func}->{1}->{constants}}];
  }
  $item->{data} = {} if (!defined($item->{data}));

  my $n = scalar(@{$arg});
  my $ptr = EMC::Common::list($item, "data", $arg->[0]);

  while (scalar(@{$ptr})<4) {
    push(@{$ptr}, 0);
  }
  $ptr->[1] = $arg->[0];		# name
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
  $global->{current}->{name} = lc($attr->{name});
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
  $data->[0] = [@t];
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
  my $atom = @_[0]->[@_[1]];
  my $connect = EMC::Common::list($atom, "connect");
  
  if (!defined($atom->{connect})) {
    $atom->{connect} = [@_[2]];
  } else {
    my $connect = $atom->{connect};
    return if (grep($_==@_[2], @{$connect}));
    push(@{$connect}, @_[2]);
  }
}


sub read_atoms {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $functions = $attr->{functions};
  my $gromacs = $attr->{gromacs};
  my $global = $attr->{global};
  my $item = $attr->{item};
  my $arg = $attr->{arg};
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
  my $ptr = $current->{atom}->[$arg->[0]-1] = {
    type => $arg->[1], resid => $arg->[2], resname => $arg->[3],
    atomname => $arg->[4], cgnr => $arg->[5], charge => eval($arg->[6])
  };
  $ptr->{mass} = eval($arg->[7]) if ($n==8);
  ++$gromacs->{atom}->{$arg->[1]}->{n};
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
  my $n = $functions->{ntypes};
  my @a = map({eval($_)} @{$arg});
  my @i = map({$_-1} splice(@a, 0, $n));
  my @t = EMC::Fields::arrange(map($atom->[$_]->{type}, @i));
  my $func = EMC::Common::element($functions, "func", shift(@a));

  if (!defined($func)) {
    EMC::Message::error_line($attr->{line}, "illegal $key function\n");
  }
  if (scalar(@{$arg})!=$func->{nconstants}+$n+1) {
    EMC::Message::error_line(
      $attr->{line}, "illegal number of $key arguments\n");
  }
  if ($func->{type} eq "improper") {
    @t[0,1] = @t[1,0];
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
    for (my $j=0; $j<$n-1; ++$j) { EMC::GROMACS::connect($atom, @i[$j,$j+1]); }
    for (my $j=$n-1; $j>0; --$j) { EMC::GROMACS::connect($atom, @i[$j,$j-1]); }
  }
  @a[1] = $func->{k} if ($key eq "constraints");
  my $data = EMC::Common::list($item, "data", @t, join("\t", @a));
  push(@{$data}, [$atom->[@i[0]]->{resname}, @i]);
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


# conversion

sub to_field {
  my $gromacs = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $type = EMC::Common::element($attr, "type");
  my $field = EMC::Common::hash($attr, "field");
  my $equivalence = EMC::Common::hash($field, "equivalence");
  my $molecules = EMC::Common::element($gromacs, "molecule");
  my $atom = EMC::Common::element($gromacs, "atom");

  my $convert = {
    martini => {
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
    "mass", "nonbond", "bond", "angle", "torsion", "improper"];
  my $eqv_index = EMC::List::hash(EMC::Fields::equivalence_index());

  if (!defined($convert->{$type})) {
    EMC::Message::error("unsupported field type '$type'\n");
  }
  $convert = $convert->{$type};

  #EMC::Message::dumper("gromacs = ", $gromacs);

  foreach (@{$order}) {
    next if (!defined($gromacs->{$_}));

    my $item = $gromacs->{$_}; next if (!defined($item->{data}));
    my $entry = EMC::Common::hash($field, $_);
    my $ftype = $_;

    if (!defined($convert->{$ftype})) {				# verbatim
      $entry->{flag} = EMC::Element::deep_copy($item->{flag});
      $entry->{index} = EMC::Element::deep_copy($item->{index});
      $entry->{data} = EMC::Element::deep_copy($item->{data});
      next;
    }

    my $n = $item->{flag}->{ntypes};				# initialize
    my $convert_index = $convert->{$_}->{index};
    my $data = $item->{data};
    my $ptr = [$data];
    my $keys = [[sort(keys(%{$data}))]];
    my $index = EMC::List::hash($item->{flag}->{index});
    my ($i, $prm, $freq);
    my (@type, @key);

    #EMC::Message::dumper("index = ", $index);

    $entry->{flag} = {array => 0, cmap => 0, first =>1, ntypes => $n};
    if (!defined($entry->{index})) {
      $entry->{index} = [map("type$_", (1..$n)), @{$convert_index}];
    }
    for ($i=1; $i<$n; ++$i) { push(@{$keys}, []); }
    while (1) {
      last if (!scalar(@{$keys->[0]}));
      
      for ($i=1; $i<$n; ++$i) { 				# advance
	last if(!scalar(@{$keys->[$i]}));
      }
      @key[$i-1] = shift(@{$keys->[$i-1]});
      for (; $i<$n; ++$i) { 
	$ptr->[$i] = $ptr->[$i-1]->{@key[$i-1]};
	$keys->[$i] = [sort(keys(%{$ptr->[$i]}))];
	@key[$i] = shift(@{$keys->[$i]});
      }
      $ptr->[$i] = $ptr->[$i-1]->{@key[-1]};
      $prm = [keys(%{$ptr->[-1]})];				# apply
      $freq = {};
      #print(join("\t", @key, scalar(@{$prm}), "\n"));
      foreach (@{$prm}) { $freq->{$_} = scalar(@{$ptr->[-1]->{$_}}); }
      $prm = EMC::List::sort($prm, $freq);

      my @type = @key;
      my $flag = 0;

      foreach (reverse(@{$prm})) {
	my $data = EMC::Common::hash($entry, "data");
	my @p = split("\t");
	my $k = $_;

	if ($flag) {						# extra type
	  my $f = {};

	  # - parameters with lowest occurence
	  # - type with highest overall occurence
	  # - otherwise alphabetically lowest type

	  foreach (@key) { ++$f->{$_}; }
	  my @sort = sort({
	      $f->{$a}==$f->{$b} ? 
		$atom->{$a}->{n}==$atom->{$b}->{n} ? $b cmp $a :
		$atom->{$a}->{n}<=>$atom->{$b}->{n} : $f->{$a}<=>$f->{$b}
	    }
	    keys(%{$f})
	  );

	  # find suitable type

	  my $change = @sort[-1];
	  my $i0 = $atom->{$change}->{i}+1;
	  my $i = $i0;
	  my $success = 0;
	  my $found = 0;
	  my $t;

	  for ( ; $i<100; ++$i ) {
	    $t = $change.$i;
	    foreach (@{$ptr->[-1]->{$k}}) {
	      last if (($found = grep($atom->{$_} eq $t, @{$_}) ? 1 : 0));
	    }
	    last if (!$found);
	  }
	  if ($i==100) {
	    EMC::Message::error("too many extra types for type '$change'\n");
	  }
	  $atom->{$change}->{i} = $i if ($i!=$i0);
	  foreach (@{$ptr->[-1]->{$k}}) {
	    my $atom = $molecules->{data}->{$_->[0]}->{atom};

	    $atom->[$_->[1]]->{type} = $t if ($atom->[$_->[1]]->{type} eq $change);
	    $atom->[$_->[2]]->{type} = $t if ($atom->[$_->[2]]->{type} eq $change);
	  }
	  @type = ();
	  foreach (@key) { 
	    if ($_ eq $change) {
	      push(@type, $t);
	      if (!EMC::Common::element($equivalence, "data", $t)) {
		EMC::Fields::equivalence($field, $t, $_);
		$equivalence->{data}->{$t}->[$eqv_index->{$ftype}-1] = $t;
	      }
	    } else {
	      push(@type, $_);
	      if (!EMC::Common::element($equivalence, "data", $_)) {
		EMC::Fields::equivalence($field, $_);
	      }
	    }
	  }
	  #EMC::Message::spot("change[$i] = $change\n");
	} else {
	  foreach (@type) {					# equivalence
	    if (!EMC::Common::element($equivalence, "data", $_)) {
	      EMC::Fields::equivalence($field, $_);
	    }
	  }
	}
	#print("\t", join("\t", @p, $freq->{$_}, @type), "\n");
	for ($i=0; $i<$n-1; ++$i) {
	  $data = EMC::Common::hash($data, @type[$i]);
	}
	$data = $data->{@type[-1]} = [];
	foreach (@{$convert_index}) {
	  push(@{$data}, @p[$index->{$_}]);
	}
	++$flag;
      }
    }
    #print("\n");
  }

  #EMC::Message::dumper("gromacs = ", $gromacs);
  #EMC::Message::dumper("field = ", $field);

  $field->{templates}->{flag} = {ntypes => 1};
  $field->{templates}->{index} = ["name", "smiles"];
  foreach (keys(%{$molecules->{data}})) {
    my $molecule = $molecules->{data}->{$_};
    my $smiles = smiles($molecule, 0);

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
  my $atoms = $molecule->{atom};
  my $atom = $atoms->[$current];
  my $smiles = $atom->{type};

  $atom->{visited} = 1;
  if ($atom->{charge}) {
    $smiles .= ($atom->{charge}>0 ? "+" : "").$atom->{charge};
  }
  $smiles = "[$smiles]" if (length($smiles)>1);
  $smiles .= join("", @{$atom->{link}});
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
