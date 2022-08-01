#!/usr/bin/env perl
#
#  module:	EMC::Math.pm
#  author:	Pieter J. in 't Veld
#  date:	November 24, 2021.
#  purpose:	Math structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211124	Inception of v1.0
#    20211225	Addition of round()
#

package EMC::Math;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use vars qw($Pi);


# constants

$EMC::Math::Round = 0.00001;
$EMC::Math::Pi = 3.14159265358979323846264338327950288;


# functions

# checks

sub boolean {
  return @_[0] if (@_[0] eq "true");
  return @_[0] if (@_[0] eq "false");
  return @_[0] ? @_[0]<0 ? "auto" : "true" : "false";
}


sub flag {
  my %allowed = ("true" => 1, "false" => 0, "1" => 1, "0" => 0, "auto" => -1);
  
  return 
    @_[0] eq "" ? 1 : 
    defined($allowed{@_[0]}) ? $allowed{@_[0]} : 
    eval(@_[0]) ? 1 : 0;
}


sub flag_q {
  my %allowed = ("true" => 1, "false" => 0, "1" => 1, "0" => 0, "auto" => -1);
  
  return defined($allowed{@_[0]}) ? 1 : 0;
}


sub number_q {
  return @_[0] =~ m/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ ? 1 : 0;
}


sub bound {
  return @_[0]<@_[1] ? @_[1] : @_[0]>@_[2] ? @_[2] : @_[0];
}


sub eval {
  my $value = shift(@_);

  return $value if (ref($value) ne "ARRAY" && ref($value) ne "");

  my $result = [];

  foreach (ref($value) eq "ARRAY" ? @{$value} : $value) {
    my $string;
    my $first = 1;
    my $error = 0;

    foreach (split(//, $_)) {
      next if ($first && $_ eq "0");
      $string .= $_;
      $first = 0;
    }
    $string = "0" if ($string eq "");
    {
      local $@;
      no warnings;
      unless (eval($string)) { $error = 1; }
    }
    push(@{$result}, $error ? $string : eval($string));
  }
  return $result;
}


# math

sub round {
  my $round = defined(@_[1]) ? @_[1]: 
	      $EMC::Math::Round>0 ? $EMC::Math::Round : 0.001;

  return int(@_[0]/$round+(@_[0]<0 ? -1 : 1)*(0.5+1e-10))*$round;
}


sub erf {
  my $x = $_[0];

  # constants
  my $a1 =  0.254829592;
  my $a2 = -0.284496736;
  my $a3 =  1.421413741;
  my $a4 = -1.453152027;
  my $a5 =  1.061405429;
  my $p  =  0.3275911;

  # Save the sign of x
  my $sign = 1;
  if ($x < 0) {
    $sign = -1;
    $x = -$x;
  }

  # A&S formula 7.1.26
  my $t = 1.0/(1.0 + $p*$x);
  my $y = 1.0 - ((((($a5*$t + $a4)*$t) + $a3)*$t + $a2)*$t + $a1)*$t*exp(-$x*$x);

  return $sign*$y;
}

