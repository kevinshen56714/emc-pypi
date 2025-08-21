#!/usr/bin/env perl
#
#  module:	EMC::Atoms.pm
#  author:	Pieter J. in 't Veld
#  date:	November 30, 2024.
#  purpose:	Atoms structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  members
#    atom
#      bond	HASH	connected atom ids with bond as element
#      charge	REAL	atom partial charge
#      connect	LIST	ordered list of connected atom ids
#      element	STRING	chemical element
#      formal	REAL	formal charge
#      gconnect	LIST	connections to other groups
#      group	HASH	pointer to element of residue->{groups}
#      id	INTEGER	numerical id representing import order
#      type	STRING	force field atom type
#
#    atoms	HASH	above atom structure
#
#  notes:
#    20241130	Inception of v1.0
#

package EMC::Atoms;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

#use vars qw($Pi);

use EMC::Message;

# functions

# element

sub decoration {
  my @c = split("", shift(@_));
  my $bonds = {"~" => 0, "-" => 2, ":" => 3, "=" => 4, "#" => 6};
  my ($bond, $ring);

  while (1) {
    if ($bonds->{@c[0]}) {
      $bond = shift(@c);
    } elsif (@c[0] eq "^") {
      shift(@c);
      while (EMC::Math::number_q(@c[0])) {
	$ring .= shift(@c);
      }
    } else {
      last;
    }
  }
  return (join("", @c), $bond, $ring);
}


# atom

sub aromatic {
  my $atom = shift(@_);
  my $ring = {5 => 1, 6 => 1};
  my $bond = defined($atom->{bond}) ? $atom->{bond} : undef;

  if (defined($ring->{$atom->{ring}})) {
    my $npartial = 0;
    foreach (keys(%{$bond})) {
      ++$npartial if ($bond->{$_} eq ":");
    }
    return $npartial>1 ? 1 : 0;
  }
  return 0;
}


# atoms

sub assign {
  my $atoms = shift(@_);
  my $attr = shift(@_);
  my $united = $attr->{united};

  foreach (keys(%{$atoms})) {
    my $atom = $atoms->{$_};
    my $bond = $atom->{bond};
    
    $atom->{aromatic} = 1 if (EMC::Atoms::aromatic($atom));
    my $connect = $atom->{connect} = [
      sort({EMC::Atoms::compare($atoms, $bond, $a, $b)} keys(%{$bond}))];

    $atom->{name} = $_;
  }
  foreach (keys(%{$atoms})) {
    my $atom = $atoms->{$_};
    my $bond = $atom->{bond};
    my $formal = $united ? 0 : EMC::Atoms::formal($atoms, $_);
    
    $atom->{formal} = $formal if ($formal);

    if (defined($atom->{group})) {
      foreach (@{$atom->{connect}}) {
	my $id = $_;
	next if (!defined($atoms->{$id}->{group}));
	next if ($atoms->{$id}->{group} == $atom->{group});
	$atom->{gconnect} = [] if (!defined($atom->{gconnect}));
	push(@{$atom->{gconnect}}, $_);
      }
    }
  }
  return $atoms;
}


sub compare {
  my ($atoms, $bond, $a, $b) = @_;
  my $a_element = $atoms->{$a}->{element};
  my $b_element = $atoms->{$b}->{element};
  my $a_bond = $bond->{$a};
  my $b_bond = $bond->{$b};
  my $order = {"~" => 0, "-" => 2, ":" => 3, "=" => 4, "#" => 6};

  $a_element = "ZZ" if ($a_element eq "H");
  $b_element = "ZZ" if ($b_element eq "H");
  return 
    $a_element eq $b_element ?
      $a_bond eq $b_bond ? $atoms->{$a}->{id} <=> $atoms->{$b}->{id} : 
	$order->{$b_bond} <=> $order->{$a_bond} : $a_element cmp $b_element;
}


