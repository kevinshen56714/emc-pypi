#!/usr/bin/env perl
#
#  module:	EMC::Element.pm
#  author:	Pieter J. in 't Veld
#  date:	November 25, 2021.
#  purpose:	Element operations; part of EMC distribution

#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211125	Inception of v1.0
#

package EMC::Element;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Message;
use EMC::List;

# functions

# element functions

sub type {
  return
    ref(@_[0]) eq "HASH" ? 2 :
    ref(@_[0]) eq "ARRAY" ? 1 : 0;
}


sub copy {
  my $type = type(@_[0]);
  
  return $type==1 ? [@{@_[0]}] : 
	 $type==2 ? {%{@_[0]}} : @_[0];
}


sub deep_copy {
  if (ref(@_[0]) eq "HASH") {
    my $result = defined(@_[1]) ? @_[1] : {};
    foreach (keys(%{@_[0]})) { $result->{$_} = deep_copy($_); }
    return $result;
  } elsif (ref(@_[0]) eq "ARRAY") {
    my $result = defined(@_[1]) ? @_[1] : [];
    foreach (@{@_[0]}) { push(@{$result}, deep_copy($_)); }
    return $result;
  } elsif (ref(@_[0]) eq "REF") {
    ${@_[1]} = ${@_[0]} if (ref(@_[1]) eq "REF");
    return ${@_[0]};
  }
  return @_;
}


sub null {
  my $type = type(@_);

  if ($type==0) {
    return 0;
  } elsif ($type==1) {
    return [(0) x scalar(@{@_[0]})];
  } elsif ($type==2) {
    my %e;
    foreach (keys(%{@_[0]})) {
      $e{$_} = $_ eq "index" ? copy(@_[0]->{$_}) : 0;
    }
    return {%e};
  }
}


sub add {
  my $e1 = shift(@_);
  my $e2 = shift(@_);

  if (@_[0] == 0) {
    $e1 += $e2;
  } elsif (@_[0] == 1) {
    foreach (0..(scalar(@{$e1})-1)) {
      $e1->[$_] += $e2->[$_];
    }
  } elsif (@_[0] == 2) {
    foreach (keys(%{$e1})) {
      $e1->{$_} += $e2->{$_} if ($_ ne "index");
    }
  }
  return $e1;
}


sub subtr {
  my $e1 = shift(@_);
  my $e2 = shift(@_);

  if (@_[0] == 0) {
    $e1 -= $e2;
  } elsif (@_[0] == 1) {
    foreach (0..(scalar(@{$e1})-1)) {
      $e1->[$_] -= $e2->[$_];
    }
  } elsif (@_[0] == 2) {
    foreach (keys(%{$e1})) {
      $e1->{$_} -= $e2->{$_} if ($_ ne "index");
    }
  }
  return $e1;
}


sub mult {
  my $e1 = shift(@_);
  my $e2 = shift(@_);

  if (@_[0] == 0) {
    $e1 *= $e2;
  } elsif (@_[0] == 1) {
    foreach (0..(scalar(@{$e1})-1)) {
      $e1->[$_] *= $e2->[$_];
    }
  } elsif (@_[0] == 2) {
    foreach (keys(%{$e1})) {
      $e1->{$_} *= $e2->{$_} if ($_ ne "index");
    }
  }
  return $e1;
}


sub mult_scalar {
  my $e1 = shift(@_);
  my $e2 = shift(@_);

  if (@_[0] == 0) {
    $e1 *= $e2;
  } elsif (@_[0] == 1) {
    foreach (0..(scalar(@{$e1})-1)) {
      $e1->[$_] *= $e2;
    }
  } elsif (@_[0] == 2) {
    foreach (keys(%{$e1})) {
      $e1->{$_} *= $e2 if ($_ ne "index");
    }
  }
  return $e1;
}


sub min {
  my $e1 = shift(@_);
  my $e2 = shift(@_);

  if (@_[0] == 0) {
    return $e2<$e1 ? $e2 : $e1;
  } elsif (@_[0] == 1) {
    $e1 = EMC::List::min($e1);
    $e2 = EMC::List::min($e2);
    return $e2<$e1 ? $e2 : $e1;
  } elsif (@_[0] == 2) {
    my $list = [];
    foreach (keys(%{$e1})) {
      push(@{$list}, min($e1->{$_}, $e2->{$_}, 0)) if ($_ ne "index");
    }
    return EMC::List::min($list);
  }
  return undef;
}


sub max {
  my $e1 = shift(@_);
  my $e2 = shift(@_);

  if (@_[0] == 0) {
    return $e2>$e1 ? $e2 : $e1;
  } elsif (@_[0] == 1) {
    $e1 = EMC::List::max($e1);
    $e2 = EMC::List::max($e2);
    return $e2>$e1 ? $e2 : $e1;
  } elsif (@_[0] == 2) {
    my $list = [];
    foreach (keys(%{$e1})) {
      push(@{$list}, max($e1->{$_}, $e2->{$_}, 0)) if ($_ ne "index");
    }
    return EMC::List::max($list);
  }
  return undef;
}


# hybrid functions

sub list {
  my $i;
  my $list = [];

  for ($i=0; $i<@_[1]; ++$i) {
    push(@{$list}, copy(@_[0]));
  }
  return $list;
}

