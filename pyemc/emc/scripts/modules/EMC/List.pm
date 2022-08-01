#!/usr/bin/env perl
#
#  module:	EMC::List.pm
#  author:	Pieter J. in 't Veld
#  date:	November 25, 2021.
#  purpose:	List operations; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211125	Inception of v1.0
#

package EMC::List;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Element;
use EMC::Math;

# functions

# list functions

# manipulation

sub copy {
  return undef if (ref(@_[0]) ne "ARRAY");
  return map({EMC::Element::copy($_)} @{@_[0]});
}


sub pad_left {
  my $list = shift(@_); return undef if (ref($list) ne "ARRAY");
  my $n = shift(@_); return scalar(@{$list}) if ($n<=0);

  unshift(@{$list}, @{EMC::Element::list(EMC::Element::null($list->[0]), $n)});
  return $list;
}


sub pad_right {
  my $list = shift(@_); return undef if (ref($list) ne "ARRAY");
  my $n = shift(@_); return scalar(@{$list}) if ($n<=0);

  push(@{$list}, @{EMC::Element::list(EMC::Element::null($list->[0]), $n)});
  return $list;
}


sub take {
  my $list = shift(@_); return undef if (ref($list) ne "ARRAY");
  my $n = shift(@_);
  my $type = EMC::Element::type($n);

  return undef if ($type==2);
  @{$list} = $type==1 ? @{$list}[$n->[0]..$n->[1]] :
	     $n<0 ? @{$list}[$n..-1] : @{$list}[0..($n-1)];
  return $list;
}


sub transpose {
  my $list = shift(@_); return undef if (ref($list) ne "ARRAY");
  return $list if (ref(@{$list}[0]) ne "ARRAY");
  my $result = [];

  foreach (@{@{$list}[0]}) {
    push(@{$result}, []);
  }
  foreach (@{$list}) {
    my $i = 0; foreach(@{$_}) {
      push(@{@{$result}[$i++]}, $_);
    }
  }
  @{$list} = @{$result};
  return $list;
}


# analysis

sub min {
  my $list = shift(@_);
  my $min = $list->[0];

  foreach (@{$list}) { $min = $_ if ($_<$min); }
  return $min;
}


sub max {
  my $list = shift(@_);
  my $max = $list->[0];

  foreach (@{$list}) { $max = $_ if ($_>$max); }
  return $max;
}


sub sum {
  return undef if (ref(@_[0]) ne "ARRAY");
  my $sum = EMC::Element::null(@_[0]->[0]);

  foreach (@{@_[0]}) { $sum = EMC::Element::add($sum, $_); }
  return $sum;
}


sub extremes {
  return undef if (ref(@_[0]) ne "ARRAY");
  my $list = [@{shift(@_)}];
  my $result = {min => [], max => []};

  transpose($list);
  foreach (@{$list}) {
    push(@{$result->{"min"}}, min($_));
    push(@{$result->{"max"}}, max($_));
  }
  return $result;
}


# operations

sub dot {
  return undef if (ref(@_[0]) ne "ARRAY" || ref(@_[1]) ne "ARRAY");
  my $dot = EMC::Element::null(@_[0]->[0]);
  my @t = map({EMC::Element::type($_)} (@_[0]->[0], @_[1]->[0]));
  my $i=0;

  return undef if(@t[0]!=@t[1] && @t[1]);
  if (@t[1]) {
    foreach (@{@_[0]}) { 
      EMC::Element::add($dot,
	EMC::Element::mult(
	  EMC::Element::copy($_), @_[1]->[$i++], @t[0]), @t[0]);
    }
  } else {
    foreach (@{@_[0]}) { 
      EMC::Element::add($dot,
	EMC::Element::mult_scalar(
	  EMC::Element::copy($_), @_[1]->[$i++], @t[0]), @t[0]);
    }
  }
  return $dot;
}


sub filter {
  my $list = shift(@_);
  
  return undef if (ref($list) ne "ARRAY");
  
  my $n = shift(@_);
  my $attr = shift(@_);
  my %flag = (periodic => 0, type => 2, zero => 0);
  my @w = map({$_-0.5*($n+1)} 1..$n);

  if (ref($attr) eq "HASH") {
    foreach (keys(%{$attr})) {
      $flag{$_} = $attr->{$_} ? 1 : 0 if (defined($flag{$_}));
    }
  }
  my $type = $flag{type};
  @w = $type==2 ? map({sqrt(0.25*$n*$n-$_*$_)} @w) :
       $type==3 ? map({EMC::Math::erf((5.0*$_+0.5)/$n)-
		       EMC::Math::erf((2.5*$_-0.5)/$n)} @w) : 
       (1.0) x $n;
  my $norm = sum(\@w);
  @w = map({$_/$norm} @w) if ($norm);
  my $m = $n-1;
  @{$list} = map(
    {my @l = @{$list}[$_..($_+$m)]; dot(\@l, \@w)} 0..(scalar(@{$list})-$n));
  return $list;
}

