#!/usr/bin/env perl
#
#  program:	emc_combine.pl
#  author:	Pieter J. in 't Veld
#  date:	December 22, 2021, January 4, 15-18, 2022.
#  purpose:	Harvest EMC distribtions and combine EMC fields
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20211222	Conception date
#    20220104	Addition of options
#    20220115	Structural reorganization
#    20220118	Incorporation of both harvest and combine into one script
#

# packages

use File::Basename;

use lib dirname($0)."/modules";
use EMC;

use strict;


# registration

sub construct {
  my $emc = EMC::Common::obtain_hash(shift(@_));
  my $main = EMC::Common::obtain_hash($emc, "main");

  $emc->{field} = EMC::Field::construct($emc->{field}, {indicator => 0});
  $emc->{message} = EMC::Message::construct($emc->{message}, {commands => 0});

  set_functions($main);
  set_identity($main);
  set_commands($main);
  set_defaults($main);

  EMC::Options::set_commands($emc);
  EMC::Options::set_defaults($emc);
  EMC::Options::set($emc);

  return $emc;
}


# initialization

sub set_identity {
  my $main = EMC::Common::obtain_hash(shift(@_));
  
  $main = EMC::Common::attributes(
    EMC::Common::obtain_hash($main),
    {
      identity		=> {
	main		=> "EMC",
	script		=> basename($0),
	name		=> "Combine",
	version		=> "1.0",
	date		=> "January 18, 2022",
	author		=> "Pieter J. in 't Veld",
	copyright	=> "2004-".EMC::Common::date_year(),
	command_line	=> "[-option[=#]] project"
      }
    }
  );
  return $main;
}


sub set_defaults {
  my $main = EMC::Common::obtain_hash(shift(@_));

  $main = EMC::Common::attributes(
    EMC::Common::obtain_hash($main, "flags"),
    {
      compress		=> 1,
      harvest		=> 0,
      nfilter		=> 10,
      output		=> "-",
      source		=> ".",
      target		=> "."
    }
  );
  return $main;
}


sub set_commands {
  my $main = EMC::Common::obtain_hash(shift(@_));
  my $flags = EMC::Common::obtain_hash($main, "flags");

  init_output($main);
  $main->{commands} = EMC::Common::attributes(
    EMC::Common::obtain_hash($main, "commands"),
    {
      compress		=> {
	comment		=> "compress output",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{compress})
      },
      harvest		=> {
	comment		=> "harvest distributions into a field",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{harvest})
      },
      help		=> {
	comment		=> "this message",
	set		=> \&EMC::Options::set_help,
      },
      ignore		=> {
	comment		=> "ignore incorrect options",
	set		=> \&set_options,
	default		=> $flags->{ignore}
      },
      nfilter		=> {
	comment		=> "set band pass filter width",
	set		=> \&set_options,
	default		=> $flags->{nfilter}
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
      }
    }
  );
  $main->{notes} = [
    "'-' as output denotes STDOUT"
  ];
  return $main;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $emc = EMC::Common::element($struct, "emc");
  my $main = EMC::Common::obtain_hash($emc, "main");
  my $flags = EMC::Common::obtain_hash($main, "flags");

  if ($option eq "compress") {
    return $flags->{compress} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "harvest") {
    return $flags->{harvest} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "ignore") {
    return $flags->{ignore} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "nfilter") {
    return $flags->{nfilter} = EMC::Math::eval($args->[0])->[0];
  } elsif ($option eq "output") {
    return $flags->{output} = $args->[0];
  } elsif ($option eq "source") {
    return $flags->{source} = EMC::IO::scrub_dir($args->[0]);
  } elsif ($option eq "target") {
    return $flags->{target} = EMC::IO::scrub_dir($args->[0]);
  } else {
    foreach ($emc->{set}->{options}) {
      my $result = $_->($struct);
      return $result if (defined($result));
    }
  }
  return undef;
}


sub set_quiet {
  my $struct = shift(@_);
  my $args = EMC::Common::element($struct, "args");
  my $emc = EMC::Common::element($struct, "emc");

  EMC::Message::set_options({
    option => "message_quiet", emc => $emc, args => $args});
}


sub set_functions {
  my $main = EMC::Common::obtain_hash(shift(@_));
  my $attr = EMC::Common::attributes(@_);
  my $set = EMC::Common::obtain_hash($main, "set");
  my $flags = {"commands" => 1};

  $set->{commands} = \&set_commands;
  $set->{defaults} = \&set_defaults;
  $set->{options} = \&set_options;
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $main;
}


sub init {
  my $emc = construct({files => []});
  my $struct = {emc => $emc};
  my $main = $emc->{main};
  my $flags = $main->{flags};
  my $result = undef;
  my $project = 0;

  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @arg = split("=", substr($_,1));
      $struct->{option} = shift(@arg);
      $struct->{args} = [@arg];
      $result = EMC::Options::set_options($emc->{options}, $struct);
      if (defined($result) ? 0 : $flags->{ignore} ? 0 : 1) {
	EMC::Options::set_help($struct);
      }
    } else {
      my @found = EMC::IO::find($flags->{source}, $_);
      push(@{$emc->{files}}, @found) if (scalar(@found));
      $project = 1;
    }
  }
  init_output($emc);
  EMC::Options::set_help($struct) if (!$project);
  if (!scalar(@{$emc->{files}})) {
    EMC::Options::header($emc->{options});
    EMC::Message::error("no files found.\n");
  }
  set_quiet($emc) if ($flags->{output} eq "-");
  @{$emc->{files}} = sort(@{$emc->{files}});
  return $emc;
}


