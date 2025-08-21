#!/usr/bin/env perl
#
#  module:	EMC::Chemistry.pm
#  author:	Pieter J. in 't Veld
#  date:	September 21, 2022.
#  purpose:	Chemistry structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "chemistry_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20220921	Inception of v1.0
#

package EMC::Chemistry;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Chemistry'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::Math;


# defaults

$EMC::Chemistry::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 21, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $chemistry = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($chemistry, $attr);
  set_defaults($chemistry);
  #set_commands($chemistry);
  return $chemistry;
}


# initialization

sub set_defaults {
  my $chemistry = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $chemistry->{context} = EMC::Common::attributes(
    EMC::Common::hash($chemistry, "context"),
    {
      dummy		=> 0
    }
  );
  $chemistry->{flag} = EMC::Common::attributes(
    EMC::Common::hash($chemistry, "flag"),
    {
      dummy		=> 0
    },
  );
  $chemistry->{identity} = EMC::Common::attributes(
    EMC::Common::hash($chemistry, "identity"),
    $EMC::Chemistry::Identity
  );
  return $chemistry;
}


sub transfer {
  my $chemistry = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($chemistry, "flag");
  my $context = EMC::Common::element($chemistry, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Chemistry{dummy},		\$context->{dummy}],
  );
}


sub set_context {
  my $chemistry = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($chemistry, "flag");
  my $context = EMC::Common::element($chemistry, "context");
}


sub set_commands {
  return;
  
  my $chemistry = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($chemistry, "set");
  my $context = EMC::Common::element($chemistry, "context");
  my $flag = EMC::Common::element($chemistry, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated = $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "chemistry_" : "";

  $chemistry->{commands} = EMC::Common::hash($chemistry, "commands");
  while (1) {
    my $commands = {
      $indicator."dummy"	=> {
	comment		=> "dummy description",
	set		=> \&set_options,
	default		=> $chemistry->{flag}->{dummy}
      }
    };

    foreach (keys(%{$commands})) {
      my $ptr = $commands->{$_};
      if (!defined($ptr->{set})) {
	$ptr->{original} = $pre.$_ if ($flag_depricated);
	$ptr->{set} = \&set_options;
      }
    }
    $chemistry->{commands} = EMC::Common::attributes(
      $chemistry->{commands}, $commands
    );
    last if ($indicator eq "" || !$depricated);
    $flag_depricated = 1;
    $indicator = "";
  }

  return $chemistry;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $chemistry = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($chemistry, "flag");
  my $set = EMC::Common::element($chemistry, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "chemistry_" : "";
  if ($option eq $indicator."dummy") {
    return $flag->{dummy} = EMC::Math::flag($args->[0]);
  }
  return undef;
}


sub set_functions {
  my $chemistry = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($chemistry, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&set_commands;
  $set->{context} = \&set_context;
  $set->{defaults} = \&set_defaults;
  $set->{options} = \&set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $chemistry;
}


# functions

sub count_clusters {
  my $smiles = shift(@_);
  my $n = 1;
  my $l = 0;
  my $i;

  for ($i=0; $i<length($smiles); ++$i) {
    my $c = substr($smiles,$i,1);
    ++$n if (($c eq '.') && ($l == 0));
    if ($c eq '(') {
      my $in = subchunk($smiles, $i++);
      my $nn = count_clusters(substr($smiles,$i,$in-$i));
      $i = $in+1;
      my $a;
      for (; $i<length($smiles); ++$i) {
	my $c = substr($smiles,$i,1);
	last if ($c lt "0" || $c gt "9");
       	$a .= $c;
      }
      --$i; $n += ($a eq "" ? $nn : $a*$nn) if (--$nn);
    }
    elsif ($c eq ')') {
    }
    elsif ($c eq '[') {
      ++$l;
    }
    elsif ($c eq ']') {
      --$l;
    }
  }
  return $n;
}


sub strip {
  my $src=shift(@_);
  my $dest="";
  my $i;

  for ($i=0; $i<length($src); ++$i) {
    my $c = substr($src,$i,1);
    next if (($c eq "-")||($c eq "+")||(($c ge "0")&&($c le "9")));
    $dest .= $c;
  }
  return $dest;
}


sub subchunk {
  my $smiles = shift(@_);
  my $i = shift(@_);
  my $l = 0;

  for (; $i<length($smiles); ++$i) {
    my $c = substr($smiles,$i,1);

    if ($c eq '(') { ++$l; }
    elsif ($c eq ')') { --$l; }
    return $i if (!$l);
  }
  EMC::Message::error("parenthesis error in '$smiles'.\n");
}


sub strtype {
  my $key = @_[0];
  $key =~ s/\*/_s_/g;
  $key =~ s/\'/_q_/g;
  $key =~ s/\"/_qq_/g;
  $key =~ s/\-/_m_/g;
  $key =~ s/\+/_p_/g;
  $key =~ s/\=/_e_/g;
  $key =~ s/__/_/g;
  $key =~ s/_$//g;
  return $key;
}

