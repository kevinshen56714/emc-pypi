#!/usr/bin/env perl
#
#  program:	EMC.pm
#  author:	Pieter J. in 't Veld
#  date:	November 28, 2021, August 31, 2022.
#  purpose:	EMC structure routines; part of EMC distribution
#
#  members
#    options		HASH	available options, defined through modules
#    analyze		HASH	analysis settings and definitions
#    chemistry		HASH	chemistry mode options and definitions
#    emc		HASH	EMC input script related definitions
#    environment	HASH	environment mode options and definitions
#    global		HASH	global options and definitions
#    md			HASH	MD options and definitions
#    message		HASH	message options and definitions
#    modules		ARRAY	sorted list of names of available modules
#    namd		HASH	NAMD options and definitions
#    pdb		HASH	PDB port definitions
#    types		HASH	field definitions
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20211128	Inception of v1.0
#    20220831	Change of construct subroutines
#

package EMC;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

# packages

use EMC::Analyze;
use EMC::Chemistry;
use EMC::Clusters;
use EMC::Common;
use EMC::Dist;
use EMC::Element;
use EMC::EMC;
use EMC::Environment;
use EMC::Fields;
use EMC::Global;
use EMC::Groups;
use EMC::Hash;
use EMC::IO;
use EMC::Job;
use EMC::Item;
use EMC::List;
use EMC::Math;
use EMC::Matrix;
use EMC::MD;
use EMC::Message;
use EMC::Options;
use EMC::PDB;
use EMC::Polymers;
use EMC::Profiles;
use EMC::Script;
use EMC::Struct;
use EMC::Types;

# constants

use vars qw(&Identity);

$EMC::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "August 31, 2022",
  version	=> "1.0",
  emc		=> "9.4.4"
};


# assignments

sub construct {
  my $parent = shift(@_);
  my $root = EMC::Common::element($parent);
  my $modules = {
    analyze => [\&EMC::Analyze::construct],
    chemistry => [\&EMC::Chemistry::construct],
    emc => [\&EMC::EMC::construct],
    environment => [\&EMC::Environment::construct],
    fields => [\&EMC::Fields::construct, {emc => 1}],
    global => [\&EMC::Global::construct],
    job => [\&EMC::Job::construct, {indicator => 0}],
    md => [\&EMC::MD::construct, {indicator => 1, depricated => 1}],
    message => [\&EMC::Message::construct, {indicator => 0}],
    script => [\&EMC::Script::construct],
    types => [\&EMC::Types::construct]
  };
  my $ptr = $modules->{global};
  my $backwards;
  my $attr;

  $root->{global}->{root} = $parent;
  $root->{global}->{parent} = $parent;
  $root->{global} = scalar(@{$ptr})>1 ? 
      $ptr->[0]->(\$root->{global}, $ptr->[1]) : $ptr->[0]->(\$root->{global});
  $backwards = EMC::Common::element($root, "global", "flag", "backwards") ? 1:0;
  $root->{modules} = [sort(keys(%{$modules}))];
  $root->{files} = [];
  foreach (@{$root->{modules}}) {
    next if ($_ eq "global");
    $ptr = $modules->{$_};
    $attr = {backwards => $backwards};
    $attr = EMC::Common::attributes($attr, $ptr->[1]) if (defined($ptr->[1]));
    $root->{$_} = EMC::Common::hash($root->{$_});
    $root->{$_}->{root} = $parent;
    $root->{$_}->{parent} = $parent;
    $root->{$_} =  $ptr->[0]->(\$root->{$_}, $attr);
  }

  EMC::Options::transcribe($root);

  return $root;
}


# initialization

sub initialize {
  my $root = EMC::Common::hash(shift(@_));
  my $struct = {root => $root};
  my $global = $root->{global};
  my $flag = $global->{flag};
  my $result = undef;
  my $project = 0;

  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @arg = split("=", substr($_,1));
      $struct->{option} = shift(@arg);
      $struct->{args} = [@arg];
      $result = EMC::Options::set_options($root->{options}, $struct);
      if (defined($result) ? 0 : $flag->{ignore} ? 0 : 1) {
	EMC::Options::set_help($struct);
      }
    } else {
      my @found = EMC::IO::find($flag->{source}, $_);
      push(@{$root->{files}}, @found) if (scalar(@found));
      $project = 1;
    }
  }
  # EMC::init_output($root);
  EMC::Options::set_context($root);
  EMC::Options::set_help($struct) if (!$project);
  if (!scalar(@{$root->{files}})) {
    EMC::Options::header($root->{options});
    EMC::Message::error("no files found.\n");
  }
  EMC::set_quiet($root) if ($flag->{output} eq "-");
  @{$root->{files}} = sort(@{$root->{files}});
  return $root;
}


sub reset {					# <= reset_global_variables
  my $root = shift(@_);

  EMC::Clusters::set_defaults($root->{clusters});
  EMC::Groups::set_defaults($root->{groups});
  $root->{emc}->{import} = {};
  $root->{polymers}->{polymer} = {};
  return $root;
}


# functions

sub init_output {
  my $root = shift(@_);
  my $global = EMC::Common::hash($root, "global");
  my $flag = EMC::Common::hash($global, "flag");

  if (substr($flag->{output}, -3) eq ".gz") {
    $flag->{output} = substr($flag->{output}, 0, length($flag->{output})-3);
    $flag->{compress} = 1;
  }
  if ($flag->{output} ne "-") {
    $flag->{output} .= ".prm" if (substr($flag->{output}, -4) ne ".prm");
    $flag->{output} .= ".gz" if ($flag->{compress});
  }
}


sub reset_flags {
  my $root = shift(@_);
  my $md = EMC::Common::element($root, "md");

  foreach (["emc", "flag"], ["pdb", "flag"], ["fields", "field"]) {
    my $flag = EMC::Common::element($root, @{$_});
    $flag->{write} = 0 if (defined($flag));
  }
  EMC::MD::set_flags($md, "write", 0);
}


sub set_quiet {
  my $struct = shift(@_);
  my $args = EMC::Common::element($struct, "args");
  my $root = EMC::Common::element($struct, "root");

  EMC::Message::set_options({
    option => "message_quiet", root => $root, args => $args});
}

