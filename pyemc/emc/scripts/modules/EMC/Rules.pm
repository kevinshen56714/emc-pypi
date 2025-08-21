#!/usr/bin/env perl
#
#  module:	EMC::Rules.pm
#  author:	Pieter J. in 't Veld
#  date:	December 8, 2024.
#  purpose:	Rules structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  members
#    <rule>	HASH	types
#    	<type>	ARRAY	list of [resid, atomid] for type occurence
#    	...	multiple entries when rule occurs for multiple types
#
#  notes:
#    20241208	Inception of v1.0
#

package EMC::Rules;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

#use vars qw($Pi);

use EMC::Atoms;
use EMC::Message;

# functions

# rules

sub residues {
  my $rules = shift(@_);
  my $residues = shift(@_);
  my $attr = shift(@_);

  my $data = EMC::Common::hash($residues, "data");
  my $override = EMC::Common::hash($residues, "override");
  my $max_depth = defined($attr->{depth}) ? $attr->{depth} : 4;
  my $selection = [];
  my $ffdepth = 0;
  my $depth = 1;

  EMC::Message::info("determining rules\n");

  foreach (sort(keys(%{$data}))) {			# create selection
    my $resid = $_;
    foreach(@{$data->{$resid}->{ids}}) {
      push(@{$selection}, [$resid, $_]);
    }
  }

  while (scalar(@{$selection})) {			# repeat upon selection
    my $check = [];
    my $types = {};

    EMC::Message::info("rules pass $depth\n");
    foreach (@{$selection}) {				# create rules
      my $resid = $_->[0];
      my $id = $_->[1];
      
      next if ($resid eq "-" || $id eq "-");

      my $residue = $data->{$resid};
      my $atoms = $residue->{atoms};
      my $attr = {
	id => $id, depth => $depth, max_depth => 0, level => 0, list => [],
	resid => $resid
      };
      my $rule = EMC::Atoms::rule($residue->{atoms}, $attr);
      my $type = $atoms->{$id}->{type};
      my $entry = $rules->{$rule};

      $ffdepth = $attr->{max_depth} if ($ffdepth<$attr->{max_depth});
      EMC::Atoms::list_reset($residue->{atoms}, $attr->{list});
      push(@{$check}, $rule);
      if (!defined($entry = $entry->{$type})) {
	$rules->{$rule}->{$type} = $entry = [];
	push(@{EMC::Common::list($types, $rule)}, $type);
      }
      push(@{$entry}, [$resid, $id]);
    }
    @{$selection} = ();
    foreach (@{$check}) {				# check doubles
      my $id = $_;
      my $rule = $rules->{$id};

      if (scalar(keys(%{$rule}))>1) {
	my $types = [sort(keys(%{$rule}))];
	my $keep = undef;

	foreach (@{$types}) {
	  my $list = $rule->{$_};

	  if ($list->[0]->[0] eq "-" || $list->[0]->[1] eq "-") {
	    if (defined($keep)) {
	      EMC::Message::error("conflicting rule entries for type '$_'\n");
	    }
	    $keep->{$_} = $list;
	    next;
	  }
	  push(@{$selection}, @{$rule->{$_}});
	}
	if (defined($keep)) {
	  $rules->{$id} = $keep;
	} else {
	  delete($rules->{$id});
	}
      }
    }
    last if (++$depth>$max_depth);			# depth+1 for OH
  }
  $attr->{depth} = $ffdepth;
  return $rules;
}


# items

sub item_rules {
  my $items = shift(@_);
  my $attr = shift(@_);

  my $field = EMC::Common::element($attr, "field");
  my $index = EMC::Common::element($attr, "index");
  my $data = EMC::Common::element($items, $index, "data");
  my $lines = EMC::Common::element($items, $index, "lines");

  return if (!($field && $index && $data && $lines));

  my $rules = EMC::Common::hash($attr, "rules");
  my $override = EMC::Common::hash($attr, "override");
  my $mass = EMC::Common::hash($field, "mass", "data");
  my $index = ["type", "element", "residue", "atom", "charge", "rule"];
  my $nargs = scalar(@{$index});

  my $line = -1;
  my $list;

  foreach (@{$data}) {
    my $arg = undef;
    my $i = 0;

    ++$line;
    foreach (@{$_}) {
      last if (substr($_,0,1) eq "!");
      last if (substr($_,0,1) eq "#");
      $arg->{$index->[$i++]} = $_ if ($_ ne "");
    }
    next if (!defined($arg));
    if (scalar(keys(%{$arg})) != $nargs) {
      EMC::Message::error_line($lines->[$line],
	"incorrect number of rule arguments\n");
    }
    if (!defined($mass->{$arg->{type}})) {
      EMC::Message::error_line($lines->[$line],
	"undefined type '$arg->{type}'\n");
    }
    if ($arg->{residue} ne "-" && $arg->{atom} ne "-") {
      $override->{$arg->{residue}}->{$arg->{atom}} = [
	$arg->{rule}, $arg->{type}];
    } else {
      $list = EMC::Common::list($rules, $arg->{rule}, $arg->{type});
      push(@{$list}, [$arg->{residue}, $arg->{atom}]);
    }
  }
  return $rules;
}


# struct i/o

sub write {
  my $stream = shift(@_);
  my $rules = shift(@_);
  my $attr = shift(@_);

  my $field = EMC::Common::element($attr, "field");

  return if (!($field && $rules));

  my $mass = EMC::Common::hash($field, "mass", "data");
  my $define = EMC::Common::hash($field, "define", "data");
  my $override = EMC::Common::element($attr, "residues", "override");

  my $sep = $define->{RULE_NARGS}>6 ? "\t" : ":";
  my $result = {};

  foreach (keys(%{$rules})) {
    my $id = $_;
    my $rule = $rules->{$id};

    foreach (keys(%{$rule})) {
      my $list = $rule->{$_};
      my $index = $list->[0];

      foreach (@{$list}) {
	next if ($_->[0] eq "-" || $_->[1] eq "-");
	$index = $_;
	last;
      }
      $result->{$_}->{$id} = $index;
    }
  }

  print($stream "# Rules\n\n");
  print($stream "ITEM\tRULES\n\n");
  print($stream "# id\ttype\telement\tresidue\tatom\tcharge\trule\n\n");
  print($stream "0\t?\t?\t".join($sep, "UNK", "UNK")."\t0\t*\n");

  my $index = 1;

  foreach (sort(keys(%{$result}))) {
    my $id = $_;
    my $type = $result->{$id};

    foreach (sort(keys(%{$type}))) {
      my $arg = $type->{$_};
      my $list = EMC::Common::element($override, $arg->[0], $arg->[1]);
      my $rule = $list ? $list->[0] : $_;

      print($stream 
	join("\t",
	  $index++, $id, $mass->{$id}->[1], join($sep, @{$arg}), 0, $rule),
       	"\n");
    }
  }
  print($stream "\nITEM\tEND\t# RULES\n\n");
}

