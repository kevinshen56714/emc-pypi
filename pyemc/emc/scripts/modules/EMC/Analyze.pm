#!/usr/bin/env perl
#
#  module:	EMC::Analyze.pm
#  author:	Pieter J. in 't Veld
#  date:	September 4, 2022.
#  purpose:	Analyze structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "analyze_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20220904	Inception of v1.0
#

package EMC::Analyze;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Analyze'

use EMC::Common;
use EMC::Element;
use EMC::IO;
use EMC::Math;


# defaults

$EMC::Analyze::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 4, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $analyze = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($analyze, $attr);
  set_defaults($analyze);
  set_commands($analyze);
  return $analyze;
}


# initialization

sub set_defaults {
  my $analyze = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");
  my $flag_backwards = $backwards ? 1 : 0;
  
  # context

  $analyze->{context} = EMC::Common::attributes( 
    EMC::Common::hash($analyze, "context"),
    {
      # L

      location		=> [EMC::IO::emc_root()."/scripts/analyze"],

      # S

      sample		=> {
	energy		=> 0,
	"green-kubo"	=> 0,
	gyration	=> 0,
	msd		=> 0,
	pressure	=> 1,
	volume		=> 0
      },
      source		=> "",
      skip		=> 0,

      # T

      target		=> "",

      # U

      user		=> "",

      # W

      window		=> 1
    }
  );

  # flag

  $analyze->{flag} = EMC::Common::attributes(
    {
      archive		=> 1,
      data		=> 1,
      replace		=> 1
    },
    EMC::Common::hash($analyze, "flag")
  );

  # script

  $analyze->{scripts} = EMC::Common::attributes(
    EMC::Common::hash($analyze, "scripts"),
    {
      # B

      bond		=> {		# Bond distance from trajectory
	active		=> 0,
	queue		=> 1,
	script		=> "script.sh",
	options		=> {
	  type		=> "bond",
	  binsize	=> 0.01,
	  queue		=> "\${queue}",
	  walltime	=> "\${walltime}"
	}
      },

      # C

      cavity		=> {		# Cavity size ditribution from
	active		=> 0,		# trajectory
	queue		=> 1,
	script		=> "cavity.sh",
	options		=> {
	  type		=> "cavity",
	  queue		=> "\${queue}",
	  walltime	=> "\${walltime}"
	}
      },

      # D

      density 		=> {		# Density profile post processing
	active		=> $flag_backwards,
	queue		=> 0,
	script		=> "files.sh",
	options		=> {
	  type		=> "density"
	}
      },
      distance		=> {		# End-to-end distance from trajectory
	active		=> 0,
	queue		=> 1,
	script		=> "script.sh",
	options		=> {
	  type		=> "distance",
	  queue		=> "\${queue}",
	  walltime	=> "\${walltime}"
	}
      },

      # E

      energy		=> {		# Energy tensor post processing
	active		=> $flag_backwards,
	queue		=> 0,
	script		=> "project.sh",
	options		=> {
	  type		=> "energy"
	}
      },

      # I

      interaction	=> {		# Interaction energy profiles
	active		=> 0,
	queue		=> 0,
	script		=> "harvest.sh",
	options		=> {
	  type		=> "interaction",
	  copy		=> 1
	}
      },

      # G

      gr		=> {		# Radius of gyration from trajectory
	active		=> 0,
	queue		=> 1,
	script		=> "script.sh",
	options		=> {
	  type		=> "gyration",
	  cutoff	=> "\${cutoff}",
	  queue		=> "\${queue}",
	  walltime	=> "\${walltime}"
	}
      },
      "green-kubo"	=> {		# Green-Kubo post processing
	active		=> $flag_backwards,
	queue		=> 0,
	script		=> "project.sh",
	options		=> {
	  type		=> "green-kubo"
	}
      },
      gyration		=> {		# Radius of gyration from trajectory
	active		=> 0,
	queue		=> 0,
	script		=> "files.sh",
	options		=> {
	  type		=> "gyration",
	}
      },

      # L

      last		=> {		# Last frame from trajectory
	active		=> 0,
	queue		=> 0,
	script		=> "last.sh",
	options		=> {
	  emc		=> "\${femc}",
	  pdb		=> "\${fpdb}"
	}
      },

      # M

      msd		=> {		# MSD post processing
	active		=> $flag_backwards,
	queue		=> 0,
	script		=> "files.sh",
	options		=> {
	  null		=> 0,
	  type		=> "msd"
	}
      },

      # P

      pressure		=> {		# Pressure profile post processing
	active		=> $flag_backwards,
	queue		=> 0,
	script		=> "files.sh",
	options		=> {
	  type		=> "pressure"
	}
      },

      # V

      volume		=> {		# Volume tensor post processing
	active		=> 0, #1,
	queue		=> 0,
	script		=> "project.sh",
	options		=> {
	  type		=> "volume"
	}
      }
    }
  );

  # sanity checks

  my $checks = {
    "cavity.sh"		=> "*/\${project}.dump",
    "files.sh"		=> "*/*.\${type}",
    "harvest.sh"	=> "*/*/\${project}.m",
    "last.sh"		=> "*/\${project}.dump",
    "project.sh"	=> "*/\${project}.\${type}",
    "script.sh"		=> "*/\${project}.dump"
  };

  foreach (keys(%{$analyze->{scripts}})) {
    my $type = $_;
    my $hash = $analyze->{scripts}->{$_};
    
    next if (defined($hash->{check}));
    $hash->{check} = $checks->{$hash->{script}};
    $hash->{check} =~ s/\$\{type\}/$type/g;
  }

  # identity

  $analyze->{identity} = EMC::Common::attributes(
    EMC::Common::hash($analyze, "identity"),
    $EMC::Analyze::Identity
  );
  return $analyze;
}


