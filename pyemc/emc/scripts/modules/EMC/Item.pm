#!/usr/bin/env perl
#
#  module:	EMC::Item.pm
#  author:	Pieter J. in 't Veld
#  date:	December 19, 2021.
#  purpose:	Item structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  members:
#    index	ARRAY	handling order of hash elements (structs)
#    [any_name]	STRUCT	
#      options	ARRAY	options coming directly after ITEM indicator
#      data	ARRAY	respective array of entries containing arrays of
#			elements
#      [...]	STRUCT	subsequent structs
#
#  notes:
#    20211219	Inception of v1.0
#

package EMC::Item;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Common;


# functions

# read

sub read {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $level = 0;
  my $line = 0;
  my $next = 0;
  my $header;
  my $item;
  my $data;
  my $id;

  $item->{index} = [] if (defined($stream));
  foreach (<$stream>) {
    ++$line;
    chomp();
    $_ = EMC::Common::trim($_);
    my @arg = split("\t");
    if (!scalar(@arg)) {
      next if ($next);
      if (defined($header)) {
	$item->{header}->{header} = $header;
	push(@{$item->{index}}, "header");
	undef($header);
      }
      $next = 1;
      next;
    }
    @arg = split(" ") if (scalar(@arg)==1);
    if (defined($id)) {
      if (@arg[0] eq "ITEM") {
	if (@arg[1] eq "END") {
	  --$level;
	  if (!$level) {
	    undef($data);
	    undef($id);
	    next;
	  }
	}
	++$level;
      }
      push(@{$data}, [@arg]);
    } else {
      if (substr(@arg[0],0,1) eq "#") {
	$header = [] if (!defined($header));
	push(@{$header}, $_);
	next;
      } else {
	if (shift(@arg) ne "ITEM") {
	  EMC::Message::error_line($line, "unexpected keyword\n");
	}
	$id = lc(shift(@arg));
	if ($id eq "index") {
	  EMC::Message::error_line($line, "unallowed item keyword\n");
	}
	$item->{$id}->{header} = $header;
	$item->{$id}->{options} = [@arg];
	$item->{$id}->{data} = $data = [];
	push(@{$item->{index}}, $id);
	undef($header);
	++$level;
      }
    }
  }
  return $item;
}


# write

sub write {
  my $stream = shift(@_);
  my $item = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $single = {
    angle => 1, angle_auto => 1, bond => 1, bond_auto => 1, cmap => 1,
    equivalence => 1, equivalence_auto => 1, improper => 1, improper_auto => 1,
    increment => 1, mass => 1, nonbond => 1, nonbond_auto => 1, references=> 1,
    torsion => 1, torsion_auto => 1};
  my $indent = defined($attr->{tab}) ? int($attr->{tab}) : 2;
  my $fsingle = 0;

  return if (!defined($item));
  $indent = 1 if ($indent<1);
  $indent *= 8;
  foreach(defined($item->{index}) ? 
		@{$item->{index}} : sort(keys(%{$item}))) {
    my $id = $_;
    my $comment;

    next if (!defined($item->{$id}));
    if (defined($item->{$id}->{header})) {
      print($stream join("\n", @{$item->{$id}->{header}}));
    } else {
      print($stream join(" ", "#", ucfirst($id)));
    }
    print($stream "\n\n");
    next if (!defined($item->{$id}->{data}));
    print($stream join("\t", "ITEM", uc($id)));
    if (defined($item->{$id}->{options})) {
      print($stream "\t", join("\t", @{$item->{$id}->{options}}));
    }
    print($stream "\n\n");
    $fsingle = defined($single->{$id}) ? 1 : 0;
    foreach (@{$item->{$id}->{data}}) {
      my $data = $_;

      print($stream "\n") if ($comment);
      $comment = 0 if ($comment);
      my @data = @{$data}; 
      if (substr(@data[0],0,1) eq "#") {
	print($stream shift(@data), " ");
	$comment = 1;
      }
      if (!$fsingle && scalar(@data)>1) {
	my $n = $indent-length(@data[0]);
	print($stream shift(@data));
	for ($n+=8 if ($n<0); $n>0; $n-=8) { print($stream "\t"); }
      }
      print($stream join("\t", @data), "\n");
    }
    print($stream "\n", join("\t", "ITEM", "END", "# ".uc($id)), "\n\n");
  }
}

