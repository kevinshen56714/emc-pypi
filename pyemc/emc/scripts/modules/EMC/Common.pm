#!/usr/bin/env perl
#
#  module:	EMC::Common.pm
#  author:	Pieter J. in 't Veld
#  date:	December 19, 2021.
#  purpose:	Common structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211219	Inception of v1.0
#

package EMC::Common;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use Time::Piece;


# element functions

sub element {
  return 
    ref(@_[0]) ne "HASH" ?  undef :
    defined(@_[0]->{@_[1]}) ? @_[0]->{@_[1]} : undef;
}


sub attributes {
  my $attr;

  $attr = shift(@_) if (ref(@_[0]) eq "HASH");
  while (scalar(@_)) {
    my $key = shift(@_);
    if (ref($key) eq "HASH") {
      $attr = defined($attr) ? 
		attributes($attr, %{$key}) : attributes(%{$key});
    } elsif (ref($key) eq "ARRAY") {
      $attr = defined($attr) ? 
		attributes($attr, @{$key}) : attributes(@{$key});
    } else {
      $attr->{$key} = shift(@_);
    }
  }
  return $attr;
}


sub obtain_array {
  if (defined(@_[1])) {
    @_[0]->{@_[1]} = [] if (!defined(@_[0]->{@_[1]}));
    return @_[0]->{@_[1]};
  } else {
    return defined(@_[0]) ? @_[0] : [];
  }
}


sub obtain_hash {
  if (defined(@_[1])) {
    @_[0]->{@_[1]} = {} if (!defined(@_[0]->{@_[1]}));
    return @_[0]->{@_[1]};
  } else {
    return defined(@_[0]) ? @_[0] : {};
  }
}


# string functions

sub trim {
  my $s = shift(@_);
  $s =~ s/^\s+|\s+$//g;
  return $s;
}


sub trim_left {
  my $s = shift(@_);
  $s =~ s/^\s+//g;
  return $s;
}


sub trim_right {
  my $s = shift(@_);
  $s =~ s/\s+$//g;
  return $s;
}


# date functions

sub date {
  my $t = Time::Piece::localtime();
  return $t->fullmonth()." ".$t->day_of_month()." ".$t->year();
}


sub date_full {
  my $t = Time::Piece::localtime(@_[0]);
  return $t->strftime("%a %b %d %H:%M:%S %Z %Y");
}


sub date_year {
  my $t = Time::Piece::localtime();
  return $t->year();
}


sub date_month {
  my $t = Time::Piece::localtime();
  return sprintf("%02d", $t->mon());
}


sub date_day {
  my $t = Time::Piece::localtime();
  return sprintf("%02d", $t->day_of_month());
}

