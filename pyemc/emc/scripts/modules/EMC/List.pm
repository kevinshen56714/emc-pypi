#!/usr/bin/env perl
#
#  module:	EMC::List.pm
#  author:	Pieter J. in 't Veld
#  date:	November 25, 2021, May 2, November 30, 2024.
#  purpose:	List operations; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211125	Inception of v1.0
#    20240502	Added extract()
#    20241130	Improved compare()
#

package EMC::List;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Common;
use EMC::Element;
use EMC::Math;

# functions

# list functions

# manipulation

sub copy {
  return undef if (ref(@_[0]) ne "ARRAY");
  return [map({EMC::Element::copy($_)} @{@_[0]})];
}


sub check {
  my @check = (shift(@_));

  @check = @{@check[0]} if (ref(@check[0]) eq "ARRAY");
  foreach (@_) {
    foreach (ref($_) eq "ARRAY" ? @{$_} : ($_)) {
      my $item = $_;
      foreach (@check) {
	return 1 if ($_ eq $item);
      }
    }
  }
  return 0;
}


sub compare {
  return undef if (ref(@_[0]) ne "ARRAY" || ref(@_[1]) ne "ARRAY");
  my $n = @{@_[0]}<@{@_[1]} ? @{@_[0]} : @{@_[1]};
  for (my $i=0; $i<$n; ++$i) {
    return -1 if (@_[2] ? @_[0]->[$i] lt @_[1]->[$i] : @_[0]->[$i]<@_[1]->[$i]);
    return 1 if (@_[2] ? @_[0]->[$i] gt @_[1]->[$i] : @_[0]->[$i]>@_[1]->[$i]);
  }
  return @{@_[0]}<@{@_[1]} ? -1 : @{@_[1]}<@{@_[0]} ? 1 : 0;
}


sub depth {
  my $list = shift(@_);
  my $depth = defined(@_[0]) ? shift(@_) : 0;

  return 
    ref($list) eq "ARRAY" ? 
      max([map({depth($_, $depth+1)} @{$list})]) : $depth;
}


sub drop {
  my $sep = shift(@_);
  my $select;

  foreach (@_) {
    foreach (ref($_) eq "ARRAY" ? @{$_} : $_) {
      last if (substr($_,0,length($sep)) eq $sep);
      $select = [] if (!defined($select));
      push(@{$select}, $_);
    }
  }
  return $select;
}


sub flatten {
  my $dest = scalar(@_)>1 ? shift(@_) : [];
  my $src = shift(@_);

  return $src if (ref($src) ne "ARRAY");
  
  foreach (@{$src}) {
    push(@{$dest}, ref($_) eq "ARRAY" ? @{flatten($_)} : $_);
  }
  return $dest;
}


sub extract {
  my $sep = shift(@_);
  my $attr = ref(@_[0]) eq "HASH" ? EMC::Common::attributes(shift(@_)) :
	     ref(@_[-1]) eq "HASH" ? EMC::Common::attributes(pop(@_)) : undef;
  my $not = EMC::Common::element($attr, "not") ? 1 : 0;
  my $last = EMC::Common::element($attr, "last");
  my $flag = length($sep) ? 1 : 0;
  my $l = length($last);
  my $select;

  ARG: foreach (@_) {
    foreach (ref($_) eq "ARRAY" ? @{$_} : $_) {
      next if (($flag ? ($_ =~ m/$sep/) ? 0 : 1 : length($_) ? 1 : 0)^$not);
      last ARG if ($l && substr($_,0,$l) eq $last);
      $select = [] if (!defined($select));
      push(@{$select}, $_);
    }
  }
  return $select;
}


sub hash {
  my $list = shift(@_);

  return undef if (ref($list) ne "ARRAY");

  my $hash;
  my $i = 0;

  foreach (@{$list}) {
    if (ref($_) eq "") {
      $hash = {} if (!defined($hash));
      $hash->{$_} = $i;
    } elsif (ref($_) eq "ARRAY") {
      $hash = {} if (!defined($hash));
      $hash->{$_->[0]} = $_->[1];
    }
    ++$i;
  }
  return $hash;
}


