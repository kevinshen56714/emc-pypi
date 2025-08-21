#!/usr/bin/env perl
#
#  module:	EMC::Hash.pm
#  author:	Pieter J. in 't Veld
#  date:	November 25, 2021, May 2, 2024.
#  purpose:	Hash operations; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211125	Inception of v1.0
#    20240502	Added optional ARRAY ref in arguments()
#

package EMC::Hash;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Element;
use EMC::List;
use EMC::Math;
use EMC::Message;

# functions

# hash functions

# manipulation

sub cat {
  return undef if (ref(@_[0]) ne "HASH");
  
  my $hash = {};

  foreach (@_) {
    my $ptr = $_;
    foreach (keys(%{$ptr})) {
      $hash->{$_} = EMC::Element::deep_copy($ptr->{$_});
    }
  }
  return $hash;
}


sub define {
  return undef if (ref(@_[0]) ne "HASH");
  
  my $hash = shift(@_);
  my $value = shift(@_);

  foreach (keys(%{$hash})) {
    $hash->{$_} = EMC::Element::deep_copy($value);
  }
  return $hash;
}


sub copy {
  return undef if (ref(@_[0]) ne "HASH");
  return EMC::Element::deep_copy(@_[0]);
}


sub list {
  my $hash = shift(@_);

  return undef if (ref($hash) ne "HASH");

  my $list = [];
  foreach (sort(keys(%{$hash}))) {
    push(@{$list}, [$_, $hash->{$_}]);
  }
  return $list;
}


sub select {
  my $main = shift(@_);
  my $hash = {};

  foreach (@_) {
    $hash->{$_} = $main->{$_} if (defined($main->{$_}));
  }
  return $hash;
}


sub sort {
  my $hash = shift(@_);
  return 
    [sort(
	{$hash->{$a}==$hash->{$b} ? $a cmp $b : $hash->{$a}<=>$hash->{$b}}
       	keys(%{$hash}))];
}


sub string {
  my $hash = shift(@_);
  my $text = "";
  my $separator;

  return EMC::List::string($hash) if (ref($hash) eq "ARRAY");
  return $hash if (ref($hash) ne "HASH");
  $text = "{";
  foreach (sort(keys(%{$hash}))) {
    $text .= $separator."$_ -> ".EMC::Hash::string($hash->{$_});
    next if (defined($separator));
    $separator = ", ";
  }
  $text .= "}";
  return $text;
}


# operations

sub ignore {
  my $list = shift(@_);
  my $hash = {};

  if (defined($list) && ref($list) ne "HASH")
  {
    EMC::Message::trace();
    EMC::Message::spot("list = ", $list, "\n");
  }
  $hash->{flag} = 1;
  $hash->{ignore} = 1;
  if (defined($list->{ignore})) {
    foreach (@{$list->{ignore}}) {
      $hash->{$_} = 1;
    }
  }
  return $hash;
}


