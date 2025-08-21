#!/usr/bin/env perl
#
#  program:	emc_gromacs.pl
#  author:	Pieter J. in 't Veld
#  date:	May 4, 2024.
#  purpose:	Convert GROMACS to EMC fields
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20240504	Inception of v1.0
#

# packages

use File::Basename;

use lib dirname($0)."/modules";
use EMC;
use EMC::GROMACS;

use strict;


# defaults

$::GROMACS::Identity = {
  version	=> "1.0",
  date		=> "May 4, 2024",
  author	=> "Pieter J. in 't Veld"
};


# registration

sub construct {
  my $parent = shift(@_);
  my $root = EMC::Common::element($parent);
  my $global = EMC::Common::hash($root, "global");
  my $modules = {
    fields => [\&EMC::Fields::construct, {commands => 0}],
    gromacs => [\&EMC::GROMACS::construct, {indicator => 0}],
    message => [\&EMC::Message::construct, {commands => 1}]
  };
  my $backwards = 0;

  $root->{modules} = [sort(keys(%{$modules}))];
  foreach (@{$root->{modules}}) {
    next if ($_ eq "global");
    my $ptr = $modules->{$_};
    my $attr = {backwards => $backwards};
    $attr = EMC::Common::attributes($attr, $ptr->[1]) if (defined($ptr->[1]));
    $root->{$_} = EMC::Common::hash($root->{$_});
    $root->{$_}->{root} = $parent;
    $root->{$_}->{parent} = $parent;
    $root->{$_} =  $ptr->[0]->(\$root->{$_}, $attr);
  }

  set_functions($global);
  set_identity($global);
  set_commands($global);
  set_defaults($global);

  EMC::Options::transcribe($root);

  return $root;
}


# initialization

sub set_identity {
  my $global = EMC::Common::hash(shift(@_));
  
  EMC::Common::attributes(
    EMC::Common::hash($global), {
      identity		=>  EMC::Common::attributes(
	$::GROMACS::Identity, {
	  main		=> "EMC",
	  script	=> basename($0),
	  name		=> "GROMACS",
	  copyright	=> "2004-".EMC::Common::date_year(),
	  command_line	=> "[-option[=#]] project"
	}
      )
    }
  );
  return $global;
}


sub set_defaults {
  my $global = EMC::Common::hash(shift(@_));

  $global = EMC::Common::attributes(
    EMC::Common::hash($global),{
      flags => {
	compress	=> 1,
	combine		=> 0,
	field		=> 1,
	find		=> 1,
	kconstraint	=> 20000,
	martini		=> 1,
	output		=> "-",
	source		=> ".",
	target		=> ".",
	virtual_mass	=> 36
      }
    }
  );
  return $global;
}


sub set_flag {
  my $global = EMC::Common::hash(shift(@_));
  my $flag = shift(@_);

  foreach ("combine", "field", "harvest") {
    $global->{$_} = 0;
  }
  $global->{$flag} = 1;
  return $global;
}


sub set_commands {
  my $global = EMC::Common::hash(shift(@_));
  my $flags = EMC::Common::hash($global, "flags");

  $global->{commands} = EMC::Common::attributes(
    EMC::Common::hash($global, "commands"),
    {
      compress		=> {
	comment		=> "compress output",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{compress})
      },
      field		=> {
	comment		=> "create a field using a define file",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{field})
      },
      find		=> {
	comment		=> "ascend into subdirectories for finding template",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{find})
      },
      kconstraint	=> {
	comment		=> "harmonic constraint constant",
	set		=> \&set_options,
	default		=> $flags->{kconstraint}
      },
      martini		=> {
	comment		=> "interpret input as MARTINI force field",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{martini})
      },
      help		=> {
	comment		=> "this message",
	set		=> \&EMC::Options::set_help,
      },
      output		=> {
	comment		=> "set alternate output file",
	set		=> \&set_options,
	default		=> $flags->{output}
      },
      quiet		=> {
	comment		=> "quiet output",
	set		=> \&set_quiet,
	default		=> EMC::Math::boolean(0)
      },
      source		=> {
	comment		=> "set source directory",
	set		=> \&set_options,
	default		=> $flags->{source}
      },
      target		=> {
	comment		=> "set target directory",
	set		=> \&set_options,
	default		=> $flags->{target}
      },
      virtual_mass	=> {
	comment		=> "set default virtual mass",
	set		=> \&set_options,
	default		=> $flags->{virtual_mass}
      }
    }
  );
  $global->{notes} = [
    "'-' as output denotes STDOUT"
  ];
  return $global;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");

  if ($option eq "compress") {
    return $flags->{compress} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "field") {
    return set_flag($global, EMC::Math::flag($args->[0]))->{$option};
  } elsif ($option eq "kconstraint") {
    $flags->{kconstraint} = EMC::Math::eval($args->[0])->[0];
    if ($flags->{kconstraint}<=0) {
      EMC::Message::error_line($line, "constraint constant <= 0\n");
    }
    return $flags->{kconstraint};
  } elsif ($option eq "martini") {
    return $flags->{martini} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "find") {
    return $flags->{find} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "output") {
    return $flags->{output} = $args->[0];
  } elsif ($option eq "source") {
    return $flags->{source} = EMC::IO::scrub_dir($args->[0]);
  } elsif ($option eq "target") {
    return $flags->{target} = EMC::IO::scrub_dir($args->[0]);
  } elsif ($option eq "virtual_mass") {
    $flags->{virtual_mass} = EMC::Math::eval($args->[0])->[0];
    if ($flags->{virtual_mass}<=0) {
      EMC::Message::error_line($line, "virtual mass <= 0\n");
    }
    return $flags->{virtual_mass};
  } else {
    foreach ($root->{set}->{options}) {
      my $result = $_->($struct);
      return $result if (defined($result));
    }
  }
  return undef;
}


