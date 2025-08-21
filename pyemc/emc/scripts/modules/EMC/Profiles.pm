#!/usr/bin/env perl
#
#  module:	EMC::Profiles.pm
#  author:	Pieter J. in 't Veld
#  date:	October 1, 2022.
#  purpose:	Profiles structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  general members:
#    commands		HASH	structure commands
#
#    identity		HASH
#      author		STRING	module author
#      date		STRING	latest modification date
#      version		STRING	module version
#
#    set		HASH
#      commands		FUNC	commands initialization
#      defaults		FUNC	defaults initialization
#      options		FUNC	options interpretation
#      flag		HASH	control flags
#        indicator	BOOLEAN	include "profiles_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    check		HASH	check for profile use elsewhere
#    flag		HASH	profile settings
#    profile		HASH	profile definitions
#
#  notes:
#    20221001	Inception of v1.0
#

package EMC::Profiles;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Profiles'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::EMC;
use EMC::Math;


# defaults

$EMC::Profiles::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "October 1, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $profiles = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($profiles, $attr);
  set_defaults($profiles);
  set_commands($profiles);
  return $profiles;
}


# initialization

sub set_defaults {
  my $profiles = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $profiles = EMC::Common::attributes(
    $profiles,
    {
      check		=> {},
      flag		=> {
	density		=> 0,
	density3d	=> 0,
	pressure	=> 0
      },
      profile		=> {}
    }
  );
  $profiles->{identity} = EMC::Common::attributes(
    EMC::Common::hash($profiles, "identity"),
    $EMC::Profiles::Identity
  );
  return $profiles;
}


sub transfer {
  my $profiles = EMC::Common::hash(shift(@_));
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Profile,			\$profiles->{check}],
    [\$::EMC::ProfileFlag,		\$profiles->{flag}],
    [\$::EMC::Profiles,			\$profiles->{profile}],
  );
}


sub set_commands {
  my $profiles = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($profiles, "set");
  my $context = EMC::Common::element($profiles, "context");
  my $flag = EMC::Common::element($profiles, "flag");

  EMC::Options::set_command(
    $profiles->{commands} = EMC::Common::attributes(
      EMC::Common::hash($profiles, "commands"), 
      {
	profile		=> {
	  comment	=> "set LAMMPS profile output",
	  default	=> EMC::Hash::text($flag, "boolean"),
	  gui		=> ["boolean", "chemistry", "analysis", "standard"]},
      }
    ),
    {
      set		=> \&EMC::Profiles::set_options
    }
  );

  EMC::Options::set_command(
    $profiles->{items} = EMC::Common::attributes(
      EMC::Common::hash($profiles, "items"),
      {
	profiles	=> {
	  set		=> \&set_item_profiles
	}
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0
    }
  );

  return $profiles;
}


sub set_context {
  my $profiles = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($profiles, "flag");
  my $context = EMC::Common::element($profiles, "context");
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $profiles = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($profiles, "flag");

  if ($option eq "profile") {
    return EMC::Hash::set($line, $flag, "boolean", "density", [], @{$args});
  }

  return undef;
}


sub set_functions {
  my $profiles = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($profiles, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Profiles::set_commands;
  $set->{context} = \&EMC::Profiles::set_context;
  $set->{defaults} = \&EMC::Profiles::set_defaults;
  $set->{options} = \&EMC::Profiles::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $profiles;
}


# set item

sub set_item_profiles {
  my $struct = shift(@_);
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return if (EMC::Common::element($options, "comment"));
  
  my $root = EMC::Common::element($struct, "root");
  my $global = EMC::Common::element($root, "global");
  my $md = EMC::Common::element($root, "md");
  my $option = EMC::Common::element($struct, "option");
  my $profiles = EMC::Common::element($struct, "module");
  my $profile = EMC::Common::element($profiles, "profile");
  my $check = EMC::Common::element($struct, "module", "check");
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $i = 0;

  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$i++];

    my %allow_style = ("type" => 1, "cluster" => 1);
    my %allow_type = EMC::List::allow($profiles->{flag});
    my $name = shift(@arg);
    my @a = split(":", shift(@arg));
    my $style = @a[0];
    my $type = @a[1] eq "" ? "density" : @a[1];
    my $binsize = @a[2] eq "" ? $global->{binsize} : EMC::Math::eval(@a[2]);

    $binsize = $global->{binsize} if ($binsize<=0.0);
    $binsize = 1.0 if ($binsize>=1.0);
    if ($name eq $global->{project}->{name}) {
      EMC::Message::error_line(
	$line, "cannot use project name '$global->{project}->{name}'\n");
    }
    if (!defined($allow_style{$style})) {
      EMC::Message::error_line(
	$line, "illegal profile style '$style'\n");
    }
    if (!defined($allow_type{$type})) {
      EMC::Message::error_line($line,
       	"illegal profile type '$type'\n");
    }
    if ($type eq "pressure" && !$md->{lammps}->{flag}->{chunk}) {
      EMC::Message::error_line(
	$line, "pressure profile needs LAMMPS chunks\n");
    }
    if (defined($check->{$name})) {
      EMC::Message::error_line($line,
       	"profile name '$name' already exists\n");
    }
     
    $check->{$name} = 1;
    push(@{$profile->{$style}->{$name}}, $type, $binsize, @arg);
    if ($style=="type") {
      foreach (@arg) {
	EMC::EMC::set_convert_key($root->{emc}, $style, $_);
      }
    }
  }
  return $root;
}


# functions