sub transfer {
  my $analyze = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($analyze, "flag");
  my $context = EMC::Common::element($analyze, "context");
  my $scripts = EMC::Common::element($analyze, "scripts");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Analyze{archive},		\$flag->{archive}],
    [\$::EMC::Analyze{data},		\$flag->{data}],
    [\$::EMC::Analyze{location},	\$context->{location}],
    [\$::EMC::Analyze{replace},		\$flag->{replace}],
    [\$::EMC::Analyze{scripts},		\$analyze->{scripts}],
    [\$::EMC::Analyze{skip},		\$context->{skip}],
    [\$::EMC::Analyze{source},		\$context->{source}],
    [\$::EMC::Analyze{target},		\$context->{target}],
    [\$::EMC::Analyze{user},		\$context->{user}],
    [\$::EMC::Analyze{window},		\$context->{window}],
    [\%::EMC::Sample,			\$context->{sample}]
  );
}


sub set_context {
  my $analyze = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($global, "context", "field");
  my $units = EMC::Common::element($global, "context", "units");
  my $flag = EMC::Common::element($analyze, "flag");
  my $context = EMC::Common::element($analyze, "context");
  my $sample = EMC::Common::element($analyze, "context", "sample");
  my $scripts = EMC::Common::element($analyze, "context", "scripts");

  # L

  $context->{location} = $global->{location}->{analyze};

  # S

  foreach (keys(%{$sample})) {
    $scripts->{$_}->{active} = $sample->{$_} if (!$scripts->{$_}->{active});
  }
}


