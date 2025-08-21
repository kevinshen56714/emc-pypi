#!/usr/bin/env perl
#
#  module:	EMC::Residues.pm
#  author:	Pieter J. in 't Veld
#  date:	November 30, 2024.
#  purpose:	Residues structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  members
#    <group>
#      atoms	LIST	list of pointers to member atoms (see EMC::Atoms)
#      connect	LIST	list of connection pairs (two atom ptrs)
#      id	INTEGER	index to member of residue->{groups} list
#
#    residue
#    	atoms	HASH	atom representations (see 'atoms' in EMC::Atoms)
#    	charge	REAL	total residue charge
#    	groups	LIST	list of above <group> entries
#    	ids	ARRAY	list of atom ids in import order
#    	n	INTEGER	total number of atoms
#    	name	STRING	residue name
#    	smiles	STRING	chemical SMILES representation of atoms
#
#    <rule>	HASH	types
#    	<type>	ARRAY	list of [resid, atomid] for type occurence
#    	...	multiple entries when rule occurs for multiple types
#
#    residues
#    	data	HASH	above residue structure
#    	rules	HASH	above <rule> entries
#
#  notes:
#    20241130	Inception of v1.0
#

package EMC::Residues;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

#use vars qw($Pi);

use EMC::Atoms;
use EMC::Increments;
use EMC::Message;
use EMC::Rules;

# functions

# residues

sub assign {
  my $residues = shift(@_);
  my $data = $residues->{data};
  my $attr = shift(@_);

  foreach (sort(keys(%{$data}))) {
    my $residue = $data->{$_};
    my $atoms = $residue->{atoms};

    $residue->{name} = $_;
    EMC::Atoms::assign($atoms, $attr);
    EMC::Message::tprint("residue", $_) if ($attr->{show});
    $residue->{smiles} =
      EMC::Atoms::smiles($atoms, $residue->{ids}->[0], $attr);
    EMC::Message::tprint("\n".$_, $residue->{smiles}."\n") if ($attr->{show});
  }
  EMC::Increments::create($residues, $attr);
  EMC::Residues::rules($residues, $attr);
  return $residues;
}


sub rules {
  return EMC::Rules::residues(EMC::Common::hash(@_[0], "rules"), @_);
}


sub reset {
  my $residues = shift(@_);
  my $data = $residues->{data};
  my $attr = shift(@_);

  foreach (sort(keys(%{$data}))) {
    my $residue = $data->{$_};
    my $atoms = $residue->{atoms};

    EMC::Atoms::reset($atoms);
  }
}


# items