sub init_output {
  my $emc = shift(@_);
  my $main = EMC::Common::obtain_hash($emc, "main");
  my $flags = EMC::Common::obtain_hash($main, "flags");

  if (substr($flags->{output}, -3) eq ".gz") {
    $flags->{output} = substr($flags->{output}, 0, length($flags->{output})-3);
    $flags->{compress} = 1;
  }
  if ($flags->{output} ne "-") {
    $flags->{output} .= ".prm" if (substr($flags->{output}, -4) ne ".prm");
    $flags->{output} .= ".gz" if ($flags->{compress});
  }
}


# harvest functions

sub add {
  my $msg;
  my $var;
  my $name;
  my $struct;
  my $import = EMC::Element::type(@{@_[0]}) ? 0 : 1;
  my $dists = ["volume1", "volume2", "volume3", "volume4", "energy"];
  my $scalars = ["i1", "i2", "i3", "i4", "type", "mass", "dvolume", "denergy"];

  foreach (@{@_[0]}) {
    if ($import) {
      my $stream = EMC::IO::open($name = $_, "r");
      $var = EMC::Struct::read($stream);
      $msg = "structure '$name' differs";
      EMC::IO::close($stream, $name);
    } else {
      $msg = "structures differ";
      $var = $_;
    }
    foreach(@{$dists}) {
      EMC::Dist::repair($var->{$_});
    }
    if (defined($struct)) {
      foreach(@{$scalars}) {
	if (defined($struct->{$_}) == defined($var->{$_})) {
	  next if (!defined($struct->{$_}));
	  next if (!EMC::Struct::compare($struct->{$_}, $var->{$_}));
	}
	EMC::Message::error("$msg for '$_'.\n");
      }
      foreach(@{$dists}) {
	if (defined($struct->{$_}) != defined($var->{$_})) {
	  EMC::Message::error("$msg for '$_'.\n");
	}
	next if (!defined($struct->{$_}));
	EMC::Dist::add($struct->{$_}, $var->{$_});
      }
      foreach ("ntrials", "nvolumes") {
 	if (defined($struct->{$_}) != defined($var->{$_})) {
	  EMC::Message::error("$msg for '$_'.\n");
	}
	next if (!defined($struct->{$_}));
	$struct->{$_} += $var->{$_};
     }
    } else {
      $struct = EMC::Element::copy($var);
    }
  }
  return $struct;
}


sub create_types {
  my $index;
  my $group;
  my $struct = shift(@_);

  foreach (@{$struct->{groups}}) {
    my $grp = $_;
    my $id = $grp->{id};
    foreach (keys(%{$grp})) {
      next if ($_ eq "id");
      $group->{$id}->{$_} = $grp->{$_};
    }
  }
  $struct->{types} = [];
  for (my $n=1; $n<4; ++$n) {
    my $index = "i$n";
    my $volume = "volume$n";
    next if (!defined($struct->{$index}));
    $index = $struct->{$index};
    my $id = $index->{groups};
    my $entry;
    foreach (keys(%{$group->{$id}})) {
      $entry->{$_} = $group->{$id}->{$_};
    }
    $entry->{mass} = $struct->{mass}->[$n-1];
    $entry->{volume} = $struct->{$volume}->{moment}->[0];
    $entry->{type} = defined($index->{name}) ?
				$index->{name} : $group->{$id}->{chemistry};
    $entry->{comment} = defined($index->{comment}) ? $index->{comment} : "";
    push(@{$struct->{types}}, $entry);
  }
  return $struct;
}


# harvest item

sub write_header {
  my $stream = shift(@_);
  my $name = shift(@_);

  $name = basename($name, ".gz");
  print ($stream "#EMC/FIELD/TABLE/$EMC::Identity->{version}
#
#   file:	$name
#   author:	EMC v$EMC::Identity->{version}
#   date:	".EMC::Common::date_full()."
#   purpose:	Interaction table for tabulated potentials
#

"
  );
}


sub item_define {
  my $field = shift(@_);
  my $item = {data => [], options => []};
  my $index = [
    "ffmode", "fftype", "ffapply", "angle", "torsion", "length", "energy",
    "density", "nbonded", "version"];

  EMC::Message::info("creating define section\n");
  foreach (@{$index}) {
    push(@{$item->{data}}, [uc($_), uc($field->{define}->{$_})])
  }
  return $item;
}


