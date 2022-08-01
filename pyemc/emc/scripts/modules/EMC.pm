#!/usr/bin/env perl
#
#  program:	EMC.pm
#  author:	Pieter J. in 't Veld
#  date:	November 28, 2021.
#  purpose:	EMC structure routines; part of EMC distribution
#
#  members
#    options	HASH	available options, defined through modules
#    clusters	HASH	cluster definitions
#    polymers	HASH	polymer definitions
#
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211128	Inception of v1.0
#

package EMC;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

# packages

use EMC::Clusters;
use EMC::Common;
use EMC::Dist;
use EMC::Element;
use EMC::Field;
use EMC::Groups;
use EMC::IO;
use EMC::Item;
use EMC::List;
use EMC::Math;
use EMC::Matrix;
use EMC::Message;
use EMC::Options;
use EMC::Polymers;
use EMC::Profiles;
use EMC::Struct;

# constants

use vars qw(&Identity);

$EMC::Identity = {
  version => "9.4.4"
};


# assignments

sub assign {
  my $emc = {
    options => {},
    groups => EMC::Groups::assign(),
    clusters => EMC::Clusters::assign(),
    polymers => EMC::Polymers::assign(),
    profiles => EMC::Profiles::assign()
  };

  EMC::Groups::options_set($emc);
  EMC::Clusters::options_set($emc);
  EMC::Polymers::options_set($emc);
  EMC::Profiles::options_set($emc);
  return $emc;
}


sub obtain {
  my $emc = shift(@_);

  $emc = assign() if (!defined($emc));
  return $emc;
}


# functions

