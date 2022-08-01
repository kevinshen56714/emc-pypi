#!/usr/bin/env perl
#
#  program:	Empty.pm
#  author:	Pieter J. in 't Veld
#  date:	@{DATE}.
#  purpose:	Empty structure routines; part of EMC distribution
#
#  members:
#
#  
#  Copyright (c) 2004-@{YEAR} Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    @{YMD}	Inception of v1.0
#

package Empty;

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
  };
}


sub obtain {
  my $emc = shift(@_);

  error("EMC object not defined\n") if (!defined($emc));
  $emc->{empty} = assign() if (!defined($emc->{empty}));
  return $emc->{empty};
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

