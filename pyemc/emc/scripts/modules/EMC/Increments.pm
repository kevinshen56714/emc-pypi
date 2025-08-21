#!/usr/bin/env perl
#
#  module:	EMC::Increments.pm
#  author:	Pieter J. in 't Veld
#  date:	December 2, 2024.
#  purpose:	Increments structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  members
#    increment
#      entry	TYPE	description
#
#    increments	HASH	above structure
#
#  notes:
#    20241202	Inception of v1.0
#

package EMC::Increments;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

#use vars qw($Pi);

use EMC::Message;
use EMC::Math;
use EMC::Matrix;

# functions

# single residue

sub register {
  my $register = shift(@_);
  my $list = shift(@_);
  my $n = scalar(@{$list});
  my $key = join("\t", @{$list}[0..($n-2)]);

  if (defined($register->{$key})) {
    return undef if ($register->{$key}==$list->[-1]);
    my $atom = shift(@_);
    my $residue = shift(@_);
    EMC::Message::info("list = {".join(", ",@{$list})."}\n");
    EMC::Message::info("register = ".$register->{$key}."\n\n");
    EMC::Atoms::debug($residue->{atoms}, $residue->{ids});
    print("\n");
    EMC::Message::error(
      "charge inconsistence for $residue->{name}:$atom->{name} ".
      "($register->{$key}!=$list->[-1])\n");
  }
  $register = {} if (!defined($register));
  $register->{$key} = $list->[-1];
  return $register;
}


