#!/usr/bin/env perl
#
#  module:	EMC::Options.pm
#  author:	Pieter J. in 't Veld
#  date:	January 2, 2022.
#  purpose:	Options structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  members:
#    columns	INTEGER	number of columns in terminal
#    offset	INTEGER	offset between command and description
#    commands	HASH	hash of commands, for members see element below
#
#  commands: 
#    comment	STRING	help explanation
#    default	ANY	default value depending on settings => turn into func?
#    [gui]	ARRAY	information to be ported to VMD EMC GUI
#      type	STRING	input type
#      tab	STRING	main menu tab
#      subtab	STRING	sub menu tab
#      section	STRING	either 'standard' or 'advanced' as subtab section
#      optional	STRING	optional defaults
#
#  notes:
#    20220102	Inception of v1.0
#    		Options are set in subsequent EMC modules
#

package EMC::Options;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Common;
use EMC::Message;


# construct

sub construct {
  return EMC::Common::obtain_hash(shift(@_));
}


# functions

sub identity {
  my $options = shift(@_);
  my $identity = defined($options->{identity}) ? $options->{identity} : {};
  
  foreach ("script", "version", "date", "author", "command_line") {
    last if (!scalar(@_));
    $identity->{$_} = shift(@_);
  }
  $identity->{copyright} = "2004-".EMC::Common::date_year();
  $options->{identity} = $identity;
  return $options;
}


sub version {
  my $options = shift(@_);
  my $identity = $options->{identity};

  EMC::Message::message(
    "EMC $identity->{name} v$identity->{version}, $identity->{date}\n");
  EMC::Message::message(
    "Copyright (c) $identity->{copyright} $identity->{author}\n");
  exit();
}

sub header {
  my $options = shift(@_);
  my $identity = $options->{identity};
  
  EMC::Message::message(
    "$identity->{main} $identity->{name} v$identity->{version} ($identity->{date}), ");
  EMC::Message::message(
    "(c) $identity->{copyright} $identity->{author}\n\n");
}


sub help {
  my $options = shift(@_);
  my $commands = defined($options->{commands}) ? $options->{commands} : undef;
  my $columns = defined($options->{columns}) ? $options->{columns} : 80;
  my $offset = defined($options->{offset}) ? $options->{offset} : 3;
  my $n;
  my $key;
  my $format;

  header($options);
  return if (!defined($commands));
  
  $options->{set_commands}->() if (defined($options->{set_commands}));
  $options->{set_defaults}->($options) if (defined($options->{set_defaults}));

  $columns -= 3;
  foreach (keys(%{$commands})) {
    $n = length($_) if (length($_)>$n); }
  $format = "%-$n.".$n."s ";
  $offset += $n+1;

  print("Usage:\n  $options->{identity}->{script}");
  if (defined($options->{identity}->{command_line})) {
    print(" $options->{identity}->{command_line}\n");
  }
  print("\nCommands:\n");
  foreach $key (sort(keys(%{$commands}))) {
    my $ptr = $commands->{$key};

    printf("  -$format", $key);
    $n = $offset;
    foreach (split(" ", $ptr->{comment})) {
      if (($n += length($_)+1)>$columns) {
	printf("\n   $format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    if (defined($ptr->{get})) {
      $ptr->{default} = $ptr->{get}->();
    }
    if ($ptr->{default} ne "") {
      foreach (split(" ", "[$ptr->{default}]")) {
	if (($n += length($_)+1)>$columns) {
	  printf("\n   $format", ""); $n = $offset+length($_)+1; }
	print(" $_");
      }
    }
    print("\n");
  }

  if (defined($options->{notes})) {
    printf("\nNotes:\n");
    $offset = $n = 3;
    $format = "%$n.".$n."s";
    foreach (@{$options->{notes}}) { 
      $n = $offset;
      printf($format, "*");
      foreach (split(" ")) {
	if (($n += length($_)+1)>$columns) {
	  printf("\n$format", ""); $n = $offset+length($_)+1; }
	print(" $_");
      }
      print("\n");
    }
  }

  printf("\n");
  exit(-1);
}


sub set_help {
  my $struct = shift(@_);
  my $emc = EMC::Common::element($struct, "emc");

  return if (!defined($emc));

  help(set($emc)->{options});
}


sub set {
  my $emc = set_commands(shift(@_));

  if (defined($emc)) {
    my $options = $emc->{options} = {};

    if (defined($emc->{main}) && defined($emc->{main}->{identity})) {
      $options->{identity} = $emc->{main}->{identity};
    }
    foreach (keys(%{$emc})) {
      next if ($_ eq "options");
      next if (ref($emc->{$_}) ne "HASH");
      my $module = $emc->{$_};
      next if (!defined($module->{set}));
      next if (!$module->{set}->{flag}->{commands});

      $options->{commands} = EMC::Common::attributes(
	EMC::Common::obtain_hash($options, "commands"),
	$emc->{$_}->{commands}) if (defined($emc->{$_}->{commands}));
      push(@{$options->{notes}},
       	@{$emc->{$_}->{notes}}) if (defined($emc->{$_}->{notes}));
    }
  }
  return $emc;
}


sub set_commands {
  my $emc = shift(@_);

  if (defined($emc)) {
    foreach (keys(%{$emc})) {
      next if (ref($emc->{$_}) ne "HASH");

      my $module = $emc->{$_}; 
      
      next if (!defined($module->{set}));
      $module->{set}->{commands}->($module);
    }
  }
  return $emc;
}


sub set_defaults {
  my $emc = shift(@_);

  if (defined($emc)) {
    foreach (keys(%{$emc})) {
      next if (ref($emc->{$_}) ne "HASH");

      my $module = $emc->{$_};

      next if (!defined($module->{set}));
      $module->{set}->{defaults}->($module);
    }
  }
  return $emc;
}


#
# Interpretation of options; returns 0 if successful
#
# members of struct:
#   option	STRING	option keyword
#   args	ARRAY	array of string values
#   file	STRING	file name
#   line	INTEGER	line of file; ignored when < 0
#   emc		PTR	pointer to hash containing all shared information
#

sub set_options {
  my $options = shift(@_);
  my $struct = shift(@_);
  my $emc = EMC::Common::element($struct, "emc");
  my $option = EMC::Common::element($struct, "option");
  my $commands = EMC::Common::element($emc->{options}, "commands");

  return if (!defined($commands));
  foreach (keys(%{$commands})) {
    if ($option eq $_) {
      my $command = $commands->{$option};

      if (!defined($command->{set})) {
	error("undefined set function for command '$option'\n");
      }
      return $command->{set}->($struct);
    }
  }
  return undef;
}

