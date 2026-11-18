#!/usr/bin/env perl
#
#  module:	EMC::VTK.pm
#  author:	Pieter J. in 't Veld
#  date:	June 17, 2026.
#  purpose:	Empty structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2026 Pieter J. in 't Veld
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
#        indicator	BOOLEAN	include "vtk_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20260602	Inception of v1.0
#

package EMC::VTK;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::VTK'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use JSON;

use EMC::Common;
use EMC::Element;
use EMC::Math;
use EMC::Options;


# defaults

$EMC::VTK::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "June 17, 2026",
  version	=> "1.0"
};


# construct

sub construct {
  my $vtk = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
 
  set_functions($vtk, $attr);
  set_defaults($vtk);
  set_commands($vtk);
  return $vtk;
}


# initialization

sub set_defaults {
  my $vtk = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $vtk->{context} = EMC::Common::attributes(
    EMC::Common::hash($vtk, "context"),
    {
      focus		=> {
	clusters	=> {},
	groups		=> {},
	sites		=> {}
      }
    }
  );
  $vtk->{flag} = EMC::Common::attributes(
    EMC::Common::hash($vtk, "flag"),
    {
      active		=> 0,
      binsize		=> 1,
      compress		=> 0,
      convolute		=> 1,
      normalize		=> 1,
      write		=> 0
    }
  );
  $vtk->{identity} = EMC::Common::attributes(
    EMC::Common::hash($vtk, "identity"),
    $EMC::VTK::Identity
  );
  return $vtk;
}


sub transfer {
  my $vtk = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($vtk, "flag");
  my $context = EMC::Common::element($vtk, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::VTK{dummy},		\$context->{dummy}],
  );
}


sub set_context {
  my $vtk = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($vtk, "flag");
  my $context = EMC::Common::element($vtk, "context");
}


sub set_commands {
  my $vtk = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($vtk, "set");
  my $context = EMC::Common::element($vtk, "context");
  my $flag = EMC::Common::element($vtk, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated =  $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "vtk_" : "";

  $context->{depricated} = $flag_depricated;
  $vtk->{commands} = EMC::Common::hash($vtk, "commands");
  while (1) {
    my $commands = {
      vtk		=> {
	comment		=> "VTK settings",
	set		=> \&EMC::VTK::set_options,
	default		=> EMC::Hash::text($flag)
      },
      $indicator."binsize"	=> {
	comment		=> "Set voxel bin size",
	set		=> \&EMC::VTK::set_options,
	default		=> $flag->{binsize}
      },
      $indicator."compress"	=> {
	comment		=> "Compress data file",
	set		=> \&EMC::VTK::set_options,
	default		=> EMC::Math::boolean($flag->{compress})
      },
      $indicator."convolute"	=> {
	comment		=> "Toggle convolution of volume over voxels",
	set		=> \&EMC::VTK::set_options,
	default		=> EMC::Math::boolean($flag->{convolute})
      },
      $indicator."normalize"	=> {
	comment		=> "Toggle normalization of voxels",
	set		=> \&EMC::VTK::set_options,
	default		=> EMC::Math::boolean($flag->{normalize})
      }
    };

    if ($flag_depricated) {
      foreach (keys(%{$commands})) {
	$commands->{$_}->{original} = $pre.$_;
      }
    }
    EMC::Options::set_command(
      $vtk->{commands} = EMC::Common::attributes(
	$vtk->{commands}, $commands
      ),
      {
	set		=> \&EMC::VTK::set_options
      }
    );
    last if ($indicator eq "" || !$depricated);
    $flag_depricated = 1;
    $indicator = "";
  }
  
  EMC::Options::set_command(
    $vtk->{items} = EMC::Common::attributes(
      EMC::Common::hash($vtk, "items"),
      {
	vtk		=> {		# added "vtk" to verbatim in
	}				# EMC::Script::read()
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0,
      set		=> \&EMC::VTK::set_item
    }
  );

  return $vtk;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $vtk = EMC::Common::element($struct, "module");
  my $context = EMC::Common::hash($vtk, "context");
  my $flag = EMC::Common::hash($vtk, "flag");
  my $set = EMC::Common::element($vtk, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "vtk_" : "";
  while (1) {
    if ($option eq "vtk") {
      my $result = 0;
      my @a = split("=", $args->[0]);
      if (scalar(@a)>0 || scalar(@{$args})>0) {
	EMC::Hash::set($line, $flag, "boolean", "active", [], @{$args});
	$result = $flag->{active};
      } else {
	$result = $flag->{active} = EMC::Math::flag($args->[0]);
      }      
#      if ($result) {
#	EMC::MD::set_flags(
#	  EMC::Common::element($vtk, "parent"), "write", 0);
#      }
      return $flag->{write} = $result;
    }
    if ($option eq $indicator."binsize") {
      return $flag->{binsize} = EMC::Math::eval($args->[0])->[0];
    }
    if ($option eq $indicator."compress") {
      return $flag->{compress} = EMC::Math::flag($args->[0]);
    }
    if ($option eq $indicator."convolute") {
      return $flag->{convolute} = EMC::Math::flag($args->[0]);
    }
    if ($option eq $indicator."normalize") {
      return $flag->{normalize} = EMC::Math::flag($args->[0]);
    }
    last if ($indicator eq "" || !$context->{depricated});
    $indicator = "";
  }
  return undef;
}


sub set_item {
  
  # could use EMC::Script::set_item_verbatim() instead, provided
  # no merging between several 'ITEM VTK' should occur
  
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $module = EMC::Common::element($struct, "module");
  my $option = EMC::Common::element($struct, "option");
  my $data = EMC::Common::element($item, "data");

  my $debug = 0;

  if ($debug) {
    EMC::Message::trace();
    EMC::Message::dumper("item = ", $item);

    my $json = JSON->new;
    my $ptr = $json->decode(join("\n", @{$item->{data}}));

    EMC::Message::dumper("ptr = ", $ptr);
  }
  $module->{verbatim} = $item;
  return $root;
}


sub set_functions {
  my $vtk = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($vtk, "set");
  my $write = EMC::Common::hash($vtk, "write");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&set_commands;
  $set->{context} = \&set_context;
  $set->{defaults} = \&set_defaults;
  $set->{options} = \&set_options;
  $set->{items} = \&set_items;

  $write->{emc} = \&write_emc;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $vtk;
}


# functions

# EMC script additions

sub write_emc {
  my $lammps = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $emc_flag = EMC::Common::element($root, "emc", "flag");
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $context = EMC::Common::element($lammps, "context");
  my $flag = EMC::Common::element($lammps, "flag");
  my $md = EMC::Common::element($lammps, "parent");

  return if (!EMC::Common::element($flag, "active"));

  printf($stream
    "\nvtk\t\t= {name -> output, ");
  printf($stream
    "binsize -> $flag->{binsize},\n");
  printf($stream
    "\t\t   compress -> %s, ", EMC::Math::boolean($flag->{compress}));
  printf($stream
    "convolute -> %s, ", EMC::Math::boolean($flag->{convolute}));
  printf($stream
    "normalize -> %s", EMC::Math::boolean($flag->{normalize}));
  printf($stream "};\n");
}

