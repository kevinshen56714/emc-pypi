#!/usr/bin/env perl
#
#  module:	EMC::Dist.pm
#  author:	Pieter J. in 't Veld
#  date:	November 25, 2021.
#  purpose:	Distribution routines; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20211125	Inception of v1.0
#

package EMC::Dist;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::List;
use EMC::Message;
use EMC::Struct;


# functions

# dist functions

sub check {
  my $d = shift(@_);
  my $msg = shift(@_);

  if (ref($d) eq "HASH") {
    return $d if (
      defined($d->{nsamples}) && defined($d->{ntotal}) &&
      defined($d->{offset}) && defined($d->{dbin}) &&
      (defined($d->{nbins}) ? $d->{nbins} ? defined($d->{data}) : 1 : 0)
    );
  }
  EMC::Message::error("$msg: illegal distribution.\n");
}


sub pad_left {
  my $d = shift(@_);
  my $n = shift(@_); return $d if ($n<=0);

  $d->{nbins} = scalar(@{EMC::List::pad_left($d->{data}, $n)});
  $d->{offset} -= $n;
  return $d;
}


sub pad_right {
  my $d = shift(@_);
  my $n = shift(@_); return $d if ($n<=0);

  $d->{nbins} = scalar(@{EMC::List::pad_right($d->{data}, $n)});
  return $d;
}


sub repair {
  my $dist = shift(@_);

  $dist->{data} = [$dist->{data}] if (ref($dist->{data}) ne "ARRAY");
  return $dist;
}


sub add {
  my $msg = join(":", (caller)[1,2], " EMC::Dist::add");
  my $d1 = shift(@_);
  my $d2 = check(shift(@_), $msg);
  return {%{$d2}} if (!defined($d1));
  return {%{$d2}} if (!defined(check($d1, $msg)->{data}));

  my $type = EMC::Element::type(@{$d1->{data}}[0]);

  if ($d1->{dbin} ne $d2->{dbin}) {
    EMC::Message::error("$msg: dbin does not match.\n");
  }
  if (ref($d1->{data}) ne ref($d2->{data})) {
    EMC::Message::error("$msg: data reference does not match.\n");
  }
  foreach ("moment", "nsites", "volume") {
    if (defined($d1->{$_})^defined($d2->{$_})) {
      EMC::Message::error("$msg: $_ does not match.\n");
    }
  }
  
  $d1->{ntotal} += $d2->{ntotal};
  $d1->{nsamples} += $d2->{nsamples};
  foreach ("moment", "nsites", "volume") {
    if (defined($d1->{$_})) {
      my $key = $_ eq "moment" ? "ntotal" : "nsample";
      my @n = ($d1->{$key}, $d2->{$key});
      my @m = ($d1->{$_}, $d2->{$_});
      my $nt = @n[0]+@n[1];
      if ($_ eq "volume") {
	$d1->{$_} = $nt ? (@m[0]*@n[0]+@m[1]*@n[1])/$nt : 0;
      } else {
	for (my $i=0; $i<scalar(@{@m[0]}); ++$i) {
	  @m[0]->[$i] = $nt ? (@m[0]->[$i]*@n[0]+@m[1]->[$i]*@n[1])/$nt : 0;
	}
      }
    }
  }

  pad_left($d1, $d1->{offset}-EMC::Element::min($d1->{offset}, $d2->{offset}));
  my $j = $d2->{offset}-$d1->{offset};
  pad_right($d1, EMC::Element::max($d1->{nbins}, $d2->{nbins}+$j)-$d1->{nbins});
  
  for (my $i=0; $i<$d2->{nbins}; ++$i) {
    if ($type) {
      EMC::Element::add($d1->{data}->[$j], $d2->{data}->[$i], $type);
    } else {
      $d1->{data}->[$j] += $d2->{data}->[$i];
    }
    ++$j;
  }
  return $d1;
}


sub substr {
  my $msg = join(":", (caller)[1,2], " EMC::Dist::subtr");
  my $d1 = shift(@_);
  my $d2 = check(shift(@_), $msg);
  return {%{$d2}} if (!defined($d1));
  return {%{$d2}} if (!defined(check($d1, $msg)->{data}));

  my $type = EMC::Element::type(@{check($d1, $msg)->{data}}[0]);

  if ($d1->{dbin} ne $d2->{dbin}) {
    EMC::Message::error("$msg: dbin does not match.\n");
  }
  if (ref($d1->{data}) ne ref($d2->{data})) {
    EMC::Message::error("$msg: data reference does not match.\n");
  }
  foreach ("moment", "nsites", "volume") {
    if (defined($d1->{$_})^defined($d2->{$_})) {
      EMC::Message::error("$msg: $_ does not match.\n");
    }
  }
  
  $d1->{ntotal} -= $d2->{ntotal};
  $d1->{nsamples} -= $d2->{nsamples};
  foreach ("moment", "nsites", "volume") {
    if (defined($d1->{$_})) {
      my $key = $_ eq "moment" ? "ntotal" : "nsample";
      my @n = ($d1->{$key}, $d2->{$key});
      my @m = ($d1->{$_}, $d2->{$_});
      my $nt = @n[0]-@n[1];
      if ($_ eq "volume") {
	$d1->{$_} = $nt ? (@m[0]*@n[0]-@m[1]*@n[1])/$nt : 0;
      } else {
	for (my $i=0; $i<scalar(@{$m[0]}); ++$i) {
	  @m[0]->[$i] = $nt ? (@m[0]->[$i]*@n[0]-@m[1]->[$i]*@n[1])/$nt : 0;
	}
      }
    }
  }

  pad_left($d1, $d1->{offset}-EMC::Element::min($d1->{offset}, $d2->{offset}));
  my $j = $d2->{offset}-$d1->{offset};
  pad_right($d1, EMC::Element::max($d1->{nbins}, $d2->{nbins}+$j)-$d1->{nbins});

  for (my $i=0; $i<$d2->{nbins}; ++$i) {
    if ($type) {
      EMC::Element::subtr($d1->{data}->[$j], $d2->{data}->[$i], $type);
    } else {
      $d1->{data}->[$j] -= $d2->{data}->[$i];
    }
    ++$j;
  }
  return $d1;
}


# hybrid functions

sub list {
  my $msg = join(":", (caller)[1,2], " EMC::Dist::list");
  my $d = check(shift(@_), $msg);
  my $type = ref(@{$d->{data}}[0]) eq "HASH" ? 1 : 0;
  my $dbin = $d->{dbin};
  my $i = $d->{offset};
  my @data = map {[
    $dbin*$i++,
    $type ? $_->{n} ? $_->{accu}/$_->{weight} : 0 : $_]} @{$d->{data}};

  return \@data;
}

