#!/usr/bin/env perl
#
#  program:	Charmm.pm
#  author:	Pieter J. in 't Veld
#  date:	January 18, 2023.
#  purpose:	Charmm structure routines; part of EMC distribution
#
#  members:
#
#  
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20230118	Inception of v1.0
#

package Charmm;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

# packages

use EMC::Common;
use EMC::Message;

use Charmm::Global;


# Identity

$Charmm::Identity = {
  version		=> "1.0",
  date			=> "January 18, 2023",
  author		=> "Pieter J. in 't Veld",
  command_line		=> "[-option[=value]] project [additional [...]]",
  name			=> "Charmm",
};


# construct

sub construct {
  my $parent = shift(@_);
  my $root = defined($parent) ? EMC::Common::element($parent) : {};
  my $global = EMC::Common::hash($root, "global");
  my $modules = {
    global => [\&Charmm::Global::construct, {indicator => 0}],
    message => [\&EMC::Message::construct, {indicator => 0}]
  };

  $root->{files} = [];
  $root->{modules} = [sort(keys(%{$modules}))];
  $parent = \$root if (!defined($parent));
  foreach (@{$root->{modules}}) {
    my $ptr = $modules->{$_};

    $root->{$_} = EMC::Common::hash($root->{$_});
    $root->{$_}->{root} = $parent;
    $root->{$_}->{parent} = $parent;
    $root->{$_} = scalar(@{$ptr})>1 ? 
	$ptr->[0]->(\$root->{$_}, $ptr->[1]) : $ptr->[0]->(\$root->{$_});
  }

  set_identity($global);
  set_defaults($global);

  EMC::Options::transcribe($root);

  return $root;
}


sub set_identity {
  my $global = EMC::Common::hash(shift(@_));
  my $win = $^O eq "MSWin32" ? 1 : 0;
  my $emc = EMC::IO::scrub_dir(
    dirname($0).($win ? "/../bin/emc_win32.exe" : "/emc.sh"));
  $emc =~ s/\//\\/g if ($win);
  my $version = !$win && -e $emc ? (split(" ", `$emc -version`))[2] : "9.4.4";
  my $split = ($win ? "\\\\" : "/");
  my @arg = split($split, $0);
  my $root = EMC::IO::emc_root();
  
  @arg = (split($split, $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  my $script = @arg[-1];
  $global = EMC::Common::attributes(
    EMC::Common::hash($global),
    {
      identity		=>  EMC::Common::attributes(
	$Charmm::Identity,
	{
	  main		=> "EMC",
	  script	=> $script,
	  copyright	=> "2004-".EMC::Common::date_year(),
	  emc		=> {
	    exec	=> $emc,
	    root	=> $root,
	    version	=> $version
	  }
	}
      )
    }
  );
  return $global;
}


sub set_defaults {
  my $global = EMC::Common::hash(shift(@_));

  return $global;
}


# initialization

sub initialize {
  my $root = EMC::Common::hash(shift(@_));
  my $struct = {root => $root, line => -1};
  my $global = $root->{global};
  my $flag = $global->{flag};
  my $result = undef;

  my $script = $global->{script};
  my $ext = $script->{extension};

  # determine script

  if (! -e $script->{name}.$ext) {
    EMC::Options::set_help($struct) if (!scalar(@ARGV));
    foreach (@ARGV) {
      my @a = split("=");
      $script->{extension} = $ext = @a[1] if (@a[0] eq "-extension");
      next if (substr($_,0,1) eq "-");
      $script->{name} = EMC::IO::strip($_, $ext);
      last;
    }
  }

  my $ext = {rtf => 1, prm => 2, str => 3};
  my $pre = ["", "top", "par", "toppar"];
  my $charmm = $root->{charmm};
  my $options = $root->{options};
  my $names = [];
  my $check = {};

  # check command line

  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @arg = split("=", substr($_,1));
      $struct->{option} = shift(@arg);
      $struct->{args} = [@arg];
      $result = EMC::Options::set_options($options, $struct);
      if (defined($result) ? 0 : $flag->{ignore} ? 0 : 1) {
	EMC::Options::set_help($struct);
      }
    } else {
      my $flag = 1;						# scrub name
      my ($name, $path, $suffix) = fileparse($_, '\.[^\.]*');
      
      if (defined($ext->{$suffix})) {
	$flag = $ext->{$suffix};
	$name =~ s/^($pre->[$flag])\s+//;
      }
      next if ($check->{$_});
      $check->{$_} = $flag ;
      push(@{$names}, $_);

    }
  }
  EMC::Options::set_help($struct) if (!scalar(@{$names}));
  $charmm->{flag}->{debug} = $root->{message}->{flag}->{debug};

  my $name = $names->[0];
  my @arg = split("/", $charmm->{source_dir});
  
  $charmm->{source_dir} = scalar(@arg) ? join("/", @arg)."/" : "";
  $charmm->{define_name} = (
    defined($charmm->{define_name}) ? $charmm->{define_name} : $name).".define";
  $name = $charmm->{output} if (defined($charmm->{output}));
  $charmm->{created_parameter_name} = $name.".prm";
  $charmm->{created_topology_name} = $name.".top";
  $charmm->{project_name} = $name;
  EMC::Options::header($root->{options});
  Charmm::Common::check_shake($charmm->{define}->{shake});
  Charmm::IO::files($charmm, $names);

  return $root;
}

# functions