sub formal {
  my $atoms = shift(@_);
  my $atom = $atoms->{shift(@_)};

  return $atom->{formal} if (defined($atom->{formal}));

  my $element = $atom->{element};
  my $delta = {C => 4, N => 3, O => 0, P => 5, S => 0}->{$element};
  
  my @connects = keys(%{$atom->{bond}});
  my $nconnects = scalar(@connects);

  return $nconnects ? 0 : $atom->{charge} if (!defined($delta));

  my $bond = {"-" => 1, ":" => 1.5, "=" => 2, "#" => 3};
  my $aromatic = defined($atom->{aromatic}) ? 1 : 0;
  my $partial = 1;
  my $formal = 0;
  my $sulfur = 0;

  foreach (@connects) {
    my $connect = $atoms->{$_};
    next if ($aromatic && $element eq "N" && $connect->{element} eq "H");
    $partial &= $atom->{bond}->{$_} eq ":" ? 1 : 0;
    $formal += $bond->{$atom->{bond}->{$_}};
    $sulfur = 1 if ($connect->{element} eq "S");
  }
  $formal -= $delta;

  if ($element eq "C") {
    $formal = 0 if ($formal == 0.5);
  } elsif ($element eq "N") {
    $formal = 0 if ($aromatic && $formal == 1);
    $formal = 0 if ($formal == 0.5);
  } elsif ($element eq "O") {
    $formal -= $aromatic ? 3 : 2;
    $formal = 0 if ($sulfur && $formal == 0.5);
  } elsif ($element eq "P") {
    $formal = 0 if ($formal == 0.5);
  } elsif ($element eq "S") {
    --$formal if ($aromatic);
    if ($nconnects<=2) { $formal -= 2 }
    elsif ($nconnects==3) { $formal -= 4 }
    else { $formal -= 6; }
    $formal = 0 if (abs($formal)==0.5);
  }

  return $partial && abs($formal)==0.5 ? 0 : $formal;
}


sub link_rec {
  my $atoms = shift(@_);
  my $current = shift(@_);
  my $atom = $atoms->{$current};
  my $parent = shift(@_);
  my $list = shift(@_);
  my @connect = @{$atom->{connect}};

  $atom->{visited} = 1;
  $list = [] if (!defined($list));
  push(@{$list}, $current);
  foreach (@connect) {					# connections
    if (defined($atoms->{$_}->{visited})) {
      if ($_ ne $parent && !defined($atom->{link}->{$_})) {
	$atoms->{$_}->{link}->{$current} = 0;
	$atom->{link}->{$_} = 0;
      }
      next;
    }							# recursive search
    $list = EMC::Atoms::link_rec($atoms, $_, $current, $list);
  }
  return $list;
}


sub link {
  my $atoms = shift(@_);
  my $first = shift(@_);

  my $list = EMC::Atoms::link_rec($atoms, $first);
  my $order;
  my $i = 0;

  foreach (@{$list}) {					# determine order
    $order->{$_} = $i++;
  }
  $i = 0;
  foreach (@{$list}) {					# assign link ids
    my $current = $_;
    my $atom = $atoms->{$current};

    next if (!defined($atom->{link}));			# skip on no link

    foreach (sort({$order->{$a} <=> $order->{$b}} keys(%{$atom->{link}}))) {
      if ($order->{$_}>$order->{$current}) {
	$atom->{link}->{$_} = $atoms->{$_}->{link}->{$current} = ++$i;
      } else {
	--$i;
      }
    }
  }
  EMC::Atoms::reset($atoms);
  return $atoms;
}


sub reset {
  my $atoms = shift(@_);

  foreach (keys(%{$atoms})) {				# delete all visited
    my $atom = $atoms->{$_};
    delete($atom->{visited}) if (defined($atom->{visited}));
  }
}