sub set_commands {
  my $analyze = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($analyze, "set");
  my $flag = EMC::Common::element($analyze, "flag");
  my $context = EMC::Common::element($analyze, "context");
  my $scripts = EMC::Common::element($analyze, "scripts");
  my $sample = EMC::Common::element($analyze, "context", "sample");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  
  $indicator = $indicator ? "analyze_" : "";
  my $commands = $analyze->{commands} = EMC::Common::attributes(
    EMC::Common::hash($analyze, "commands"),
    {
      # A

      $indicator."archive"	=> {
	comment		=> "archive file names associated with analyzed data",
	default		=> EMC::Math::boolean($flag->{archive}),
	gui		=> ["boolean", "environment", "analysis", "standard"]},

      # D

      $indicator."data"	=> {
	comment		=> "create tar archive from exchange file list",
	default		=> EMC::Math::boolean($flag->{data}),
	gui		=> ["boolean", "environment", "analysis", "standard"]},

      # L

      $indicator."last"	=> {
	comment		=> "include last trajectory frame (deprecated)",
	default		=> EMC::Math::boolean($scripts->{last}->{active}),
	gui		=> ["boolean", "environment", "analysis", "standard"]},

      # M

      msd		=> {
	comment		=> "set LAMMPS mean square displacement output",
	default		=> $sample->{msd}!=2 ? EMC::Math::boolean($sample->{msd}) : "average",
	gui		=> ["boolean", "chemistry", "analysis", "standard"]},

      # R

      $indicator."replace"	=> {
	comment		=> "replace already exisiting analysis results",
	default		=> EMC::Math::boolean($flag->{replace}),
	gui		=> ["boolean", "environment", "analysis", "standard"]},

      # S

      sample		=> {
	comment		=> "set sampling options",
	default		=> EMC::Hash::text($sample, "boolean"),
	gui		=> ["string", "chemistry", "top", "standard"]},      
      $indicator."skip"	=> {
	comment		=> "set the number of initial frames to skip",
	default		=> $context->{skip},
	gui		=> ["integer", "environment", "analysis", "standard"]},
      $indicator."source"	=> {
	comment		=> "set data source directory for analysis scripts",
	default		=> $context->{source},
	gui		=> ["string", "environment", "analysis", "ignore"]},

      # U

      $indicator."user"	=> {
	comment		=> "set directory for user analysis scripts",
	default		=> $context->{user},
	gui		=> ["string", "environment", "analysis", "standard"]},

      # W

      $indicator."window"	=> {
	comment		=> "set the number of frames in window average",
	default		=> $context->{window},
	gui		=> ["integer", "environment", "analysis", "standard"]},
    }
  );

  foreach (keys(%{$commands})) {
    my $ptr = $commands->{$_};
    if (!defined($ptr->{set})) {
      $ptr->{set} = \&EMC::Analyze::set_options;
    }
  }

  EMC::Options::set_command(
    $analyze->{items} = EMC::Common::attributes(
      EMC::Common::hash($analyze, "items"),
      {
	# A

	#analysis	=> {},
	analyze		=> {}
      }
    ),
    {
      chemistry		=> 0,
      environment	=> 1,
      order		=> 0,
      set		=> \&set_item_analyze
    }
  );

  return $analyze;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $analyze = EMC::Common::element($struct, "module");
  my $context = EMC::Common::hash($analyze, "context");
  my $sample = EMC::Common::hash($analyze, "context", "sample");
  my $flag = EMC::Common::hash($analyze, "flag");
  my $set = EMC::Common::element($analyze, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "analyze_" : "";

  # A

  if ($option eq $indicator."archive") {
    return $context->{archive} = EMC::Math::flag($args->[0]); }

  # D

  if ($option eq $indicator."data") {
    return $context->{data} = EMC::Math::flag($args->[0]); }

  # L

  if ($option eq $indicator."last") {
    return $context->{scripts}->{last}->{active} = EMC::Math::flag($args->[0]); }

  # M

  if ($option eq "msd") {
    return $sample->{msd} = 
	$args->[0] ne "average" ? EMC::Math::flag($args->[0]) : 2; }

  # R

  if ($option eq $indicator."replace") {
    return $context->{replace} = EMC::Math::flag($args->[0]); }

  # S

  if ($option eq "sample") {
    EMC::Hash::set($line, $sample, "string", "", [], @{$args});
    my %average = (msd => 1);
    my %allowed = (false => 0, true => 1, average => 2);
    foreach (sort(keys(%{$sample}))) {
      my $s = $sample->{$_};
      my $v = defined($allowed{$s}) ? $allowed{$s} : -1;
      $v = $s ne "" ? ($s !~ /\D/ ? int(eval($s)) : -1) : 1 if ($v<0);
      $v = -1 if (defined($average{$_}) ? $v>2 : $v>1);
      EMC::Message::error_line(
	$line, "unallowed option '$s' for keyword '$_'\n") if ($v<0);
      $sample->{$_} = $v;
    }
    return 1;
  }
  if ($option eq $indicator."skip") {
    my $value = EMC::Math::eval($args->[0])->[0];
    return $context->{skip} = $value<0 ? 0 : int($value);
  }
  if ($option eq $indicator."source") {
    return $context->{source} = EMC::IO::expand_tilde($args->[0]); }

  # U

  if ($option eq $indicator."user") {
    return $context->{user} = EMC::IO::expand_tilde($args->[0]); }

  # W

  if ($option eq $indicator."window") {
    my $value = EMC::Math::eval($args->[0])->[0];
    return $context->{window} = $value<1 ? 1 : int($value);
  }

  # S
    
  return undef;
}


sub set_functions {
  my $analyze = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($analyze, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, indicator => 1, items => 1};

  $set->{commands} = \&set_commands;
  $set->{defaults} = \&set_defaults;
  $set->{options} = \&set_options;

  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $analyze;
}


# set item

sub set_item_analyze {
  my $struct = shift(@_);
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));
  my $root = EMC::Common::element($struct, "root");

  return $root if (EMC::Common::element($options, "comment"));
  
  my $option = EMC::Common::element($struct, "option");
  my $analyze = EMC::Common::element($struct, "module");
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $i = 0;

  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$i++];

    my $script = shift(@arg);
    my $key = (split("\\.sh", $script))[0];
    my $hash;

    if (!defined($analyze->{scripts}->{$key})) {
      $hash = {active => 1, queue => 0, options => {type => $key}};
      $analyze->{scripts}->{$key} = $hash;
      $hash->{script} = $script;
    } else {
      $hash = $analyze->{scripts}->{$key};
      $hash->{active} = 1;
      #EMC::Message::dumper($hash);
    }
    foreach (@arg) {
      my @a = split("=");
      if (@a[0] eq "active") {
	$hash->{active} = EMC::Math::flag(@a[1]); next;
      } elsif (@a[0] eq "queue") {
	$hash->{queue} = EMC::Math::flag(@a[1]); next;
      } elsif (@a[0] eq "script") {
	$hash->{script} = @a[1]; next;
      }
      $hash->{options}->{@a[0]} = @a[1] eq "" ? 1 : @a[1];
    }
    if (!defined($hash->{script})) {
      EMC::Message::error_line($line, "missing script definition\n");
    }
  }
  return $root;
}