sub item_mass {
  my $struct = shift(@_);
  my $item = {data => [], options => []};
  my $types;

  EMC::Message::info("creating mass section\n");

  push(
    @{$item->{data}},
    ["#", "type", "mass", "volume", "chem", "ncons", "charge", "comment"]);
  foreach (@{$struct->{types}}) {
    my $type = $_->{type};
    my $chem = $_->{chemistry};
    my $ncons = $chem =~ tr/\*//;
    
    ++$types->{$type}->{n};
    $types->{$type}->{ncons} = $ncons;
    $types->{$type}->{chemistry} = $chem;
    $types->{$type}->{charge} = $_->{charge};
    $types->{$type}->{mass} += $_->{mass};
    $types->{$type}->{volume} += $_->{volume};
    $types->{$type}->{comment} = $_->{comment};
  }
  foreach (sort(keys(%{$types}))) {
    my $entry = $types->{$_};
    push(
      @{$item->{data}},
      [$_,
	EMC::Math::round($entry->{mass}/$entry->{n}, 1e-4),
       	EMC::Math::round($entry->{volume}/$entry->{n}, 1e-4),
       	$entry->{chemistry},
       	$entry->{ncons},
	EMC::Math::round($entry->{charge}/$entry->{n}, 1e-4),
	$entry->{comment}
      ]
    );
  }
  return $item;
}


sub item_table {
  my $struct = shift(@_);
  my $nfilter = shift(@_);
  my $ns = {pair => 2, bond => 2, angle => 3, torsion => 4};
  my $n = $ns->{$struct->{type}};
  my $item = {data => [], options => []};
  my $list = EMC::List::filter(EMC::Dist::list($struct->{energy}), $nfilter);
  my $type = [];
  my $header = ["#"];

  EMC::Message::info("creating table section\n");
  
  for (my $i=1; $i<=$n; ++$i) {
    push(@{$header}, "type$i");
  }
  push(@{$header}, "t", "n", "x0", "dx", "table");
  foreach (@{$struct->{types}}) {
    push(@{$type}, $_->{chemistry});
  }
  push(
    @{$item->{data}}, $header,
    [@{$type}, "T", $struct->{t}, "TABLE", $#{$list}+1, $list->[0]->[0], 
      EMC::Math::round($list->[1]->[0]-$list->[0]->[0], 1e-8)]);
 
  my $n = 0;
  my $sub = [];

  foreach (@{$list}) {
    if ($n==5) {
      push(@{$item->{data}}, $sub);
      $sub = [];
      $n = 0;
    }
    push(@{$sub}, EMC::Math::round($_->[1], 1e-8));
    ++$n;
  }
  push(@{$item->{data}}, $sub) if ($n);
  return $item;
}


# harvest distributions

sub harvest {
  my $emc = shift(@_);
  my $flags = $emc->{main}->{flags};
  my $struct = create_types(add($emc->{files}));
  my $option = {
    pair => "nonbond", bond => "bond", angle => "angle", torsion => "torsion"
  };

  EMC::Options::header($emc->{options});
  if (!defined($option->{$struct->{type}})) {
    EMC::Message::error("unsupported type: '$struct->{type}'\n");
  }
  EMC::Message::info("nfilter = $flags->{nfilter}\n");
  my $item = {
    index => ["define", "mass", $option->{$struct->{type}}],
    define => item_define($emc->{field}),
    mass => item_mass($struct),
    $option->{$struct->{type}} => item_table($struct, $flags->{nfilter})
  };

  my $name = $flags->{output} eq "-" ? $flags->{output} :
	     $flags->{target} eq "." ? $flags->{output} :
	     join("/", $flags->{target}, $flags->{output});
  my $stream = EMC::IO::open($name, "w");
  
  EMC::Message::info("writing field to '$name'\n");
  write_header($stream, $name eq "-" ? $struct->{type}.".prm" : $name);
  EMC::Item::write($stream, $item);
  EMC::IO::close($stream, $name);
  EMC::Message::message("\n");
}


# combine fields

sub field_import {
  my $name = shift(@_);
  my $field = shift(@_);
  my $stream;

  EMC::Message::info("reading field from '$name'\n");
  $stream = EMC::IO::open($name, "r");
  $field = EMC::Field::read($stream, {field => $field});
  EMC::IO::close($stream, $name);
  
  return $field;
}

sub combine {
  my $emc = shift(@_);
  my $flags = $emc->{main}->{flags};
  my $field;

  EMC::Options::header($emc->{options});
  #$field = field_import($flags->{output}) if (-e $flags->{output});
  foreach (@{$emc->{files}}) {
    $field = field_import($_, $field);
  }

  my $name = $flags->{output} eq "-" ? $flags->{output} :
	     $flags->{target} eq "." ? $flags->{output} :
	     join("/", $flags->{target}, $flags->{output});
  my $stream = EMC::IO::open($name, "w");
  
  EMC::Message::info("writing field to '$name'\n");
  delete($field->{header});
  write_header($stream, $name eq "-" ? "table.prm" : $name);
  EMC::Field::write($stream, $field);
  EMC::IO::close($stream, $name);
  EMC::Message::message("\n");
}


# main

{
  my $emc = init(@ARGV);
  my $flags = $emc->{main}->{flags};

  if ($flags->{harvest}) {
    harvest($emc);
  } else {
    combine($emc);
  }
}

