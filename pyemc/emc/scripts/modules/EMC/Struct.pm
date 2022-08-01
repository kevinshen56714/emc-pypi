#!/usr/bin/env perl
#
#  module:	EMC::Struct.pm
#  author:	Pieter J. in 't Veld
#  date:	December 10, 2021.
#  purpose:	Structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20211210	Inception of v1.0
#

package EMC::Struct;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Common;
use EMC::Element;
use EMC::Math;
use EMC::Message;


# functions

sub set_index {
  my $struct = shift(@_);
  my $list = shift(@_);
  my $index;

  foreach (@{$list}) {
    $index = [] if (!defined($index));
    push(@{$index}, $_) if (defined($struct->{$_}));
  }
  if (defined($index)) {
    $struct->{index} = $index;
  } else {
    undef($struct->{index});
  }
  return $struct;
}


# analysis

sub compare {
  my @v = (shift(@_), shift(@_));
  my @t = map({EMC::Element::type($_)} @v);
  my $r = @t[0]<@t[1] ? -1 : @t[0]>@t[1] ? 1 : 0;

  return $r if ($r);
  if (@t[0] == 0) {
    if (EMC::Math::number_q(@v[0]) && EMC::Math::number_q(@v[1])) {
      return @v[0]<@v[1] ? -1 : @v[0]>@v[1] ? 1 : 0;
    } else {
      return @v[0] lt @v[1] ? -1 : @v[0] gt @v[1] ? 1 : 0;
    }
  } elsif (@t[0] == 1) {
    my @n = map({scalar(@{$_})} @v);
    $r = @n[0]<@n[1] ? -1 : @n[0]>@n[1] ? 1 : 0;
    return $r if ($r);
    for (my $i=0; $i<@n[0]; ++$i) {
      $r = compare(@v[0]->[$i], @v[1]->[$i]);
      return $r if ($r);
    }
  } else {
    my @n = map({scalar(keys(%{$_}))} @v);
    $r = @n[0]<@n[1] ? -1 : @n[0]>@n[1] ? 1 : 0;
    return $r if ($r);
    foreach (sort(keys(%{@v[0]}))) {
      return 1 if (!defined(@v[1]->{$_}));
      $r = compare(@v[0]->{$_}, @v[1]->{$_});
      return $r if ($r);
    }
  }
  return $r;
}


# read

sub read {
  my $stream = shift(@_);
  my $attr = {order => 1};
  my %stack = (name => [], struct => [], value => []);
  my $fcomment = 0;
  my $fstring = 0;
  my $level = 0;
  my @read;
  my @value;
  my $name;
  my $last;
  my $line;
  my $struct = defined($attr->{struct}) ? $attr->{struct} : undef;
  my $index = 
	    defined($attr->{index}) ? $attr->{index} ? 1 : 0 : 0;

  $attr = EMC::Common::attributes($attr, shift(@_));
  foreach (<$stream>) {
    ++$line;
    foreach (split("")) {
      if ($fcomment) {
	$fcomment = 0 if ($_ eq ")" && $last eq "*");
      } elsif ($fstring) {
	push(@read, $_) if ($_ ne "\"");
	$fstring = 0 if ($_ eq "\"");
      } else {
	if ($_ eq "{") {
	  ++$level;
	  push(@{$stack{struct}}, $struct);
	  push(@{$stack{name}}, $name);
	  push(@{$stack{value}}, [@value]);
	  undef(@value);
	  undef($name);
	  undef($struct);
	} elsif ($_ eq "}") {
	  --$level;
	  if (@read) {
	    if (defined($name)) {
	      $struct->{$name} = 
		scalar(@value) ? 
		  scalar(@value)>1 ? [@value] : @value[0] : join("", @read);
	      if ($index) {
		$struct->{index} = [] if (!defined($struct->{index}));
		push(@{$struct->{index}}, $name);
	      }
	    } else {
	      push(@value, join("", @read));
	    }
	    undef(@read);
	  } else {
	    push(@value, $struct) if (defined($struct));
	  }
	  $name = pop(@{$stack{name}});
	  if (defined($name)) {
	    my $current = $struct;
	    $struct = pop(@{$stack{struct}});
	    $struct->{$name} =
	      scalar(@value) ?
		scalar(@value)>1 ? [@value] : @value[0] : $current;
	    if ($index) {
	      $struct->{index} = [] if (!defined($struct->{index}));
	      push(@{$struct->{index}}, $name);
	    }
	  } else {
	    pop(@{$stack{struct}});
	  }
	  @value = @{pop(@{$stack{value}})};
	} elsif ($_ eq "," || $_ eq ";") {
	  if (defined($name)) {
	    if (@read) {
	      $struct->{$name} = join("", @read);
	      if ($index) {
		$struct->{index} = [] if (!defined($struct->{index}));
		push(@{$struct->{index}}, $name);
	      }
	    }
	  } else {
	    push(@value, @read ? join("", @read) : $struct);
	  }
	  undef($name);
	  undef(@read);
	} elsif ($_ eq "\"") {
	  $fstring ^= 1;
	} else {
	  if (!$fstring) {
	    if (($_ eq ">" && $last eq "-") || $_ eq "=") {
	      pop(@read);
	      $name = join("", @read);
	      undef(@read);
	      next;
	    } elsif ($_ eq "\^" && $last eq "*") {
	      @read[-1] = "e";
	      next;
	    } elsif ($_ eq "*" && $last eq "(") {
	      $fcomment = 1;
	      pop(@read);
	      undef(@read) if (!scalar(@read));
	      next;
	    } elsif ($_ le " ") {
	      next;
	    }
	  }
	  push(@read, $_);
	}
      }
      $last = $_;
    }
  }
  return $struct;
}


