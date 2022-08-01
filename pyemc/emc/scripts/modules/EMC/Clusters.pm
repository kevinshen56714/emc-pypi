#!/usr/bin/env perl
#
#  module:	EMC::Clusters.pm
#  author:	Pieter J. in 't Veld
#  date:	November 28, 2021.
#  purpose:	EMC::Clusters structure routines; part of EMC distribution
#
#  members:
#    flag	HASH	holds cluster settings
#      first	BOOLEAN
#      mass	BOOLEAN
#      volume	BOOLEAN
#    cluster	HASH	of names
#      id	VALUE	index in index array
#      fraction	VALUE	fraction
#      mass	VALUE	mass of cluster (for DPD, depricated)
#      volume	VALUE	volume of cluster (for DPD, depricated)
#      type	STRING	'cluster', 'alternate', 'block', or 'random'
#      group	REF	xref to contributing group name when not a polymer
#      n	VALUE	total number of members including counter ions
#      profile	BOOLEAN	set when contributing to profiles
#      polymer	REF	xref to polymer
#    index	ARRAY	holds cluster names in index of appearance
#
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211128	Inception of v1.0
#

package EMC::Clusters;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Message;


# assignment

sub assign {
  return {
    flag		=> {
      first		=> 1,
      mass		=> 0,
      volume		=> 0
    },
    cluster		=> {},
    index		=> []
  };
}


sub obtain {
  my $emc = shift(@_);

  error("EMC object not defined\n") if (!defined($emc));
  $emc->{clusters} = assign() if (!defined($emc->{clusters}));
  return $emc->{clusters};
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

sub flag {
  my $clusters = shift(@_);
  my $flag = $clusters->{flag};
  my $line = shift(@_);
  my $name = shift(@_);
  my $mass = shift(@_);
  my $volume = shift(@_);

  if ($flag->{first}) {
    $flag->{mass} = $mass ne "" ? 1 : 0;
    $flag->{volume} = $volume ne "" ? 1 : 0;
    $flag->{first} = 0;
  } else {
    if (($mass ne "" ? 1 : 0)^$flag->{mass}) {
      EMC::Message::error_line(
	$line, "inconsistent mass entry for cluster '$name'\n");
    }
    if (($volume ne "" ? 1 : 0)^$flag->{volume}) {
      EMC::Message::error_line(
	$line, "inconsistent volume entry for cluster '$name'\n");
    }
  }
}


sub item {
  my $emc = shift(@_);
  my $clusters = $emc->{clusters};
  my $cluster = $clusters->{cluster};
  my $name = shift(@_);
  my $group_name = shift(@_);
  my $fraction = shift(@_);
  my $mass = shift(@_);
  my $volume = shift(@_);
  my $line = $emc->{line};

  # set id

  my $index;
  my $id;

  if (defined($clusters->{index})) {
    $index = $clusters->{index};
  } else {
    $index = $clusters->{index} = [];
  }
  if (defined($cluster->{$name})) {
    $id = ($cluster = $cluster->{$name})->{id};
  } else {
    $cluster->{$name}->{id} = scalar(@{$clusters->{index}});
    push(@{$clusters->{index}}, $name);
    $cluster = $cluster->{$name};
  }
  flag($clusters, $name, $mass, $volume);

  # check mass
  
  my $field = $emc->{field};
  
  if ($mass ne "" && !$emc->{flag}->{mass_entry}) {
    EMC::Message::error_line(
      $line, "mass entry allowed for field '$emc->{field}->{type}'\n");
  }

  # check group
  
  my $fpoly = EMC::Polymers::is_polymer($group_name);
  my $groups = $emc->{groups};
  my $group = $groups->{group};

  if ($fpoly ? 0 : !defined($group->{$group_name})) {
    EMC::Message::error_line(
      $line, "undefined group \'$group_name\'\n");
  }

  my $profiles = $emc->{profiles};
  my $profile = $emc->{profile};

  if ($profiles->{flag}->{density} ?
      defined($profile->{$name}) : 0) {
      EMC::Message::error_line(
	$line, "cluster name '$name' already taken by a profile\n");
  }
  $profile->{$name} = 1 if ($profiles->{flag}->{density});

  $cluster->{name} = $name;
  $cluster->{fraction} = $fraction;
  $cluster->{mass} = $mass;
  $cluster->{volume} = $volume;
  $cluster->{type} = $fpoly ? $group : "cluster";
  $cluster->{group} = $group if (!$fpoly);
  $cluster->{n} = $fpoly ? 1 : ${$::EMC::Group{$group}}{nextra}+1;
  $cluster->{profile} = $::EMC::ProfileFlag{density} ? 1 : 0;

  my $polymers = EMC::Polymers::obtain($emc);
  my $polymer = $emc->{polymer};

  if (!defined($polymer->{$name})) {
    if ($fpoly) {
      $polymers->{flag}->{cluster} = 1;
    } 
  }
  return $cluster;
}

