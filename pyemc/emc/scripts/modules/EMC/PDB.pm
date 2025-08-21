#!/usr/bin/env perl
#
#  module:	EMC::PDB.pm
#  author:	Pieter J. in 't Veld
#  date:	September 3, 2022, December 12, 2024.
#  purpose:	PDB structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "pdb_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    flag		HASH	optional flags
#
#  notes:
#    20220903	Inception of v1.0
#    20241212	Added -pdb_licorice
#

package EMC::PDB;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::PDB'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::EMC;
use EMC::Math;


# defaults

$EMC::PDB::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 3, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $pdb = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($pdb, $attr);
  set_defaults($pdb);
  set_commands($pdb);
  return $pdb;
}


# initialization

sub set_defaults {
  my $pdb = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $pdb->{flag} = EMC::Common::attributes(
    EMC::Common::hash($pdb, "flag"),
    {
      atom		=> "index",
      compress		=> 1,
      connect		=> 0,
      cut		=> 0,
      extend		=> 0,
      fixed		=> 1,
      hexadecimal	=> 0,
      licorice		=> 0,
      parameters	=> 0,
      pbc		=> 1,
      rank		=> 0,
      residue		=> "index",
      rigid		=> 1,
      segment		=> "index",
      unwrap		=> 1,
      vdw		=> 0,
      write		=> 1
    }
  );
  $pdb->{identity} = EMC::Common::attributes(
    EMC::Common::hash($pdb, "identity"),
    $EMC::PDB::Identity
  );
  return $pdb;
}


sub transfer {
  my $lammps = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($lammps, "flag");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Flag{hexadecimal},	\$flag->{hexadecimal}],
    [\$::EMC::PDB{atom},		\$flag->{atom}],
    [\$::EMC::PDB{compress},		\$flag->{compress}],
    [\$::EMC::PDB{connect},		\$flag->{connect}],
    [\$::EMC::PDB{cut},			\$flag->{cut}],
    [\$::EMC::PDB{extend},		\$flag->{extend}],
    [\$::EMC::PDB{fixed},		\$flag->{fixed}],
    [\$::EMC::PDB{parameters},		\$flag->{parameters}],
    [\$::EMC::PDB{pbc},			\$flag->{pbc}],
    [\$::EMC::PDB{rank},		\$flag->{rank}],
    [\$::EMC::PDB{residue},		\$flag->{residue}],
    [\$::EMC::PDB{rigid},		\$flag->{rigid}],
    [\$::EMC::PDB{segment},		\$flag->{segment}],
    [\$::EMC::PDB{unwrap},		\$flag->{unwrap}],
    [\$::EMC::PDB{vdw},			\$flag->{vdw}],
    [\$::EMC::PDB{write},		\$flag->{write}]
  );
}