sub index {
  my $list = shift(@_);

  return undef if (ref($list) ne "ARRAY");

  my $i = 0;
  my $target = shift(@_);

  foreach (@{$list}) {
    return $i if ($_ eq $target);
    ++$i;
  }
  return undef;
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


sub permutations {
  my $list = shift(@_);

  return $list if (ref($list) ne "ARRAY");

  my $result = [];					# initialize counters
  my @i = (0) x scalar(@{$list});
  my @n = map({ref($_) eq "ARRAY" ? scalar(@{$_}) : 0} @{$list});

  for (my $k=0; $k<scalar(@{$list}); ) {
    my $j = 0;						# assign
    push(@{$result},
      [map({ref($_) eq "ARRAY" ? $_->[@i[$j++]] : $j++ ? $_ : $_} @{$list})]);
    $k = 0;
    foreach (@i) {					# advance
      last if (++$_<@n[$k]);
      $_ = 0;
      ++$k;
    }
  }
  return $result;
}


sub replace {
  my ($list, $replace) = @_;

  return undef if (ref($list) ne "ARRAY");
  if (ref($replace) eq "HASH") {
    foreach (@{$list}) {
      $_ = $replace->{$_} if (defined($replace->{$_}));
    }
  }
  return $list;
}


sub sort {
  my ($list, $freq, $up) = @_;

  my $list = shift(@_);
  my $freq = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $reverse = defined(@_[0]) ? shift(@_)&3 : 0;	# bitwise list & freq

  return $list if (ref($list) ne "ARRAY");
  if (defined($freq)) {
    if ($reverse == 0) {				# standard
      @{$list} = sort(
	{$freq->{$a}==$freq->{$b} ? $a cmp $b : $freq->{$a}<=>$freq->{$b}}
	@{$list});
    } elsif ($reverse == 1) {				# reverse list
      @{$list} = sort(
	{$freq->{$a}==$freq->{$b} ? $b cmp $a : $freq->{$a}<=>$freq->{$b}}
	@{$list});
    } elsif ($reverse == 2) {				# reverse freq
      @{$list} = sort(
	{$freq->{$a}==$freq->{$b} ? $a cmp $b : $freq->{$b}<=>$freq->{$a}}
	@{$list});
    } elsif ($reverse == 3) {				# reverse list & freq
      @{$list} = sort(
	{$freq->{$a}==$freq->{$b} ? $b cmp $a : $freq->{$b}<=>$freq->{$a}}
	@{$list});
    }
  } else {
    @{$list} = $reverse ? reverse(sort(@{$list})) : sort(@{$list});
  }
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
  my $i = 0;

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


sub filter {					# apply band filter
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


# option list functions

sub allow {					# <= list_allow
  my $hash = shift(@_);

  return undef if (!defined($hash));

  my $list = {};

  foreach (keys(%{$hash})) {
    $list->{$_} = 1 if ($_ ne "flag");
  }
  return $list;
}


sub drop_comment {
  my $list = shift(@_);

  if (ref($list) eq "ARRAY") {
    my $i = 0;
    foreach (@{$list}) { last if (substr($_,0,1) eq "#"); ++$i; }
    @{$list} = splice(@{$list}, 0, $i);
  }
  return $list;
}


sub eval {					# <= eval_parms
  foreach (@_) { $_ = eval($_); }
  return @_;
}


sub ran {
  return @_[int(rand(scalar(@_)))];
}


sub smiles {
  my $string = shift(@_);
  my $attr = shift(@_);
  my $line = EMC::Common::element($attr, "line") ? $attr->{line} : -1;
  my $filter = EMC::Common::element($attr, "filter") ? $attr->{filter} : undef;
  my $list = [];
  my $sub = "";
  my $l = 0;
  my $s = 0;

  return $list if (!length($string));
  foreach (split("", $string)) {
    next if ($_ eq " ");
    next if (defined($filter) && defined($filter->{$_}));
    if ($_ eq "(") { 
      $sub .= $_ if ($l);
      ++$l;
    } elsif ($_ eq ")") { 
      if (--$l<0) {
	EMC::Message::error_line($line, "parenthesis mismatch\n");
      } elsif (!$l) {
	push(@{$list}, smiles($sub, $attr)) if (length($sub));
	$sub = "";
      } else {
	$sub .= $_;
      }
    } elsif ($_ eq "[") {
      $sub .= $_ if ($l);
      ++$s;
    } elsif ($_ eq "]") {
      if (--$s<0) {
	EMC::Message::error_line($line, "bracket mismatch\n");
      } elsif (!$s) {
	if ($l) {
	  $sub .= $_;
	} else {
	  push(@{$list}, $sub) ;
	  $sub = "";
	}
      }
    } else {
      if ($l||$s) {
	$sub .= $_;
      } else {
	push(@{$list}, $_);
      }
    }
  }
  if ($l) {
    EMC::Message::error_line($line, "parenthesis mismatch\n");
  } elsif ($s) {
    EMC::Message::error_line($line, "bracket mismatch\n");
  }
  return $list;
}


sub set_list_oper {
  my $line = shift(@_);
  my $oper = shift(@_);	
  my $phases = $oper->{phases};
  my $default = $oper->{default};
  my $first = 1;
  my $phase = $default->{phase};
  my %allowed = (
    mode => {distance => 1, random => 1},
    type => {absolute => 1, relative => 1}
  );
  my @args = @_;

  if (scalar(@args)==1) {
    @args = split(" ", @args[0]);
  }
  $oper = EMC::Element::deep_copy($default);
  foreach (@args) {
    my $i = index($_, "=");
    my $key = $i<0 ? $_ : substr($_,0,$i);
    my @arg = $i<0 ? undef : split(":", substr($_, $i+1));
    my $all = 0;

    if ($i<0) {
      EMC::Message::error_line($line, "missing equal sign\n") if ($key ne "+");
    } elsif (!defined($oper->{$key})) {
      EMC::Message::error_line($line, "illegal oper keyword '$key'\n");
    }
    foreach (@arg) { 
      $_ =~ s/^"+|"+$//g;
      if ($_ eq "all") { $all = 1; last; }
    }
    if ($key eq "phase" || $key eq "+") {
      if (!$first) {
	$oper->{phases} = $phases = [] if (!defined($phases));
	$phases->[$phase] = $oper;
      }
      $oper = EMC::Element::deep_copy($default);
      $oper->{phase} = $phase = eval(@arg[0]);
    } elsif ($key eq "clusters") {
      $oper->{clusters} = $all ? "all" : [@arg];
    } elsif ($key eq "groups") {
      $oper->{groups} = $all ? "all" : [@arg];
    } elsif ($key eq "sites") {
      $oper->{sites} = $all ? "all" : [@arg];
    } elsif ($key eq "fraction") {
      $oper->{fraction} = @arg[0];
    } else {
      if (defined($oper->{$key}) ? 0 :
	  defined(${$allowed{$key}}{@arg[0]})) {
	EMC::Message::error_line($line, "illegal option for keyword '$key'\n");
      }
      if (ref($oper->{$key}) eq "ARRAY") {
	my $ptr = $oper->{$key};
	my $n = scalar(@arg);

	$n = scalar(@{$ptr}) if ($n>scalar(@{$ptr}));
	for (my $i=0; $i<$n; ++$i) {
	  $ptr->[$i] = @arg[$i];
	}
      } else {
	$oper->{$key} = @arg[0];
      }
    }
    $first = 0;
  }
  if (!$first) {
    $oper->{phases} = $phases = [] if (!defined($phases));
    $phases->[$phase] = $oper;
  }
  return $oper;
}


sub string {
  my $list = shift(@_);
  my $attr = shift(@_);
  my $text = "";
  my $separator;

  return EMC::Hash::string($list) if (ref($list) eq "HASH");
  return $list if (ref($list) ne "ARRAY");
  $text = defined($attr->{parens}) ?
    ref($attr->{parens}) eq "ARRAY" ? $attr->{parens}->[0] : "" : "{";
  foreach (@{$list}) {
    $text .= $separator.EMC::List::string($_);
    next if (defined($separator));
    $separator = ", ";
  }
  $text .= defined($attr->{parens}) ?
    ref($attr->{parens}) eq "ARRAY" ? $attr->{parens}->[1] : "" : "}";
  return $text;
}


sub trim {
  my $list = shift(@_);

  if (ref($list) eq "ARRAY") {
    while (scalar(@{$list}) && $list->[0] eq "") { shift(@{$list}); }
    while (scalar(@{$list}) && $list->[-1] eq "") { pop(@{$list}); }
  }
  return $list;
}


sub unique {					# <= list_unique
  my $line = shift(@_);
  my %check = ();
  my @list;

  foreach (@_) {
    if (defined($check{$_})) {
      if ($line>0) {
	EMC::Message::warning(
	  "omitting reoccurring entry '$_' in line $line of input.\n");
      }
      next;
    }
    push(@list, $_);
    $check{$_} = 1;
  }
  return @list;
}