sub rule {
  my $atoms = shift(@_);
  my $attr = shift(@_);

  return if (!defined($attr));

  my $current = $attr->{id};
  my $atom = $atoms->{$current};
  my $list = $attr->{list};
  my $depth = $attr->{depth};
  my $level = $attr->{level};
  my $bond = $attr->{bond};

  my $ring = defined($atom->{ring}) ? "^$atom->{ring}" : "";
  my $rule = $atom->{aromatic} ? lc($atom->{element}) : $atom->{element};
  my $add = "";

  $atom->{visited} = 1;
  $attr->{max_depth} = $level if ($attr->{max_depth}<$level);
  
  if (defined($atom->{formal})) {			# formal charge
    my $formal = $atom->{formal};
    $rule .= $formal>0 ? "+" : "-";
    $rule .= abs($formal) if (abs($formal)!=1);
  }
  $rule = "[$rule]" if (length($rule)>1);
  if (scalar(@{$atom->{connect}})==2) {			# always add H to O
    foreach (@{$atom->{connect}}) {
      next if (defined($atoms->{$_}->{visited}));
      next if (scalar(@{$atoms->{$_}->{connect}})!=1);
      $attr->{bond} = $atom->{bond}->{$_};
      $attr->{bond} = "" if ($attr->{bond} eq "-");
      $attr->{id} = $_;
      $attr->{depth} = 0;
      $attr->{level} = $level+1;
      $add .= "(".EMC::Atoms::rule($atoms, $attr).")";
    }
  }

  push(@{$list}, $current) if ($list);
  if ($depth) {						# continue upon depth
    foreach (@{$atom->{connect}}) {
      next if (defined($atoms->{$_}->{visited}));
      $attr->{bond} = $atom->{bond}->{$_};
      $attr->{bond} = "" if ($attr->{bond} eq "-");	# recursive search
      $attr->{id} = $_;
      $attr->{depth} = $depth-1;
      $attr->{level} = $level+1;
      $rule .= "(".EMC::Atoms::rule($atoms, $attr).")";
    }
  }
  return $ring.$bond.$rule.$add;
}


sub smiles_rec {
  my $atoms = shift(@_);
  my $atom = $atoms->{shift(@_)};
  my $united = shift(@_);
  my @connect = @{$atom->{connect}};
  my $smiles = $atom->{aromatic} ? lc($atom->{element}) : $atom->{element};
  my $bond;
  my $last;

  $atom->{visited} = 1;
  if (defined($atom->{formal})) {			# formal charge
    my $formal = $atom->{formal};
    $smiles .= $formal>0 ? "+" : "-";
    $smiles .= abs($formal) if (abs($formal)!=1);
    $smiles = "[$smiles]";
  }
  if (defined($atom->{link})) {				# ring linkage
    my $link = $atom->{link};
    $smiles .= join("", 
      map({length($link->{$_})>1 ? "%$link->{$_}" : $link->{$_}} 
	sort({$link->{$a} <=> $link->{$b}} keys(%{$link}))));
  }
  foreach (@connect) {					# connections
    next if (defined($atoms->{$_}->{visited}));
    $bond = $atom->{bond}->{$_};
    $bond = "" if ($bond eq "-" || ($bond eq ":" && $atom->{aromatic}));
    my $result = 
      EMC::Atoms::smiles_rec($atoms, $_, $united);	# recursive search
    next if ($result eq "H" && !$united);		# exclude hydrogen
    if (!defined($last)) {
      $last = $bond.$result;
    } else {
      $smiles .= "(".$bond.$result.")";
    }
  }
  return $smiles.$last;
}


sub smiles {
  my $atoms = shift(@_);
  my $first = shift(@_);
  my $attr = shift(@_);
  
  my $smiles = EMC::Atoms::smiles_rec(
    EMC::Atoms::link($atoms, $first), $first, $attr->{united});

  EMC::Atoms::debug($atoms) if ($attr->{show});
  EMC::Atoms::reset($atoms);
  return $smiles;
}


# list 

sub list_reset {
  my $atoms = shift(@_);
  my $list = shift(@_);

  if (ref($list) eq "ARRAY") {
    foreach (@{$list}) {
      my $atom = $atoms->{$_};
      delete($atom->{visited}) if (defined($atom->{visited}));
    }
  }
}


# debug

sub debug {
  my $atoms = shift(@_);
  my $order = ref(@_[0]) eq "ARRAY" ? shift(@_) : [sort(keys(%{$atoms}))];

  foreach (@{$order}) {
    my $id = $_;
    my $atom = $atoms->{$id};
    my $bond = $atom->{bond};

    EMC::Message::tprint(
      $id, $atom->{type}, $atom->{charge}, 
      map({$bond->{$_}.$_} sort(keys(%{$bond}))));
  }
}

