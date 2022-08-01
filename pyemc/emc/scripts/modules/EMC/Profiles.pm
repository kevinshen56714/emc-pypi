#!/usr/bin/env perl
#
#  module:	EMC::Profiles.pm
#  author:	Pieter J. in 't Veld
#  date:	November 28, 2021.
#  purpose:	EMC::Profiles structure routines; part of EMC distribution
#
#  members:
#    flag	HASH	profile flags
#
#  
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211128	Inception of v1.0
#

package EMC::Profiles;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

# packages

use EMC::Message;


# assignments

sub assign {
  return {
    flag		=> {
      density		=> 0,
      density3d		=> 0,
      pressure		=> 0
    }
  };
}


sub obtain {
  my $emc = shift(@_);

  error("EMC object not defined\n") if (!defined($emc));
  $emc->{profiles} = assign() if (!defined($emc->{profiles}));
  return $emc->{profiles};
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