sub set_commands {
  my $pdb = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($pdb, "set");
  my $flag = EMC::Common::element($pdb, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  
  $indicator = $indicator ? "pdb_" : "";
  my $commands = $pdb->{commands} = EMC::Common::attributes(
    EMC::Common::hash($pdb, "commands"),
    {
      pdb		=> {
	comment		=> "create PDB and PSF output",
	default		=> EMC::Math::boolean($flag->{write}),
	gui		=> ["string", "chemistry", "top", "ignore"]},

      # A

      $indicator."atom"		=> {
	comment		=> "set atom name behavior",
	default		=> $flag->{atom},
	gui		=> ["option", "chemistry", "emc", "advanced", "detect,index,series"]},

      # C

      $indicator."compress"	=> {
	comment		=> "set PDB and PSF compression",
	default		=> EMC::Math::boolean($flag->{compress}),
	gui		=> ["option", "chemistry", "emc", "advanced"]},
      $indicator."connect"	=> {
	comment		=> "add connectivity information",
	default		=> EMC::Math::boolean($flag->{connect}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      $indicator."cut"		=> {
	comment		=> "cut bonds spanning simulation box",
	default		=> EMC::Math::boolean($flag->{cut}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},

      # E

      $indicator."extend"	=> {
	comment		=> "use extended format for PSF",
	default		=> EMC::Math::boolean($flag->{extend}),
	gui		=> ["boolean", "chemistry", "emc", "advanced"]},

      # F

      $indicator."fixed"	=> {
	comment		=> "do not unwrap fixed sites",
	default		=> EMC::Math::boolean($flag->{fixed}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},

      # H

      $indicator."hexadecimal"	=> {
	comment		=> "set hexadecimal index output in PDB",
	default		=> EMC::Math::boolean($flag->{hexadecimal}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},

      # L

      $indicator."licorice"		=> {
	comment		=> "add licorice representation",
	default		=> EMC::Math::boolean($flag->{licorice}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},

      # P

      $indicator."parameters"	=> {
	comment		=> "generate NAMD parameter file",
	default		=> EMC::Math::boolean($flag->{parameters}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
      $indicator."pbc"	=> {
	comment		=> "apply periodic boundary conditions",
	default		=> EMC::Math::boolean($flag->{pbc}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},

      # R

      $indicator."rank"	=> {
	comment		=> "apply rank evaluation for coarse-grained output",
	default		=> EMC::Math::boolean($flag->{rank}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
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

      # V

      $indicator."vdw"		=> {
	comment		=> "add Van der Waals representation",
	default		=> EMC::Math::boolean($flag->{vdw}),
	gui		=> ["boolean", "chemistry", "emc", "ignore"]},
    }
  );

  foreach (keys(%{$commands})) {
    my $ptr = $commands->{$_};
    if (!defined($ptr->{set})) {
      $ptr->{set} = \&EMC::PDB::set_options;
    }
  }

  return $pdb;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $pdb = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($pdb, "flag");
  my $set = EMC::Common::element($pdb, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "pdb_" : "";
  if ($option eq "pdb") {
    return $flag->{write} = EMC::Math::flag($args->[0]); }

  # A

  if ($option eq $indicator."atom") {
    return $flag->{atom} = set_flag("atom", $args->[0], $line); }

  # C

  if ($option eq $indicator."compress") {
    return $flag->{compress} = EMC::Math::flag($args->[0]); }
  if ($option eq $indicator."connect") {
    return $flag->{connect} = EMC::Math::flag($args->[0]); }
  if ($option eq $indicator."cut") {
    return $flag->{cut} = EMC::Math::flag($args->[0]); }

  # E

  if ($option eq $indicator."extend") {
    return $flag->{extend} = EMC::Math::flag($args->[0]); }

  # F

  if ($option eq $indicator."fixed") {
    return $flag->{fixed} = EMC::Math::flag($args->[0]); }

  # H

  if ($option eq $indicator."hexadecimal") {
    return $flag->{hexadecimal} = EMC::Math::flag($args->[0]); }
  if ($option eq "hexadecimal") {				# backwards
    return $flag->{hexadecimal} = EMC::Math::flag($args->[0]); }

  # L

  if ($option eq $indicator."licorice") {
    $flag->{vdw} = 0;
    return $flag->{licorice} = EMC::Math::flag($args->[0]); }

  # P

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

  # U

  if ($option eq $indicator."unwrap") {
    return $flag->{unwrap} = EMC::EMC::flag_unwrap($args->[0]); }

  # V

  if ($option eq $indicator."vdw") {
    $flag->{licorice} = 0;
    return $flag->{vdw} = EMC::Math::flag($args->[0]); }
  return undef;
}


sub set_functions {
  my $pdb = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($pdb, "set");
  my $write = EMC::Common::hash($pdb, "write");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, indicator => 1, items => 1, md => 0};

  $set->{commands} = \&EMC::PDB::set_commands;
  $set->{defaults} = \&EMC::PDB::set_defaults;
  $set->{options} = \&EMC::PDB::set_options;

  $write->{emc} = \&EMC::PDB::write_emc;

  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $pdb;
}


# option functions

sub set_flag {					# <= set_pdb_flag
  my $type = shift(@_);
  my $mode = shift(@_);
  my $line = shift(@_);
  my %allow = (detect => 1, index => 1, series => 1);

  if (!$allow{$mode}) {
    EMC::Message::error_line($line, "illegal PDB $type flag '$mode'\n");
  }
  return $mode;
}


# EMC script additions

# PDB import

sub read {
  my $name = shift(@_);
  my $stream = EMC::IO::open($name, "r");
  my $read = {
    atom => \&EMC::PDB::read_atom,
    hetatom => \&EMC::PDB::read_atom,
    connect => \&EMC::PDB::read_connect,
    cryst1 => \&EMC::PDB::read_cryst1,
    remark => \&EMC::PDB::read_remark
  };
  my $result = {
    flag => {connect => 0}
  };

  foreach (<$stream>) {
    my $command = EMC::Common::trim(lc(substr($_,0,6)));

    next if (!defined($read->{$command}));
    $read->{$command}->($result, \$_);
  }
  EMC::IO::close($stream, $name);
  return $result;
}


sub read_atom {
  my $result = shift(@_);
  my $line = shift(@_);
  my $data = {
    id => EMC::Common::trim(substr(${$line}, 6, 5)),
    name => EMC::Common::trim(substr(${$line}, 11, 5)),
    loc_id => EMC::Common::trim(substr(${$line}, 16, 1)),
    res_name => EMC::Common::trim(substr(${$line}, 17, 4)),
    chain_id => EMC::Common::trim(substr(${$line}, 21, 1)),
    res_id => EMC::Common::trim(substr(${$line}, 22, 4)),
    code => EMC::Common::trim(substr(${$line}, 23, 1)),
    x => EMC::Common::trim(substr(${$line}, 30, 8)),
    y => EMC::Common::trim(substr(${$line}, 38, 8)),
    z => EMC::Common::trim(substr(${$line}, 46, 8)),
    occupancy => EMC::Common::trim(substr(${$line}, 54, 6)),
    temp_factor => EMC::Common::trim(substr(${$line}, 60, 6)),
    segname => EMC::Common::trim(substr(${$line}, 72, 4)),
    element => EMC::Common::trim(substr(${$line}, 76, 2)),
    charge => EMC::Common::trim(substr(${$line}, 78, 2))
  };

  $result->{atom} = [] if (!defined($result->{atom}));
  $result->{atom}->[$data->{id}-1] = $data;
  return $result;
}


sub read_connect {
  my $result = shift(@_);
  my $line = shift(@_);
  my $id = EMC::Common::trim(substr(${$line}, 6, 5));
  my $connect = [];
  my $bond = [];

  foreach (split(" ", ${$line}, 11)) {
    my @a = split(":");
    unshift(@a, "~") if (scalar(@a)<2);
    push(@{$bond}, @a[0]);
    push(@{$connect}, @a[1]);
  }
  $result->{atom} = [] if (!defined($result->{atom}));
  $result->{atom}->[$id]->{connect} = $connect;
  $result->{atom}->[$id]->{bond} = $bond;
  $result->{flag}->{connect} = 1;
  return $result;
};


sub read_cryst1 {
  my $result = shift(@_);
  my $line = shift(@_);
  my $data = {
    x => EMC::Common::trim(substr(${$line}, 6, 9)),
    y => EMC::Common::trim(substr(${$line}, 15, 9)),
    z => EMC::Common::trim(substr(${$line}, 24, 9)),
    gamma => EMC::Common::trim(substr(${$line}, 33, 7)),
    beta => EMC::Common::trim(substr(${$line}, 40, 7)),
    alpha => EMC::Common::trim(substr(${$line}, 47, 7)),
    space_group => EMC::Common::trim(substr(${$line}, 55, 11)),
    z_value => EMC::Common::trim(substr(${$line}, 66, 4))
  };

  if (EMC::Math::round(1.0-cos($data->alpha*$EMC::Math::Pi))==0.0 ||
      EMC::Math::round(1.0-cos($data->beta*$EMC::Math::Pi))==0.0 ||
      EMC::Math::round(1.0-cos($data->gamma*$EMC::Math::Pi))==0.0) {
    EMC::Message::error("incorrect box angle\n");
  }
  $result->{geometry} = EMC::Common::attributes($result->{geometry}, $data);
  return $result;
}


sub read_remark {
  my $result = shift(@_);
  my $line = shift(@_);
  my $data = {
  };
  $result->{geometry} = $data;
  return $result;
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

  printf($stream "\npdb\t\t= {name -> output,");
  printf($stream " compress -> ".EMC::Math::boolean($flag->{compress}).",");
  printf($stream " extend -> ".EMC::Math::boolean($flag->{extend}).",");
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
  printf($stream " vdw -> ".EMC::Math::boolean($flag->{vdw}).",");
  printf($stream " cut -> ".EMC::Math::boolean($flag->{cut}).",");
  printf($stream "\n\t\t  ");
  printf($stream " fixed -> ".EMC::Math::boolean($flag->{fixed}).",");
  printf($stream " rigid -> ".EMC::Math::boolean($flag->{rigid}).",");
  printf($stream " connectivity -> ".EMC::Math::boolean($flag->{connect}).",");
  printf($stream "\n\t\t  ");
  if ($flag->{licorice}) {
    printf($stream " licorice -> ".EMC::Math::boolean($flag->{licorice}).",");
  }
  printf($stream " parameters -> ".EMC::Math::boolean($flag->{parameters}));
  printf($stream "};\n");
}