# write

sub write_newline {
  my $format = shift(@_);
  my $stream = $format->{stream};

  return if (!defined($format));
  return if (!defined($format->{text}));
  return if ($format->{text} eq "");
  $format->{depth} += () = $format->{text} =~ m/\{/g;
  $format->{depth} -= () = $format->{text} =~ m/\}/g;
  print($stream EMC::Common::trim($format->{text}), "\n");
  my $n = $format->{column} = $format->{offset}+2*$format->{depth};
  for (my $i=0; $i<$n; ++$i) {
    print($stream " ");
  }
  undef($format->{text});
  ++$format->{line};
}


sub write_format {
  my $format = shift(@_);
  my $text = shift(@_);

  if ($text eq "\n") {
    write_newline($format);
  } else {
    my $l = length($text)+length($format->{text});
    write_newline($format) if ($format->{column}+$l+3>=$format->{width});
    $format->{text} = $format->{text}.$text;
  }
}


sub write {
  my $stream = shift(@_);
  my $struct = shift(@_);
  my $format = EMC::Common::attributes(@_);
  my $comma;

  $format->{line} = 0 if (!defined($format->{line}));
  $format->{level} = 0 if (!defined($format->{level}));
  $format->{offset} = 0 if (!defined($format->{offset}));
  $format->{column} = 0 if (!defined($format->{column}));
  $format->{indent} = 0 if (!defined($format->{indent}));
  $format->{width} = 80 if (!defined($format->{width}));
  $format->{stream} = $stream if (!defined($format->{stream}));

  ++$format->{level};
  if (ref($struct) eq "HASH") {
    my @index = 
	  defined($struct->{index}) ? 
	  @{$struct->{index}} : sort(keys(%{$struct}));

    write_format($format, "\n") if (defined($format->{text}));
    $format->{text} .= "{";
    foreach (@index) {
      next if (!defined($struct->{$_}));
      $format->{text} .= $comma if (defined($comma));
      #write_format($format, "\n") if ($comma ne "");
      write_format($format, "$_ -> ");
      EMC::Struct::write($stream, $struct->{$_}, $format);
      $comma = ", ";
    }
    $format->{text} .= "}";
  } elsif (ref($struct) eq "ARRAY") {
    $format->{text} .= "{";
    write_format($format, "\n");
    my $comma;
    foreach (@{$struct}) {
      $format->{text} .= $comma if (defined($comma));
      write_format($format, "");
      EMC::Struct::write($stream, $_, $format);
      $comma = ", ";
    }
    $format->{text} .= "}";
  } else {
    $format->{text} .= EMC::Math::number_q($struct) ? $struct : "\"$struct\"";
  }
  --$format->{level};
  return if ($format->{level}); 
  write_format($format, "\n");
}