sub residue {
  my $increments = shift(@_);
  my $residue = shift(@_);
  my $attr = shift(@_);

  my $atoms = EMC::Common::element($residue, "atoms");
  my $debug = EMC::Common::element($attr, "debug");
  my $show = EMC::Common::element($attr, "show");

  return if (ref($atoms) ne "HASH");

  my $ids = $residue->{ids};

  if (scalar(@{$ids})==2) {
    my @type = map({$atoms->{$_}->{type}} @{$ids});
    if (@type[0] eq @type[1]) {
      ++$increments->{@type[0]}->{@type[1]}->{$atoms->{$ids->[0]}->{charge}};
      return $increments;
    }
  }

  my $index = {};						# column ids
  my $header = [];
  my $charge = 0;
  my $n = 0;

  foreach (@{$ids}) {
    my $id = $_;
    my $atom = $atoms->{$_};
    my $t1 = $atom->{type};

    $charge += $atom->{charge};
    foreach (@{$atom->{connect}}) {
      my $t2 = $atoms->{$_}->{type};

      $index->{$t1}->{$t2} = $index->{$t2}->{$t1} = 0;
    }
  }
  foreach (sort(keys(%{$index}))) {
    my $ptr = $index->{$_};
    my $t1 = $_;

    foreach (sort(keys(%{$ptr}))) {
      push(@{$header}, [$t1, $_]);
      $ptr->{$_} = $n++;
    }
  }

  my $unlink = EMC::Common::hash($residue, "unlink");
  my $allowed => {C => 1, N => 1, P => 1};

  foreach (@{$ids}) {						# uncoupling
    my $atom = $atoms->{$_};
    my $flag = 0;

    next if (!EMC::Common::element($atom, "formal"));
    foreach (@{$atom->{connect}}) {
      my $connect = $atoms->{$_};
      next if (!EMC::Common::element($connect, "formal"));
      $unlink->{$atom->{type}}->{$connect->{type}} = 1;
      $unlink->{$connect->{type}}->{$atom->{type}} = 1;
      $flag = 1;
    }
    next if ($flag);
    foreach (@{$atom->{connect}}) {
      my $connect = $atoms->{$_};
      next if (!defined($allowed->{$connect->{element}}));
      $unlink->{$atom->{type}}->{$connect->{type}} = 1;
      $unlink->{$connect->{type}}->{$atom->{type}} = 1;
    }
  }

  my $total = [(0) x $n, $charge];				# matrix
  my $register = {};
  my $linked = {};
  my $group = {};
  my $m = [];

  foreach (@{$ids}) {						# all connects
    my $id = $_;
    my $atom = $atoms->{$_};
    my $t1 = $atom->{type};
    my $row = [(0) x $n, $atom->{charge}];

    foreach (@{$atom->{connect}}) {
      my $t2 = $atoms->{$_}->{type};

      if (!EMC::Common::element($unlink, $t1, $t2)) {		# link
	if (!EMC::Common::element($linked, $t1, $t2)) {
	  my $row = [(0) x $n, 0];
	  $row->[$index->{$t1}->{$t2}] = $row->[$index->{$t2}->{$t1}] = 1;
	  $linked->{$t1}->{$t2} = $linked->{$t2}->{$t1} = 1;
	  push(@{$m}, $row) if (register($register, $row, $atom, $residue));
	}
      }
      ++$total->[$index->{$t1}->{$t2}];				# contrib
      ++$row->[$index->{$t1}->{$t2}];
    }
    push(@{$m}, $row) if (register($register, $row, $atom, $residue));

    if (defined($atom->{gconnect})) {
      foreach (@{$atom->{gconnect}}) {				# groups
	my $t2 = $atoms->{$_}->{type};

	foreach ([$t1, $t2], [$t2, $t1]) {
	  next if (EMC::Common::element($group, @{$_}));
	  my $row = [(0) x $n, 0];				# zero contrib
	  $group->{$_->[0]}->{$_->[1]} = 1;			# over bounds
	  $row->[$index->{$_->[0]}->{$_->[1]}] = 1;
	  push(@{$m}, $row) if (register($register, $row, $atom, $residue));
	}
      }
    }
  }
  EMC::Matrix::mprint($m, $header) if ($show);

  my $sol = EMC::Matrix::msolve($m, {m => \$m, show => $debug});

  if (!defined($sol)) {
    EMC::Message::tprint("\nresidue", $residue->{name}."\n");
    EMC::Atoms::debug($residue->{atoms}, $residue->{ids});
    EMC::Message::tprint("\ncharge", $charge."\n");
    EMC::Matrix::mprint($m, $header);
    EMC::Message::error(
      "increments not found for residue '$residue->{name}'\n");
  }

  EMC::Matrix::mprint([$sol], $header) if ($show);

  for (my $i=0; $i<scalar(@{$sol}); ++$i) {
    ++$increments->{$header->[$i]->[0]}->{$header->[$i]->[1]}->{$sol->[$i]};
  }
}


# convert to field

sub to_field {
  my $increments = shift(@_);
  my $field = shift(@_);

  my $increment = EMC::Common::hash($field, "increment", "data");

  foreach (sort(keys(%{$increments}))) {
    my $i1 = $_;

    foreach (sort(keys(%{$increments->{$i1}}))) {
      my $i2 = $_;
      my @id = EMC::Fields::arrange($i1, $i2);
      my @d;

      foreach ([@id], [reverse(@id)]) {
	my @v = keys(%{$increments->{$_->[0]}->{$_->[1]}});
	
	if (scalar(@v)>1) {
	  EMC::Message::info("increments = {".join(", ", @v)."}\n");
	  EMC::Message::error("multiple increments for '{$_->[0], $_->[1]}'\n");
	}
	push(@d, @v[0]);
      }
      @d[1] = -@d[0] if (@id[0] eq @id[1]);
      $increment->{@id[0]}->{@id[1]} = join("\t", @d);
    }
  }
}


# create for all residues

sub create {
  my $residues = shift(@_);
  my $attr = shift(@_);

  EMC::Message::info("determining increments\n");
  
  my $increments = EMC::Common::hash($residues, "increments");
  my $data = EMC::Common::hash($residues, "data");

  foreach (sort(keys(%{$data}))) {
    EMC::Message::info("residue = $_\n\n") if ($attr->{show});
    EMC::Increments::residue($increments, $data->{$_}, $attr);
  }
  return $increments;
}