sub set_quiet {
  my $struct = shift(@_);
  my $args = EMC::Common::element($struct, "args");
  my $root = EMC::Common::element($struct, "root");

  EMC::Message::set_options({
    option => "message_quiet", root => $root, args => $args});
}


sub set_functions {
  my $global = EMC::Common::hash(shift(@_));
  my $attr = EMC::Common::attributes(@_);
  my $set = EMC::Common::hash($global, "set");
  my $flags = {"commands" => 1};

  $set->{commands} = \&set_commands;
  $set->{defaults} = \&set_defaults;
  $set->{options} = \&set_options;
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $global;
}


# initialization

sub initialize {
  my $root = shift(@_);
  my $struct = {root => $root, line => -1};
  my $global = $root->{global};
  my $flags = $global->{flags};
  my $result = undef;
  my $project = 0;
  my @files;

  EMC::Common::attributes($root, {files => []});
  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @arg = split("=", substr($_,1));
      $struct->{option} = shift(@arg);
      $struct->{args} = [@arg];
      $result = EMC::Options::set_options($root->{options}, $struct);
      if (defined($result) ? 0 : $flags->{ignore} ? 0 : 1) {
	EMC::Options::set_help($struct, 1);
      }
    } else {
      push(@files, $_);
      $project = 1;
    }
  }
  EMC::Options::set_help($struct) if ($project == 0);
  init_output($root);
  foreach (@files) {
    my @found;
    my $name = $_;
    foreach ("", ".itp") {
      my $file = "$flags->{source}/$name".$_;
      @found = $flags->{find} ? EMC::IO::find($flags->{source}, $name.$_) : 
	       -e $file ? ($file) : undef;
      last if (scalar(@found));
    }
    push(@{$root->{files}}, @found) if (scalar(@found));
  }
  if (!scalar(@{$root->{files}})) {
    EMC::Options::header($root->{options});
    EMC::Message::error("no files found.\n");
  }
  if ($flags->{output} eq "-") { set_quiet($root); }
  else {
    $flags->{compress} = 1 if (substr($flags->{output},-3) eq ".gz");
    $flags->{output} = (
      fileparse((fileparse($flags->{output}, "\.gz"))[0], "\.prm"))[0];
    $flags->{output} .= ".prm";
    $flags->{output} .= ".gz" if ($flags->{compress});
  }
  #@{$root->{files}} = sort(@{$root->{files}});
  EMC::Options::header($root->{options});
  return $root;
}


sub init_output {
  my $root = shift(@_);
  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");

  if (substr($flags->{output}, -3) eq ".gz") {
    $flags->{output} = substr($flags->{output}, 0, length($flags->{output})-3);
    $flags->{compress} = 1;
  }
  if ($flags->{output} ne "-") {
    $flags->{output} .= ".prm" if (substr($flags->{output}, -4) ne ".prm");
    $flags->{output} .= ".gz" if ($flags->{compress});
  }
}


