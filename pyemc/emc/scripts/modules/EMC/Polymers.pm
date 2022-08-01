#!/usr/bin/env perl
#
#  module:	EMC::Polymers.pm
#  author:	Pieter J. in 't Veld
#  date:	November 28, 2021.
#  purpose:	EMC::Polymers structure routines; part of EMC distribution
#
#  members:
#    flag
#      bias		OPTION	'none', 'binary', or 'accumulative'
#      cluster		VALUE	reference to cluster	
#      fraction		OPTION	'mass' or 'number'	
#      niterations	VALUE	number of iterations while constructing	
#      index		OPTION	index in which to select: 'list' or 'random'
#      ignore		ARRAY	flag options to ignore
#    polymer
#      name		STRING	name
#      flag		HASH	see above	
#      data		HASH
#        n		ARRAY	number of repeat units
#        group		ARRAY	contributing groups
#        weight		ARRAY	weight of each contributing group
#        fraction	VALUE	distribution fraction	
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211128	Inception of v1.0
#

package EMC::Polymers;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

# packages

use EMC::Math;


# assignments

sub assign {
  return {
    flag => {
      bias		=> "none",
      cluster		=> 0,
      fraction		=> "number",
      niterations	=> -1,
      index		=> "list",
      ignore		=> ["cluster"]
    },
    polymer		=> {}
  };
}


sub obtain {
  my $emc = shift(@_);

  error("EMC object not defined\n") if (!defined($emc));
  $emc->{polymers} = assign() if (!defined($emc->{polymers}));
  return $emc->{polymers};
}


# options

sub options_set {
  my $emc = shift(@_);
  my $options = {
  };

  foreach (keys(%{$options})) {
    $emc->{options}->{$_} = $options->{$_};
  }
}


# functions

sub is_polymer {
  my $text = shift(@_);
  my $allowed = {
    alternate => 1, block => 2, random => 3};

  return defined($allowed->{$text}) ? $allowed->{$text} : 0;
}


# ITEM POLYMERS
#   line 1: 	name,fraction[,mass[,volume]]
#   fraction -> mole, mass, or volume fraction
#   line 2:	fraction,group,n[,group,n[,...]]
#   fraction -> mole fraction
#   line ...:	same as line 2

sub item {
  my $emc = shift(@_);
  my $emc_flag = $emc->{flag};
  my $polymers = $emc->{polymers};
  my $polymer = $polymers->{polymer};
  my $ptr;

  if (!EMC::Math::number_q(@_[0])) {
    my $name = shift(@_);
    my $groups = $emc->{groups};
    my $group = $groups->{group};
    my $clusters = $emc->{clusters};
    my $cluster = $clusters->{cluster};

    if (defined($cluster->{$name}) && $cluster->{$name}->{type} ne "cluster") {
      $ptr = $cluster->{$name};
    } elsif (defined($group->{$name}) && $group->{$name}->{type} ne "group") {
      $ptr = $group->{$name};
    }
  }
}