sub item_stream {
  my $items = shift(@_);
  my $attr = shift(@_);

  my $field = EMC::Common::element($attr, "field");
  my $index = EMC::Common::element($attr, "index");
  my $data = EMC::Common::element($items, $index, "data");
  my $lines = EMC::Common::element($items, $index, "lines");

  return if (!($field && $index && $data && $lines));

  my $mass = EMC::Common::hash($field, "mass");
  my $residues = EMC::Common::hash($attr, "residues");
  my $ielement = EMC::List::hash(EMC::Common::list($mass, "index"))->{element};
  my $residues_data = EMC::Common::hash($residues, "data");
  my $mass = EMC::Common::hash($mass, "data");

  my $line = -1;
  my $atom_id = 0;
  my $group_id = -1;
  my $group = undef;
  my $residue = undef;
  my $atoms = undef;
  my $types = undef;
  my $comment = 0;
  my $nentries = {
    atom => 3, conect => 2, formal => 2, group => 0, resi => 2, unlink => 2};

  foreach (@{$data}) {
    my $arg = [];
    my $key;

    ++$line;
    foreach (@{$_}) {
      last if (substr($_,0,1) eq "!");
      last if (substr($_,0,1) eq "#" && $key ne "conect");
      push(@{$arg}, $_) if ($_ ne "");
      $key = lc($arg->[0]) if (scalar(@{$arg})==1);
    }
    next if (!scalar(@{$arg}));
    my $Key = shift(@{$arg});
    my $key = lc($Key);
    if ($key eq "/*" || $key eq "(*") {
      ++$comment;
    } elsif ($key eq "*/" || $key eq "*)") {
      --$comment;
      next;
    }
    next if ($comment);
    if (defined($nentries->{$key})) {
      if (scalar(@{$arg})<$nentries->{$key}) {
	EMC::Message::error_line($lines->[$line],
	  "too few entries for keyword '$Key'\n");
      }
    }
    if ($key ne "resi" && !defined($residue)) {
      EMC::Message::error_line($lines->[$line],
       	"residue must be define before keyword '$Key'\n");
    }
    if ($key eq "atom") {					# ATOM
      my $id = shift(@{$arg});
      my $atom = EMC::Common::hash($atoms, $id);

      $atom->{type} = shift(@{$arg});
      if (!defined($mass->{$atom->{type}})) {
	EMC::Message::error_line($lines->[$line],
	  "undefined type '$atom->{type}'\n");
      }
      $atom->{charge} = shift(@{$arg});
      $atom->{element} = $mass->{$atom->{type}}->[$ielement-1] if ($ielement);
      $residue->{charge} += $atom->{charge};
      $residue->{n} = scalar(keys(%{$residue->{atoms}}));
      if (!defined($atom->{id})) {
	$atom->{id} = ++$atom_id;
	$residue->{ids} = [] if (!defined($residue->{ids}));
	push(@{$residue->{ids}}, $id);
      }
      if (defined($group)) {
	$atom->{group} = $group_id;
	push(@{$group}, $id);
      }
      $types->{$atom->{type}} = 1;
    } elsif ($key eq "bond" || $key eq "conect") {		# BOND, CONECT
      my ($source, $bond, $ring);
      while (scalar(@{$arg})) {
	if ($key eq "bond" || !defined($source)) {
	  ($source, $bond, $ring) = EMC::Atoms::decoration(shift(@{$arg}));
	  if (!defined($atoms->{$source})) {
	    EMC::Message::error_line($lines->[$line],
	      "undefined atom '$source'\n");
	  }
	  if (defined($bond)) {
	    EMC::Message::error_line($lines->[$line],
	      "source atom cannot contain bond information\n");
	  }
	  if (!scalar(@{$arg})) {
	    EMC::Message::error_line($lines->[$line],
	      "missing target atom after '$source'\n");
	  }
	  $atoms->{$source}->{ring} = $ring if (defined($ring));
	}
	my ($target, $bond, $ring) = EMC::Atoms::decoration(shift(@{$arg}));
	if (!defined($atoms->{$target})) {
	  EMC::Message::error_line($lines->[$line],
	    "undefined atom '$target'\n");
	}
	$bond = "-" if (!defined($bond));
	$atoms->{$target}->{ring} = $ring if (defined($ring));
	$atoms->{$source}->{bond}->{$target} = $bond;
	$atoms->{$target}->{bond}->{$source} = $bond;
      }
    } elsif ($key eq "formal") {				# FORMAL
      my $id = shift(@{$arg});
      if (!defined($atoms->{$id})) {
	EMC::Message::error_line($lines->[$line], "undefined atom '$id'\n");
      }
      $atoms->{$id}->{formal} = eval(shift(@{$arg}));
    } elsif ($key eq "group") {					# GROUP
      my $groups = EMC::Common::list($residue, "groups");
      push(@{$groups}, $group = []);
      ++$group_id;
    } elsif ($key eq "resi") {					# RESI
      if (defined($residues_data->{$arg->[0]})) {
	EMC::Message::error_line($lines->[$line],
	  "residue '$arg->[0]' redefinition\n");
      }
      $atom_id = 0;
      $residue = $residues_data->{$arg->[0]} = {};		# reset
      $atoms = $residue->{atoms} = {};
      $types = {};
      $group_id = -1;
      $group = undef;
    } elsif ($key eq "unlink") {				# UNLINK
      while (scalar(@{$arg})) {
	if (scalar(@{$arg})==1) {
	  EMC::Message::error_line($lines->[$line],
	    "missing type'\n");
	}
	my $type = [shift(@{$arg}), shift(@{$arg})];
	foreach (@{$type}) {
	  if (!defined($types->{$_})) {
	    EMC::Message::error_line($lines->[$line],
	      "undefined type '$_'\n");
	  }
	}
	$residue->{unlink}->{$type->[0]}->{$type->[1]} = 1;
	$residue->{unlink}->{$type->[1]}->{$type->[0]} = 1;
      }
    } else {
      EMC::Message::error_line($lines->[$line],
       	"unknown keyword '$Key'\n");
    }
  }
  
  my $define = EMC::Common::element($field, "define", "data");
  my $flags = EMC::Common::element($attr, "flags");
  my $attr = {
    show => $flags->{show}, united => $flags->{united},
    depth => $define->{FFDEPTH}};

  EMC::Residues::assign($residues, $attr);
  EMC::Increments::to_field($residues->{increments}, $field);
  $define->{FFDEPTH} = $attr->{depth};
  return $residues;
}


# struct i/o

sub write_precedence {
  my $stream = shift(@_);
  my $residues = shift(@_);

  my $rules = EMC::Common::element($residues, "rules");
  my $element = {};
  my $types = {};
  my $depth = {};

  foreach (sort(keys(%{$rules}))) {
    my $rule = $_;
    my $list = $rules->{$_};
    my $l = EMC::List::smiles($rule);
    my $d = EMC::List::depth($l);
    my $e;

    foreach (@{$l}) {
      last if (ref($_) eq "ARRAY");
      $e = lc($_);
    }


    foreach (keys(%{$list})) {
      $depth->{$_} = $d if ((!defined($depth->{$_})) || ($d<$depth->{$_}));
      $element->{$_} = $e if (!defined($element->{$_}));
      ++$types->{$_};
    }
  }

  print($stream "# Precedence\n\n");
  print($stream "ITEM\tPRECEDENCE\n\n");
  print($stream "(?\n");
  foreach (sort({
	$element->{$a} eq $element->{$b} ?
	$depth->{$a}==$depth->{$b} ? 
	$b cmp $a :
	$depth->{$b} <=> $depth->{$a} :
	$element->{$a} cmp $element->{$b}
      } keys(%{$types}))) {
    print($stream "  ($_)\n");
  }
  print($stream ")\n\nITEM\tEND\t# PRECEDENCE\n\n");
}


sub write_rules {
  EMC::Rules::write(@_[0], EMC::Common::element(@_[1], "rules"), @_[2]);
}


sub write_templates {
  my $stream = shift(@_);
  my $residues = shift(@_);
  my $attr = shift(@_);

  my $residues = EMC::Common::element($residues, "data");

  return if (!$residues);

  print($stream "# Templates\n\n");
  print($stream "ITEM\tTEMPLATES\n\n");
  print($stream "# name\tsmiles\n\n");

  foreach (sort(keys(%{$residues}))) {
    print($stream $_, "\t", $residues->{$_}->{smiles}, "\n");
  }
  print($stream "\nITEM\tEND\t# TEMPLATES\n\n");
}