sub arguments {
  my $hash = ref(@_[0]) eq "HASH" ? shift(@_) : {};
  my $attr = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  
  my $error = EMC::Element::extract($attr, "error");
  my $line = EMC::Element::extract($attr, "line", -1);
  my $order = EMC::Element::extract($attr, "order");
  my $default = EMC::Element::extract($attr, "default");
  my $replace = EMC::Element::extract($attr, "replace");
  my $special = EMC::List::hash(EMC::Element::extract($attr, "special"));
  my $type = EMC::Element::extract($attr, "type", "string");
  my $ignore = EMC::Hash::ignore($hash);
  my $iorder = 0;

  $order = undef if (ref($order) ne "ARRAY");
  foreach (@_) {
    foreach (ref($_) eq "ARRAY" ? @{$_} : $_) {
      my @arg = split("=");
      if (defined($replace) && EMC::Common::element($replace, @arg[0])) {
	@arg[0] = $replace->{@arg[0]};
      }
      if (scalar(@arg) == 1) {
	if ($order) {
	  if ($iorder<scalar(@{$order})) {
	    @arg = ($order->[$iorder++], @arg[0]);
	  } else {
	    next if (!$error);
	    EMC::Message::error_line($line, "too many arguments\n");
	  }
	} else {
	  @arg = split(":");
	  @arg = (shift(@arg), join(":", @arg)) if (scalar(@arg)>1);
	}
      }
      if ($error && 
	      (!defined($hash->{@arg[0]}) || defined($ignore->{@arg[0]}))) {
	#EMC::Message::dumper("hash = ", $hash);
	EMC::Message::error_line(
	  $line, "illegal option \'@arg[0]\'\n") if (!EMC::Math::flag_q(@arg[0]));
      }
      if (defined($special->{@arg[0]}) || $type eq "string") {
	@arg[1] =~ s/^"+|"+$//g;				# strip quotes
      } elsif ($type eq "array") {
	my @a = split(":", @arg[1]);
	@arg[1] = $default ? [@a, @{$hash->{@arg[0]}}] : [@a];
      } elsif ($type eq "boolean") {
	if (scalar(@arg) == 1) {
	  if ($default eq "") {
	    @arg = (@arg[0], 1);
	  }
	  elsif (
	      @arg[0] eq "0" || @arg[0] eq "1" ||
	      @arg[0] eq "false" || @arg[0] eq "true") {
	    @arg = ($default, @arg[0]);
	  }
	}
	if (@arg[1] eq "true" || @arg[1] eq "") {
	  @arg[1] = 1;
	} elsif (@arg[1] eq "false") {
	  @arg[1] = 0;
	} elsif (@arg[1] == 0 && @arg[1] ne "0") {
	  EMC::Message::error_line($line, "illegal option value \'@arg[1]\'\n");
	}
	@arg[1] = 1 if (scalar(@arg)==1);
	@arg[1] = 0 if (@arg[1] eq "false");
	@arg[1] = 1 if (@arg[1] eq "true");
      } elsif ($type eq "integer") {
	@arg[1] = int(eval(@arg[1]));
	@arg[1] = 0 if (@arg[1]<0);
      } elsif ($type eq "real") {
	@arg[1] = eval(@arg[1]);
      }
      $hash->{@arg[0]} = @arg[1];
    }
  }
  $hash->{flag} = 1;
  return $hash;
}


sub set {
  my $line = shift(@_);
  my $hash = shift(@_);
  my $type = shift(@_);
  my $default = shift(@_);
  my $special = shift(@_);

  foreach (@_) {
    foreach (@{separate($_)}) {
      my @arg = split("=>");
    
      if (scalar(@arg)==1) {
	arguments($hash, {
	    error => 1, line => $line, type => $type, default => $default,
	    special => $special
	  }, @arg);
      } elsif (scalar(@arg)==2) {
	$hash->{@arg[0]} = set(
	  $line, $hash->{@arg[0]}, $type, $default, $special, EMC::Common::strip(@arg[1]));
      } else {
	EMC::Message::error_line($line, "too many hash indicators\n");
      }
    }
  }
  return $hash;
}


sub separate {
  my $line = shift(@_);
  my $args = shift(@_);
  my $level = 0;
  my $arg;

  $args = [] if (ref($arg) ne "ARRAY");
  foreach (split("", $line)) {
    ++$level if ($_ eq "{");
    --$level if ($_ eq "}");
    if ($_ eq "," && !$level) {
      push(@{$args}, EMC::Common::trim($arg));
      $arg = "";
    } else {
      $arg .= $_;
    }
  }
  $arg = EMC::Common::trim($arg);
  push(@{$args}, $arg) if (scalar($arg));
  return $args;
}


sub text {
  my $hash = shift(@_);
  my $type = shift(@_);
  my $ignore = EMC::Hash::ignore($hash);
  my $special = {}; foreach (@_) { $special->{$_} = 1; }
  my @arg;

  foreach (sort(keys(%{$hash}))) {
    next if (defined($ignore->{$_}));
    my $result;
    if (ref($hash->{$_}) eq "HASH") {
      $result = ">{".EMC::Hash::text($hash->{$_})."}";
    } elsif (ref($hash->{$_}) eq "ARRAY") {
      $result = join(":", @{$hash->{$_}});
    } elsif (defined($special->{$_})) {
      $result = $hash->{$_};
    } elsif ($type eq "array") {
      $result = join(":", @{$hash->{$_}});
    } elsif ($type eq "boolean") {
      $result = EMC::Math::boolean($hash->{$_});
    } else {
      $result = $hash->{$_};
    }
    push(@arg, "$_=$result");
  }
  return join(", ", @arg);
}


sub variables {
  my $hash = {};

  foreach (@_) {
    my @arg = split("=");
    $hash->{@arg[0]} = eval(@arg[1]);
  }
  return $hash;
}