sub get {
  my $root = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $field = EMC::Common::hash($attr, "field");
  my $gromacs = EMC::Common::hash($attr, "gromacs");
  my $k = EMC::Common::element($attr, "kconstraint");
  my $vmass = EMC::Common::element($attr, "virtual_mass");

  foreach (@{$root->{files}}) {
    $gromacs = 
      EMC::GROMACS::get(
	$_, {gromacs => $gromacs, kconstraint => $k, virtual_mass => $vmass});
  }
  $field =
    EMC::GROMACS::to_field(
      $gromacs, {type => "martini", field => $field});
  $root->{fields} = $field;
  return $root;
}


# application

sub mass_complete {
  my $field = shift(@_);
  my $data = EMC::Common::element($field, "mass", "data");

  return if (!defined($data));

  my $index = {
    C => "apolar", D => "divalent ion", N => "intermediate", P => "polar",
    Q => "monovalent ion", U => "unknown", W => "water", X => "halogen compound"
  };
  my $pre = {
    S => "small", T => "tiny"};
  my $end = {
    a => "hydrogen acceptor", d => "hydrogen donor", 
    e => "electron donor", v => "electron acceptor",
    h => "increased miscibility", r => "reduced miscibility",
    n => "negative charge", p => "positive charge", q => "partially charged"};

  foreach (keys(%{$data})) {
    my $ptr = $data->{$_};
    my $type = $_;
    my @a = split("", $type);
    my @s = ();
    my $extra;
    my $level;
    my $main;

    foreach (@a) {
      if (defined($pre->{$_})) {
	push(@s, $pre->{$extra = $_});
      } elsif (!defined($main)) {
	push(@s, "ring") if (defined($extra) && $_ eq "C");
	push(@s, $index->{$main = $_});
      } elsif (!defined($level)) {
	push(@s, "level", $level = $_);
      } elsif (defined($end->{$_})) {
	push(@s, $end->{$_});
      }
    }
    $ptr->[1] = $main.$level;	# name
    $ptr->[4] = join(" ", @s);	# comment
  }
}


sub equivalence {
  my $field = shift(@_);

  my $mass = EMC::Common::element($field, "mass", "data");
  my $equivalence = EMC::Common::element($field, "equivalence");
  my $data = EMC::Common::element($equivalence, "data");

  return if (!defined($mass));
  return if (!defined($equivalence));
  return if (!defined($data));

  $equivalence->{flag} = {
    array => 0, cmap => 0, first => 1, ntypes => 1};
  $equivalence->{index} = [
    "type", "pair", "incr", "bond", "angle", "torsion", "improper"];
  foreach (keys(%{$mass})) {
    next if (defined($data->{$_}));
    $data->{$_} = [$_, $_, $_, $_, $_, $_];
  }
  foreach (keys(%{$data})) {
    next if defined($mass->{$_});
    my $t = $data->{$_}->[0];
    if (!defined($mass->{$t})) {
      EMC::Message::warning("missing mass for type '$t'\n");
    }
    EMC::Message::info("creating mass entry for type '$_' from '$t'\n");
    $mass->{$_} = EMC::Element::deep_copy($mass->{$t});
  }
}


# main

{
  my $root = {};
  my $field = EMC::Fields::from_item(
    EMC::Item::read({data => EMC::IO::get("
ITEM	DEFINE

FFMODE	MARTINI
FFTYPE	COARSE
FFAPPLY	ALL
FFMERGE	FALSE
VERSION	".EMC::Common::date_year()."
CREATED	".EMC::Common::date_short()."
LENGTH	NANOMETER
ENERGY	KJ/MOL
DENSITY	G/CC
MIX	NONE
NBONDED	1
INNER	0.9
CUTOFF	1.2
PAIR14	OFF
ANGLE	WARN
TORSION	IGNORE

ITEM	END")}));

  initialize(construct(\$root));
  my $flags = $root->{global}->{flags};
  get($root, {
      field => $field, 
      kconstraint => $flags->{kconstraint},
      virtual_mass => $flags->{virtual_mass}
    });
  #EMC::Message::dumper("field = ", $field);
  #EMC::Message::dumper("field = ", EMC::Fields::to_item($field));

  my $flags = EMC::Common::element($root, "global", "flags");
  mass_complete($field) if ($flags->{martini});
  equivalence($field);
  EMC::Fields::put($root->{global}->{flags}->{output}, $field);

  #EMC::Message::dumper("field = ", $field);
  EMC::Message::message("\n");
}
