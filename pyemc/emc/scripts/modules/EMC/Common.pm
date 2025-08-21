#!/usr/bin/env perl
#
#  module:	EMC::Common.pm
#  author:	Pieter J. in 't Veld
#  date:	December 19, 2021.
#  purpose:	Common structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
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
  my $element = shift(@_);

  while (ref($element) eq "REF") { 
    $element = ${$element};
  }
  foreach (@_) {
    return undef if (ref($element) ne "HASH");
    $element = defined($element->{$_}) ? $element->{$_} : undef;
    while (ref($element) eq "REF") {
      $element = ${$element};
    }
  }
  return $element;
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


sub array {
  return list(@_);
}


sub hash {
  my $ptr = shift(@_);

  return {} if (!defined($ptr));
  foreach (@_) {
    if (ref($ptr) eq "HASH") {
      $ptr->{$_} = {} if (!defined($ptr->{$_}));
      $ptr = $ptr->{$_};
    } else {
      EMC::Message::error("unexpected element in hash\n");
    }
  }
  return $ptr;
}


sub list {
  if (defined(@_[1])) {
    my $last = pop(@_);
    my $hash = hash(@_);
    
    $hash->{$last} = [] if (!defined($hash->{$last}));
    return $hash->{$last};
  } else {
    return defined(@_[0]) ? @_[0] : [];
  }
}


# string functions

sub convert_name {
  my @r;

  foreach (@_) {
    my $s = $_;
    $s =~ s/:/_/g;
    push(@r, $s);
  }
  return [@r];
}


sub strip {
  return substr(@_[0],1,length(@_[0])-2);
}


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
  return $t->fullmonth()." ".$t->day_of_month().", ".$t->year();
}


sub date_short {
  my $t = Time::Piece::localtime();
  return $t->fullmonth()." ".$t->year();
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


# I/O functions

# verbatim	HASH
#   line	VALUE	line number in original file
#   data	STRING	line content

sub write_verbatim {
  my $stream = shift(@_);
  my $verbatim = shift(@_);
  my $n = 0;

  return if (!defined($verbatim));
  foreach(@{$verbatim}) {
    printf($stream "%s\n", $_->{data});
    ++$n;
  }
  return $n;
}



