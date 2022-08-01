#!/usr/bin/env perl
#
#  module:	EMC::Groups.pm
#  author:	Pieter J. in 't Veld
#  date:	November 28, 2021.
#  purpose:	EMC::Groups structure routines; part of EMC distribution
#
#  members:
#    group	HASH	group definitions
#      type	OPTION	'group', 'alternate', 'block', or 'random'
#      polymer	REF	xref to polymer in emc->polymers->polymer
#    index	ARRAY	index in which groups were defined
#
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211128	Inception of v1.0
#

package EMC::Groups;

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
    group => {},
    index => []
  };
}


sub obtain {
  my $emc = shift(@_);

  error("EMC object not defined\n") if (!defined($emc));
  $emc->{groups} = assign() if (!defined($emc->{groups}));
  return $emc->{groups};
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

