#!/usr/bin/env perl
#
#  module:	EMC::LAMMPS.pm
#  author:	Pieter J. in 't Veld
#  date:	August 31, 2022.
#  purpose:	LAMMPS structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "lammps_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#
#    flag		HASH	optional flags
#
#    write		HASH
#      emc		FUNC	EMC script additions
#      job		FUNC	BASH workflow additions
#      script		FUNC	LAMMPS script
#
#  notes:
#    20220831	Inception of v1.0
#

package EMC::LAMMPS;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::LAMMPS'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Math;
use EMC::Script;


# defaults

$EMC::LAMMPS::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "August 31, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $lammps = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($lammps, $attr);
  set_defaults($lammps);
  set_commands($lammps);
  return $lammps;
}


# initialization

sub set_defaults {
  my $lammps = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $lammps->{context} = EMC::Common::attributes(
    EMC::Common::hash($lammps, "context"),
    {
      dlimit		=> 0.2,
      dtthermo		=> 1000,
      dtdump		=> 100000,
      dtrestart		=> 100000,
      error		=> 0,
      momentum		=> [100,1,1,1,"angular"],
      nchains		=> "", 
      nsample		=> 1000, 
      pdamp		=> 1000,
      restart_ext	=> "restart?",
      skin		=> -1,
      tdamp		=> 100,
      tequil		=> 1000,
      tfreq		=> 10, 
      trun		=> 10000000,
      verbatim		=> undef,
      version		=> 2023, 
      version_pass	=> 0,
      new_version	=> 2015,
      newer_version	=> 2021,
      write		=> 1
    }
  );
  $lammps->{flag} = EMC::Common::attributes(
    EMC::Common::hash($lammps, "flag"),
    {
      cutoff		=> 0,
      chunk		=> 1, 
      communicate	=> 0,
      dump_box		=> 0,
      engine		=> 1,
      momentum		=> 1,
      multi		=> 0,
      prefix		=> 0,
      triclinic		=> 0,
      trun		=> 0,
      version		=> $lammps->{context}->{newer_version},
      write		=> 1
    }
  );
  $lammps->{script} = EMC::Common::attributes(
    EMC::Common::hash($lammps, "script"),
    {
      spot		=> {
	head		=> 0,
	tail		=> 1,
	false		=> 0,
	true		=> 1,
	0		=> 0,
	1		=> 1,
	"-1"		=> 1
      }
    }
  );
  $lammps->{identity} = EMC::Common::attributes(
    EMC::Common::hash($lammps, "identity"),
    $EMC::LAMMPS::Identity
  );
  return $lammps;
}


sub transfer {
  my $lammps = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($lammps, "flag");
  my $context = EMC::Common::element($lammps, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Lammps{cutoff},		\$flag->{cutoff}],
    [\$::EMC::Lammps{chunk},		\$flag->{chunk}],
    [\$::EMC::Lammps{communicate},	\$flag->{communicate}],
    [\$::EMC::Lammps{dlimit},		\$context->{dlimit}],
    [\$::EMC::Lammps{dtdump},		\$context->{dtdump}],
    [\$::EMC::Lammps{dtrestart},	\$context->{dtrestart}],
    [\$::EMC::Lammps{dtthermo},		\$context->{dtthermo}],
    [\$::EMC::Lammps{error},		\$context->{error}],
    [\$::EMC::Lammps{momentum},		\$context->{momentum}],
    [\$::EMC::Lammps{momentum_flag},	\$flag->{momentum}],
    [\$::EMC::Lammps{multi},		\$flag->{multi}],
    [\$::EMC::Lammps{nchains},		\$context->{nchains}],
    [\$::EMC::Lammps{nsample},		\$context->{nsample}],
    [\$::EMC::Lammps{pdamp},		\$context->{pdamp}],
    [\$::EMC::Lammps{prefix},		\$flag->{prefix}],
    [\$::EMC::Lammps{skin},		\$context->{skin}],
    [\$::EMC::Lammps{tdamp},		\$context->{tdamp}],
    [\$::EMC::Lammps{tequil},		\$context->{tequil}],
    [\$::EMC::Lammps{tfreq},		\$context->{tfreq}],
    [\$::EMC::Lammps{triclinic},	\$flag->{triclinic}],
    [\$::EMC::Lammps{trun},		\$context->{trun}],
    [\$::EMC::Lammps{trun_flag},	\$flag->{trun}],
    [\$::EMC::Lammps{version},		\$context->{version}],
    [\$::EMC::Lammps{version_pass},	\$context->{version_pass}],
    [\$::EMC::Lammps{new_version},	\$context->{new_version}],
    [\$::EMC::Lammps{newer_version},	\$context->{newer_version}],
    [\$::EMC::Lammps{write}, 		\$flag->{write}]
  );
}


sub set_commands {
  my $lammps = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($lammps, "set");
  my $flag = EMC::Common::element($lammps, "flag");
  my $context = EMC::Common::element($lammps, "context");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated = $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "lammps_" : "";

  $lammps->{commands} = EMC::Common::attributes(
    EMC::Common::hash($lammps, "commands"), {
      lammps		=> {
	comment		=> "create LAMMPS input script or set LAMMPS version using year, e.g. -lammps=2014 (new versions start at $context->{new_version})",
	default		=> EMC::Math::boolean($flag->{write}),
	set		=> \&EMC::LAMMPS::set_options,
	gui		=> ["boolean", "chemistry", "lammps", "ignore"]},
    }
  );
  while (1) {
    my $commands = {

      # C

      $indicator."chunk"	=> {
	comment		=> "use chunk approach for profiles in LAMMPS script",
	default		=> EMC::Math::boolean($flag->{chunk}),
	gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
      $indicator."communicate"	=> {
	comment		=> "use communicate keyword in LAMMPS script",
	default		=> EMC::Math::boolean($flag->{communicate}),
	gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
      $indicator."cutoff"	=> {
	comment		=> "generate output of pairwise cut off in LAMMPS parameter file",
	default		=> EMC::Math::boolean($flag->{cutoff}),
	gui		=> ["boolean", "chemistry", "lammps", "advanced"]},

      # D

      $indicator."dlimit"	=> {
	comment		=> "set LAMMPS nve/limit distance",
	default		=> $context->{dlimit},
	gui		=> ["real", "chemistry", "lammps", "advanced"]},
      $indicator."dtdump"	=> {
	comment		=> "set LAMMPS trajectory file write frequency",
	default		=> $context->{dtdump},
	gui		=> ["integer", "chemistry", "lammps", "standard"]},
      $indicator."dtrestart"	=> {
	comment		=> "set LAMMPS restart file frequency",
	default		=> $context->{dtrestart},
	gui		=> ["integer", "chemistry", "lammps", "standard"]},
      $indicator."dtthermo"	=> {
	comment		=> "set LAMMPS thermodynamic output frequency",
	default		=> $context->{dtthermo},
	gui		=> ["integer", "chemistry", "lammps", "standard"]},
      $indicator."dump_box"	=> {
	comment		=> "include box multiples in LAMMPS trajectory file",
	default		=> EMC::Math::boolean($flag->{dump_box}),
	gui		=> ["integer", "chemistry", "lammps", "advanced"]},

      # E

      $indicator."error"	=> {
	comment		=> "restart LAMMPS only upon previous error",
	default		=> EMC::Math::boolean($flag->{error}),
	gui		=> ["real", "chemistry", "lammps", "advanced"]},

      # M

      $indicator."momentum"	=> {
	comment		=> "set zero total momentum in LAMMPS",
	default		=> ($flag->{momentum} ? join(",", @{$context->{momentum}}) : "false"),
	gui		=> ["list", "chemistry", "lammps", "advanced"]},

      # N

      $indicator."nsample"	=> {
	comment		=> "number of configuration in profile",
	default		=> $context->{nsample},
	gui		=> ["integer", "chemistry", "analysis", "standard"]},

      # P

      $indicator."pdamp"	=> {
	comment		=> "set LAMMPS barostat damping constant",
	default		=> $context->{pdamp},
	gui		=> ["real", "chemistry", "lammps", "advanced"]},
      $indicator."prefix"	=> {
	comment		=> "set project name as prefix to LAMMPS output files",
	default		=> EMC::Math::boolean($flag->{prefix}),
	gui		=> ["boolean", "chemistry", "lammps", "ignore"]},

      # S

      $indicator."skin"		=> {
	comment		=> "set LAMMPS skin",
	default		=> $context->{skin},
	gui		=> ["real", "chemistry", "lammps", "advanced"]},

      # T

      $indicator."tdamp"	=> {
	comment		=> "set LAMMPS thermostat damping constant",
	default		=> $context->{tdamp},
	gui		=> ["real", "chemistry", "lammps", "advanced"]},
      $indicator."tequil"	=> {
	comment		=> "set LAMMPS equilibration time",
	default		=> $context->{tequil},
	gui		=> ["integer", "chemistry", "lammps", "standard"]},
      $indicator."tfreq"	=> {
	comment		=> "set LAMMPS profile sampling frequency",
	default		=> $context->{tfreq},
	gui		=> ["integer", "chemistry", "lammps", "standard"]},
      $indicator."thermo_multi"	=> {
	comment		=> "set LAMMPS thermo style to multi",
	default		=> EMC::Math::boolean($flag->{multi}),
	gui		=> ["boolean", "chemistry", "lammps", "ignore"]},
      $indicator."triclinic"	=> {
	comment		=> "set LAMMPS triclinic mode",
	default		=> EMC::Math::boolean($flag->{triclinic}),
	gui		=> ["string", "chemistry", "lammps", "standard"]},
      $indicator."trun"	=> {
	comment		=> "set LAMMPS run time",
	default		=> $context->{trun},
	gui		=> ["string", "chemistry", "lammps", "standard"]},
    };

    foreach (keys(%{$commands})) {
      my $ptr = $commands->{$_};
      if (!defined($ptr->{set})) {
	$ptr->{original} = $pre.$_ if ($flag_depricated);
	$ptr->{comment} =~ s/LAMMPS //g if ($indicator ne "");
	$ptr->{comment} =~ s/in LAMMPS//g if ($indicator ne "");
	$ptr->{set} = \&EMC::LAMMPS::set_options;
      }
    }
    $lammps->{commands} = EMC::Common::attributes(
      $lammps->{commands}, $commands);
    last if ($indicator eq "" || !$depricated);
    $flag_depricated = 1;
    $indicator = "";
  }

  EMC::Options::set_command(
    $lammps->{items} = EMC::Common::attributes(
      EMC::Common::hash($lammps, "items"),
      {
	lammps		=> {
	}
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0,
      set		=> \&EMC::Script::set_item_verbatim
    }
  ); 

  return $lammps;
}


sub set_context {
  my $lammps = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($root, "global", "units");
  my $flag = EMC::Common::element($lammps, "flag");
  my $context = EMC::Common::element($lammps, "context");
  my $defined = EMC::Common::element($lammps, "defined");

  $context->{skin} = (
    $units->{type} eq "cgs" ? 0.1 :
    $units->{type} eq "lj" ? 0.3 :
    $units->{type} eq "metal" ? 2.0 :
    $units->{type} eq "real" ? ($field->{type} eq "colloid" ? 200.0 : 2.0) :
    $units->{type} eq "si" ? 0.001 : -1) if (!defined($defined->{skin}));
  if ($context->{skin}<0) {
    EMC::Message::error("undetermined LAMMPS skin.\n");
  }
  if ($flag->{write}>0) {
    $context->{version} = $context->{new_version} if ($flag->{write}>1);
    $context->{version} = $flag->{write} if ($flag->{write}>2000);
    $flag->{communicate} = $context->{version}<$context->{new_version} ? 1 : 0;
    $flag->{chunk} = $context->{version}<$context->{new_version} ? 0 : 1;
  }
  $context->{pdamp} = (
    $field->{type} eq "dpd" ? 10 :
    $field->{type} eq "gauss" ? 10 : 1000) if (!defined($defined->{pdamp}));
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $lammps = EMC::Common::element($struct, "module");
  my $global = EMC::Common::hash($root, "global");
  my $context = EMC::Common::hash($lammps, "context");
  my $flag = EMC::Common::hash($lammps, "flag");
  my $defined = EMC::Common::hash($lammps, "defined");
  my $set = EMC::Common::element($lammps, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "lammps_" : "";
  while (1) {
    
    # C
    
    if ($option eq $indicator."chunk") {
      return $flag->{chunk} = EMC::Math::flag($args->[0]); }
    if ($option eq $indicator."communicate") {
      return $flag->{communicate} = EMC::Math::flag($args->[0]); }
    if ($option eq "cut") {					# backwards
      $context->{cutoff} = 
	$global->{cutoff}->{repulsive} = $args->[0] eq "repulsive" ? 1 : 0;
      $global->{cutoff}->{pair} = EMC::Math::eval($args->[0])->[0] if (!$context->{cutoff});
      return $context->{cutoff}; }
    if ($option eq $indicator."cutoff") {
      return $context->{cutoff} = 
	$global->{cutoff}->{repulsive} = EMC::Math::flag($args->[0]); }

    # D
    
    if ($option eq $indicator."dlimit") {
      return $context->{dlimit} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq "dtdump") {					# backwards
      return $context->{dtdump} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."dtdump") {
      return $context->{dtdump} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq "dtrestart") {				# backwards
      return $context->{dtrestart} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."dtrestart") {
      return $context->{dtrestart} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq "dtthermo") {				# backwards
      return $context->{dtthermo} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."dtthermo") {
      return $context->{dtthermo} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."dump_box") {
      return $flag->{dump_box} = EMC::Math::flag($args->[0]); }
    
    # E
    
    if ($option eq $indicator."error") {
      return $context->{error} = EMC::Math::flag($args->[0]); }

    # L

    if ($option eq "lammps") {
      my $result = 0;
      my $value = EMC::Math::eval($args->[0])->[0];
      if ($args->[0] eq "old" ) {
	$result = $context->{new_version}-1; }
      elsif ($args->[0] eq "new") {
	$result = $context->{new_version}; }
      elsif ($args->[0] eq "newer") {
	$result = $context->{newer_version}; }
      elsif ($value>2000) {
	$result = $value; }
      else {
	$result = EMC::Math::flag($args->[0]); }
      if ($result) {
	EMC::MD::set_flags(EMC::Common::element($lammps, "parent"), "write", 0);
	$context->{version} = $result if ($result>2000);
      }
      return $flag->{write} = $result;
    }

    # M

    if ($option eq $indicator."momentum" || $option eq "momentum") {
      my $n = scalar(@{$args});
      $args->[0] = 0 if (EMC::Math::eval($args->[0])->[0]<0);
      if (($flag->{momentum} = EMC::Math::flag($args->[0]))) {
	if ($args->[0] ne "true") {
	  my $i; for ($i=0; $i<($n<4 ? $n : 4); ++$i) {
	    $context->{momentum}->[$i] = EMC::Math::eval($args->[$i])->[0]; }
	  if ($args->[4] eq "none" || $args->[4] eq "-") {
	    $context->{momentum}->[4] = "";
	  }
	}
      }
    }

    # N

    if ($option eq "nsample") {					# backwards
      return $context->{nsample} = int(EMC::Math::eval($args->[0])->[0]); }
    if ($option eq $indicator."nsample") {
      return $context->{nsample} = int(EMC::Math::eval($args->[0])->[0]); }

    # P

    if ($option eq $indicator."pdamp") {
      $defined->{pdamp} = 1;
      return $context->{pdamp} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq "prefix") {					# backwards
      return $flag->{prefix} = EMC::Math::flag($args->[0]); }
    if ($option eq $indicator."prefix") {
      return $flag->{prefix} = EMC::Math::flag($args->[0]); }

    # S

    if ($option eq "skin") {					# backwards
      $flag->{skin} = 1;
      return $context->{skin} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."skin") {
      $flag->{skin} = 1;
      return $context->{skin} = EMC::Math::eval($args->[0])->[0]; }

    # T

    if ($option eq "tdamp") {					# backwards
      $defined->{tdamp} = 1;
      return $context->{tdamp} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."tdamp") {
      $defined->{tdamp} = 1;
      return $context->{tdamp} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq "tequil") {					# backwards
      $defined->{tequil} = 1;
      return $context->{tequil} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq $indicator."tfreq") {
      $defined->{tfreq} = 1;
      return $context->{tfreq} = EMC::Math::eval($args->[0])->[0]; }
    if ($option eq "thermo_multi") {				# backwards
      return $flag->{multi} = EMC::Math::flag($args->[0]); }
    if ($option eq $indicator."thermo_multi") {
      return $flag->{multi} = EMC::Math::flag($args->[0]); }
    if ($option eq $indicator."trun") { 
      if (($flag->{trun} = $args->[0] eq "-" ? 0 : 1)) {
	my @s = @{$args};
	@s[0] = EMC::Math::eval(@s[0])->[0];
	$context->{trun} = scalar(@s)<2 ? @s[0] : "\"".join(" ", @s)."\"";
      }
      return $flag->{trun};
    }
    last if ($indicator eq "");
    $indicator = "";
  }
  return undef;
}


sub set_functions {
  my $lammps = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($lammps, "set");
  my $write = EMC::Common::hash($lammps, "write");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1, md => 1};

  $set->{commands} = \&EMC::LAMMPS::set_commands;
  $set->{context} = \&EMC::LAMMPS::set_context;
  $set->{defaults} = \&EMC::LAMMPS::set_defaults;
  $set->{options} = \&EMC::LAMMPS::set_options;

  $write->{emc} = \&EMC::LAMMPS::write_emc;
  $write->{job} = \&EMC::LAMMPS::write_job;
  $write->{script} = \&EMC::LAMMPS::write_script;

  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $lammps;
}


# LAMMPS script

sub pressure_coupling {				# <= lammps_pressure_coupling
  my $global = shift(@_);
  my $pressure = EMC::Common::hash($global, "pressure");
  my @couple = split(":", $pressure->{couple});
  my @direction = split("[+]", $pressure->{direction});
  my $string;
  my $mode;

  if (scalar(@couple)==1 && scalar(@direction)==3) {
    if (@couple[0] eq "couple") { 
      $mode = "iso";
    }
    elsif (@couple[0] eq "uncouple") {
      $mode = $global->{flag}->{triclinic} ? "tri" : "aniso";
    }
    $string .= "\n\t\t$mode \${pressure} \${pressure} \${pdamp}";
  }
  else
  {
    my %d = (x => 0, y => 0, z => 0);
    my @dir = split("[+]", @couple[1]);
    foreach(@direction) { $d{$_} = 1; }
    @direction = (); foreach (sort(keys(%d))) {
      $string .= "\n\t\t$_ \${pressure} \${pressure} \${pdamp} &" if ($d{$_});
      push(@direction, $_) if ($d{$_});
    }
    @dir = @direction if (!scalar(@dir));
    if (@couple[0] eq "couple") {
      %d = (x => 0, y => 0, z => 0);
      foreach (@dir) { $d{$_} = 1; }
    } else {
      %d = (x => 1, y => 1, z => 1);
      foreach (@dir) { $d{$_} = 0; }
    }
    @dir = (); foreach (sort(keys(%d))) { push(@dir, $_) if ($d{$_}); }
    $string .= "\n\t\tcouple ".(scalar(@dir)>1 ? join("", @dir) : "none");
  }
  return $string;
}


sub write_script {				# <= write_lammps
  my $root = shift(@_);
  my $name = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $lammps = EMC::Common::element($root, "md", "lammps");
  my $flag = EMC::Common::element($lammps, "flag");

  return if (!defined($flag) || !$flag->{write});

  if ((-e "$name.in")&&!$global->{replace}->{flag}) {
    EMC::Message::warning(
      "\"$name.in\" exists; use -replace flag to overwrite\n");
    return;
  }

  EMC::Message::info("creating LAMMPS input script \"$name.in\"\n");

  my $stream = EMC::IO::open("$name.in", "w");
  my $stage = [
    "header", "variables", "interaction", "equilibration", "simulation",
    "integration", "integrator", "sampling", "intermediate", "run"
  ];
  my $write = {
    header		=> \&write_header,
    variables		=> \&write_variables,
    interaction		=> \&write_interaction,
    equilibration 	=> \&write_equilibration,
    simulation		=> \&write_simulation,
    integration		=> \&write_integrator,
    integrator		=> \&write_integrator,
    sampling		=> \&write_sample,
    intermediate 	=> \&write_intermediate,
    run			=> \&write_footer
  };

  foreach (@{$stage}) {
    next if ($_ eq "integration");		# backwards compatibility
    write_verbatim($stream, $lammps, $_, "head");
    $write->{$_}->($stream, $root);
    write_verbatim($stream, $lammps, $_, "tail");
  }

  EMC::IO::close($stream);
}


sub write_verbatim {				# <= write_lammps_verbatim
  my ($stream, $lammps, $stage, $spot) = @_[0..3];
  my $verbatim = EMC::Common::element($lammps, "verbatim");
  my $data = EMC::Common::element($verbatim, $stage, $spot, "data");

  if ($data) {
    EMC::Message::info("adding verbatim lammps $spot paragraph at $stage\n");
    printf($stream "# Verbatim paragraph\n\n%s\n\n", join("\n", @{$data}));
  }
}


sub write_header {				# <= write_lammps_header
  my $stream = shift(@_);
  my $root = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $context = EMC::Common::element($root, "md", "lammps", "context");
  my $flag = EMC::Common::element($root, "md", "lammps", "flag");

  my $identity = EMC::Common::element($global, "identity");
  my $field = EMC::Common::element($root, "fields", "field");
  my $date = EMC::Common::date_full();
  my $atom_style = (
    $field->{type} eq "colloid" ? "sphere\nnewton\t\toff" :
    $field->{type} eq "dpd" ? ("hybrid molecular".
      ($global->{flag}->{charge} ? " charge" : "")) :   
    $global->{flag}->{charge} ? "full" : "molecular");
  my $units = $global->{units}->{type} eq "reduced" ? "lj" : $global->{units}->{type};

  printf($stream "%s",
"# LAMMPS input script for standardized atomistic simulations
# Created by $identity->{script} v$identity->{version}, $identity->{date} as part of EMC
# on $date

# LAMMPS atomistic input script

echo		screen
units		$units
atom_style	$atom_style

");
}


sub write_variable {
  my $stream = shift(@_);
  my $spacer = "";
  my $quote = 0;
  my @arg;
  my @a;
  
  foreach (split(" ", shift(@_))) {
    if (length($_)>1 && substr($_,0,1) eq '"' && substr($_,-1,1) eq '"') {
      push(@arg, $_);
    } elsif ($quote) {
      push(@a, $_);
      if (substr($_,-1,1) eq '"') {
	push(@arg, join(" ", @a));
	$quote = 0;
	@a = ();
      }
    } elsif (substr($_,0,1) eq '"') {
      $quote = 1;
      @a = ($_);
    } else {
      push(@arg, $_);
    }
  }
  foreach (2, 2, 1, 2) {
    my $v = shift(@arg);
    my $n = $_-int(length($v)/8);

    printf($stream $spacer."%s", $v);
    $spacer = $n==2 ? "\t\t" : $n==1 ? "\t" : " ";
  }
  printf($stream $spacer."%s", join(" ", @arg)) if (scalar(@arg));
  printf($stream "\n");
}


sub write_variables {				# <= write_lammps_variables
  my $stream = shift(@_);
  my $root = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $context = EMC::Common::element($root, "md", "lammps", "context");
  my $timestep =  EMC::Common::element($root, "md", "context", "timestep");
  my $emc = EMC::Common::element($root, "emc", "context");
  my $flag = EMC::Common::element($root, "md", "lammps", "flag");
  my $seed = [0,0,0];

  foreach (@{$seed}) {
    my $v = 0;
    do { $v = int(rand(1e8)); } while ($v<1e7);
    $_ = $v;
  }

  printf($stream "# Variable definitions\n\n");
  foreach (split("\n",  
"variable	project		index	\"$global->{project}->{name}\"		# project name
variable	source		index	$emc->{build}->{dir}	# data directory
variable	temperature	index	$global->{temperature}		# system temperature
variable	tdamp		index	$context->{tdamp}		# temperature damping"
.($global->{pressure}->{flag} ? "
variable	pressure	index	$global->{pressure}->{value}		# system pressure
variable	pdamp		index	$context->{pdamp}		# pressure damping" : "")
.($global->{shear}->{flag} ? "
variable	rate		index	$global->{shear}->{rate}		# shear rate
variable	tramp		index	$global->{shear}->{ramp}		# shear ramp
variable	framp		index	".($global->{shear}->{mode} ? 1 : 0).
"\t\t# 0: skip, 1: apply" :
 "")."
variable	dielectric	index	$global->{dielectric}		# medium dielectric
variable	kappa		index	$global->{kappa}		# electrostatics kappa
variable	cutoff		index	$global->{cutoff}->{pair}		# standard cutoff"
.($global->{cutoff}->{ghost}>=0 ? "
variable	ghost_cutoff	index	$global->{cutoff}->{ghost}		# ghost region cutoff" : "")
.($global->{cutoff}->{center}>=0 ? "
variable	center_cutoff	index	$global->{cutoff}->{center}		# center cutoff" : "")
.($global->{cutoff}->{inner}>=0 ? "
variable	inner_cutoff	index	$global->{cutoff}->{inner}		# inner cutoff" : "")."
variable	charge_cutoff	index	$global->{cutoff}->{charge}		# charge cutoff
variable	precision	index	$global->{precision}		# kspace precision
variable	lseed		index	$seed->[0]	# langevin seed
variable	vseed		index	$seed->[1]	# velocity seed"
.($field->{type} eq "colloid" ? "
variable	bseed		index	$seed->[2]	# brownian seed" : "")."
variable	tequil		index	$context->{tequil}		# equilibration time
variable	dlimit		index	$context->{dlimit}		# nve/limit distance
variable	trun		index	$context->{trun}	# run time
variable	frestart	index	".($global->{md}->{restart} ? 1 : 0)
."		# 0: equil, 1: restart
variable	dtrestart	index	$context->{dtrestart}		# delta restart time
variable	dtdump		index	$context->{dtdump}		# delta dump time
variable	dtthermo	index	$context->{dtthermo}		# delta thermo time
variable	timestep	index	$timestep		# integration time step
variable	tfreq		index	$context->{tfreq}		# profile sampling freq
variable	nsample		index	$context->{nsample}		# profile conf sampling
variable	dtime		equal	\${tfreq}*\${nsample}	# profile dtime
variable	restart		index	\${project}.restart
")) {
    write_variable($stream, $_);
  }

  if ($field->{type} eq "charmm") {
    if ($context->{version}<$context->{newer_version}) {
      EMC::IO::touch("$global->{project}->{name}.cmap");
    } else {
      write_variable($stream,
	"variable\tfcmap\tequal\tis_file(\${source}/\${project}.cmap)");
    }
  }
  printf($stream "
if \"\${frestart} != 0\" then &
\"variable	data		index	\${restart}\" &
else &
\"variable	data		index	\${source}/\${project}.data\"

");
}


sub write_interaction {				# <= write_lammps_interaction
  my $stream = shift(@_);
  my $root = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $context = EMC::Common::element($root, "md", "lammps", "context");
  my $flag = EMC::Common::element($root, "md", "lammps", "flag");

  my $special_bonds = (
    $field->{type} eq "cff" ? "0 0 1" :
    $field->{type} eq "dpd" ? "1 1 1" :
    $field->{type} eq "martini" ? "0 1 1" :
    $field->{type} eq "opls" ? "0 0 0.5" : 
    $field->{type} eq "sdk" ? "0 0 1" :
    $field->{type} eq "colloid" ? "1 1 1" :
    "0 0 0");
  my $cut = "\${cutoff}";
  my $icut = "\${inner_cutoff}";
  my $zcut = "\${center_cutoff}";
  my $ccut = "\${charge_cutoff}";
  my $long = $global->{flag}->{ewald} ? "long" : "cut";
  my @momentum = @{$context->{momentum}};
  my $fcmap = $context->{version}<$context->{newer_version} ? 0 : 1;
  my $pair_style = (
    $field->{type} eq "colloid" ? "colloid $cut" :
    $field->{type} eq "dpd" ? (
      ($global->{flag}->{charge} ?
	"hybrid/overlay &\n\t\tdpd/charge \${charge_cutoff} \${kappa} &\n\t\t":
	"").
      "dpd \${temperature} \${cutoff} \${vseed}") :
    $field->{type} eq "charmm" ?
      ($global->{flag}->{charge} ? 
	"lj/charmm/coul/$long $icut $cut $ccut" : "lj/charmm $cut")."\n\n".
      ($fcmap ?
	"if \"\${fcmap}\" then &\n".
	"\"fix\t\tcmap all cmap \${source}/\${project}.cmap\" &\n".
	"\"fix_modify\tcmap energy yes\"\n" : 
	"fix\t\tcmap all cmap \${source}/\${project}.cmap\n".
	"fix_modify\tcmap energy yes\n") :
    $field->{type} eq "cff" ? 
      ($global->{flag}->{charge} ? 
	"lj/class2/coul/$long $cut $ccut" : "lj/class2 $cut") :
    $field->{type} eq "sdk" ? 
      ($global->{flag}->{charge} ? "lj/sdk/coul/$long $cut $ccut" : "lj/sdk $cut") :
    $field->{type} eq "martini" ?
      ($global->{flag}->{charge} ? "lj/gromacs/coul/gromacs $icut $cut &\n\t\t$zcut $ccut" : 
		     "lj/gromacs $icut $cut") :
      ($global->{flag}->{charge} ? "lj/cut/coul/$long $cut $ccut" : "lj/cut $cut"));

  my $neighbor = ($context->{version}<$context->{newer_version} ? "multi" : "multi/old");

  printf($stream "%s",
"# Interaction potential definition

pair_style	$pair_style
".($field->{type} ne "colloid" ? "bond_style\tharmonic\n" : "").
($field->{type} eq "sdk" ? "angle_style\tsdk\n" : "").
"special_bonds	lj/coul $special_bonds".
($global->{flag}->{triclinic} ? "
box		tilt large" : "")."\n
if \"\${frestart} != 0\" then \"read_restart \${data}\" &".
($field->{type} eq "charmm" ? 
  ($fcmap ? "\nelif \"\${fcmap}\" then " : "\nelse ").
  "\"read_data \${data} fix cmap crossterm CMAP\"".
  ($fcmap ? " &\nelse \"read_data \${data}\"\n" : "\n") : 
  "\nelse \"read_data \${data}\"\n").
($global->{shear}->{flag}||$global->{flag}->{triclinic} ? "
if \"\${frestart} == 0\" then \"change_box all triclinic\"" : "")."
include		\${source}/\${project}.params

# Integration conditions (check)
".($field->{type} eq "dpd" ? "
neighbor	$context->{skin} $neighbor
".($flag->{communicate} ? "communicate	" : "comm_modify	mode ").
		"single vel yes cutoff \${ghost_cutoff}
neigh_modify	delay 0 every 2 check yes" : "")."
timestep	\${timestep}\n".
($global->{flag}->{charge} ?
  ($field->{type} ne "martini" ? 
    ($global->{flag}->{ewald} ? "if \"\${flag_charged} != 0\" then \"kspace_style pppm/cg \${precision}\"\n" : "") : "").
      "dielectric\t\${dielectric}\n" : "").
($flag->{momentum} ? join(" ", "fix\t\tmom all momentum", shift(@momentum), "linear", @momentum) : "")
.($field->{type} eq "colloid" ? "
neighbor	$context->{skin} $neighbor
neigh_modify	delay 0 every 1 check yes
neigh_modify	include all
comm_modify	mode $neighbor vel yes" : "")."

");
}


sub write_equilibration {			# <= write_lammps_equilibration
  my $stream = shift(@_);
  my $root = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $context = EMC::Common::element($root, "md", "lammps", "context");
  my $flag = EMC::Common::element($root, "md", "lammps", "flag");
  my $shake = EMC::Common::element($root, "md", "context", "shake");

  printf($stream "%s",
"# Equilibration
".
($flag->{multi} ? "\nthermo_style\tmulti" : "")."
thermo		\${dtthermo}
if \"\${frestart} != 0\" then \"jump SELF simulate\"\n".
($shake->{flag} ? "timestep\t1\nunfix\t\tshake\n" : "").
"velocity	all create \${temperature} \${vseed} &
		dist gaussian rot yes mom yes sum yes
".($field->{type} eq "dpd" ? "" :
  "fix\t\ttemp all langevin \${temperature} \${temperature} \${tdamp} &\n\t\t\${lseed}\n").
"fix		int all nve/limit \${dlimit}
run		\${tequil}
".($field->{type} eq "dpd" ? "" :
"unfix		temp\n").
"unfix		int
write_restart	\${project}.restart2

");
}


sub write_simulation {				# <= write_lammps_simulation
  my $stream = shift(@_);
  my $root = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $context = EMC::Common::element($root, "md", "lammps", "context");
  my $flag = EMC::Common::element($root, "md", "lammps", "flag");

  printf($stream "%s",
"# Simulation

label		simulate

"
);
}


sub write_shake {				# <= write_lammps_shake
  my $shake = shift(@_);
  my $command = undef;
  
  if (defined($shake->{flag}) ? $shake->{flag} ? 0 : 1 : 0) {
    $command = "shake all shake ";
    $command .= "$shake->{tolerance} $shake->{iterations} $shake->{output}";
    my $index = 1;
    my $offset = 16;
    my $column = $offset+length($command);
    my %key = (mass => "m", type => "t", bond => "b", angle => "a");

    foreach ("mass", "type", "bond", "angle") {
      if (defined($shake->{$_})) {
	my $ptr = $shake->{$_};
	my $flag = $_ eq "mass" ? 0 : 1;
	my $pre = "type"; $pre .= "_$_" if ($_ ne "type");

	$command .= " &\n\t\t$key{$_}";
	$column = $offset+length($key{$_});
	foreach (@{$ptr}) {
	  my $type = $flag ? "\${".join("_", $pre, @{$_})."}" : @{$_}[0];
	  my $n = length($type);
	  
	  if ($column+$n>77) {
	    $command .= " &\n\t\t$type"; $column = $offset+$n;
	  } else {
	    $command .= " $type"; $column += $n+1;
	  }
	}
      }
    }
    $command = "\nfix\t\t$command";
  }
  return $command;
}


sub write_integrator {				# <= write_lammps_integrator
  my $stream = shift(@_);
  my $root = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $context = EMC::Common::element($root, "md", "lammps", "context");
  my $flag = EMC::Common::element($root, "md", "lammps", "flag");
  my $shear_mode = $global->{shear}->{mode} eq "" ? "erate" : $global->{shear}->{mode};
  my $shake = write_shake(
     EMC::Common::element($root, "md", "context", "shake"));

  printf($stream "%s",
"# Integrator
".
($global->{flag}->{shake} ? "
timestep	\${timestep}\ninclude\t\t\${source}/\${project}.params\n" : "").
$shake.($field->{type} eq "dpd" ? 
  ($global->{pressure}->{flag} ?  "
fix		press all press/berendsen &".pressure_coupling($global) : "")."
fix		int all nve" :
  ($global->{shear}->{flag} ? 
  ($global->{pressure}->{flag} ?
  ($field->{type} eq "colloid" ? "
fix		press all press/berendsen &".pressure_coupling($global) : " 	
fix		int all npt/sllod temp \${temperature} \${temperature} \${tdamp} &".pressure_coupling($global)) : 
  ($field->{type} eq "colloid" ? "
fix		int all nve/noforce" : "
fix		int all nvt/sllod \${temperature} \${temperature} \${tdamp}"))."

if \"(\${frestart} != 0) || (\${framp} == 0)\" then \"jump SELF deform\"
fix		def all deform 1 xy $shear_mode \${rate} remap v
run		\${tramp}
unfix		def

label		deform
fix		def all deform 1 xy erate \${rate} remap v" : 
  ($global->{pressure}->{flag} ? " 
fix		int all npt temp \${temperature} \${temperature} \${tdamp} &".pressure_coupling($global) : "
fix		temp all langevin \${temperature} \${temperature} \${tdamp} &\n\t\t\${lseed}
fix		int all nve")))."\n\n"
);
}


sub write_sample {				# <= write_lammps_sample
  my $stream = shift(@_);
  my $root = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $analyze = EMC::Common::element($root, "analyze", "context");
  my $context = EMC::Common::element($root, "md", "lammps", "context");
  my $flag = EMC::Common::element($root, "md", "lammps", "flag");
  my $units = $global->{units}->{type} eq "reduced" ? "lj" : $global->{units}->{type};

  $analyze->{sample}->{volume} = 1 if ($analyze->{sample}->{"green-kubo"});
  foreach(sort(keys(%{$analyze->{sample}}))) {
    my $key = $_;
    next if ($key eq "flag" || $key eq "msd" || $key eq "gyration");
    next if (!$analyze->{sample}->{$key});
    EMC::Message::info("adding $key sampling\n");
    printf($stream "# System sampling: $key\n");
    if ($key eq "energy") {
      printf($stream "
variable	pe equal pe
variable	ke equal ke
variable	etotal equal etotal
variable	enthalpy equal enthalpy
variable	evdwl equal evdwl
variable	ecoul equal ecoul
variable	epair equal epair
variable	ebond equal ebond
variable	eangle equal eangle
variable	edihed equal edihed
variable	eimp equal eimp
variable	emol equal emol
variable	elong equal elong
variable	etail equal etail

fix		ene all ave/time \${tfreq} \${nsample} \${dtime} &
		c_thermo_temp &
	       	v_pe v_ke v_etotal v_enthalpy v_evdwl &
		v_ecoul v_epair v_ebond v_eangle v_edihed v_eimp &
		v_emol v_elong v_etail &
		file \${project}.energy

");
    }
    elsif ($key eq "pressure") {
      printf($stream "
fix		sample_press all ave/time \${tfreq} \${nsample} \${dtime} &
		c_thermo_temp &
		c_thermo_press[1] c_thermo_press[2] c_thermo_press[3] &
		c_thermo_press[4] c_thermo_press[5] c_thermo_press[6] &
		file \${project}.pressure

");
    }
    elsif ($key eq "volume") {
      printf($stream "
variable	volume equal vol
variable	hxx equal lx
variable	hyy equal ly
variable	hzz equal lz
variable	hxy equal xy
variable	hxz equal xz
variable	hyz equal yz

fix		vol all ave/time \${tfreq} \${nsample} \${dtime} &
		v_volume v_hxx v_hyy v_hzz v_hyz v_hxz v_hxy &
		file \${project}.volume

");
    }
    elsif ($key eq "green-kubo") {
      my ($kB, $atm2Pa, $A2m, $fs2s) = 
	$units eq "real" ? (
	  "1.3806504e-23	# [J/K Boltzmann]",
	  "101325.0	# [Atmosphere to Pa]",
	  "1.0e-10		# [A to m]",
	  "1.0e-15		# [fs to s]"
	) : $units eq "si" ? (
	  "1.3806504e-23	# [J/K Boltzmann]",
	  "1		# [Pa to Pa]",
	  "1		# [m to m]",
	  "1		# [s to s]",
	) : (1, 1, 1, 1);

      printf($stream "
variable	kB		equal	$kB
variable	atm2Pa		equal	$atm2Pa
variable	A2m		equal	$A2m
variable	fs2s		equal	$fs2s
variable	volume		equal	vol

variable	convert 	equal	\${atm2Pa}*\${atm2Pa}*\${fs2s}*\${A2m}*\${A2m}*\${A2m}

fix		cnu all ave/correlate \${tfreq} \${nsample} \${dtime} &
		c_thermo_press[4] c_thermo_press[5] c_thermo_press[6]
fix		anu all ave/correlate \${tfreq} \${nsample} \${dtime} &
		c_thermo_press[4] c_thermo_press[5] c_thermo_press[6] ave running

variable	scale		equal	\${convert}/(\${kB}*\${temperature})*\${volume}*\${tfreq}*\${timestep}*1000

variable	nu_xy		equal	trap(f_cnu[3])*\${scale}
variable	nu_xz		equal	trap(f_cnu[4])*\${scale}
variable	nu_yz		equal	trap(f_cnu[5])*\${scale}
variable	nu		equal	(v_nu_xy+v_nu_xz+v_nu_yz)/3.0

variable	anu1		equal	trap(f_anu[3])*\${scale}
variable	anu2		equal	trap(f_anu[4])*\${scale}
variable	anu3		equal	trap(f_anu[5])*\${scale}
variable	nu_avg		equal	(v_anu1+v_anu2+v_anu3)/3.0

fix		nu all ave/time \${dtime} 1 \${dtime} &
		v_nu_avg v_nu v_nu_xy v_nu_xz v_nu_yz title1 &
		\"# Time-averaged data: Green-Kubo viscosity in ".(
		$units eq "reduced" ? "reduced units" : "[mPa s]")."\" &
		file \${project}.green-kubo

thermo_style	custom step temp c_thermo_temp pe ke press c_thermo_press vol

");
    }
  }
}


sub write_intermediate {			# <= write_lammps_intermediate
  my $stream = shift(@_);
  my $root = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $profiles = EMC::Common::element($root, "global", "profiles");
  my $context = EMC::Common::element($root, "md", "lammps", "context");
  my $flag = EMC::Common::element($root, "md", "lammps", "flag");
  my $clusters = EMC::Common::element($root, "emc", "clusters");
  my $sample = EMC::Common::element($root, "analyze", "context", "sample");

  #EMC::Message::dumper("profiles = ", $profiles);

  return if (!(defined($profiles)||
		       $profiles->{flag}->{flag}||
	       	       $sample->{gyration}||
		       $sample->{msd}));
  
  my $binsize = $global->{binsize};
  my $x = $global->{direction}->{x};
  my $g = "profile";
  my $offset = 4;
  my $i;
  my $l;

  if ($sample->{msd}) {
    EMC::Message::info("adding msd analysis\n");
  }
  if (defined($profiles)||$profiles->{flag}->{flag}) {
    EMC::Message::info("adding profile analysis\n");
  }
  if ($profiles->{flag}->{flag}||$sample->{msd}||
      $sample->{gyration}) {
    my $dim = {"1d" => 0, "2d" => 0, "3d" => 0, msd => 0, gyration => 0};
    $dim->{"1d"} = ($profiles->{flag}->{density}||$profiles->{flag}->{pressure});
    $dim->{"3d"} = ($profiles->{flag}->{density3d});
    $dim->{"msd"} = ($sample->{msd});
    $dim->{"gyration"} = ($sample->{gyration});
    if ($profiles->{flag}->{pressure}) {
      if (!$flag->{chunk}) {
	EMC::Message::error("Pressure profiles can only be used in combination with LAMMPS chunks\n");
      }
      my $m = "all"; $g = $m;
      my $name = ($flag->{prefix} ? $global->{project}->{name}."_" : "").$m;
      printf($stream "# Cluster sampling: $m\n\n");
      printf($stream "compute\t\tchunk_$m $g chunk/atom bin/1d $x 0.0 $binsize units reduced\n");
      printf($stream "compute\t\tpress_$m $g stress/atom NULL\n");
      printf($stream "fix\t\tpress_$m $g ave/chunk &\n");
      printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
      printf($stream "\t\tc_press_$m\[1] c_press_$m\[2] c_press_$m\[3] &\n");
      printf($stream "\t\tc_press_$m\[4] c_press_$m\[5] c_press_$m\[6] &\n");
      printf($stream "\t\tfile $name.pressure\n\n");
    }
    printf($stream "# Cluster sampling: init\n\nvariable\tin\tequal\t0\n\n")
      if (scalar(@{$clusters->{sampling}}));
    for ($i=0; $i<scalar(@{$clusters->{sampling}}); ++$i) {
      my $m = $clusters->{sampling}->[$i]; $g = $m;
      my $name = ($flag->{prefix} ? $global->{project}->{name}."_" : "").$m;
      
      printf($stream "# Cluster sampling: $m\n\n");
      printf($stream "variable\ti0\tequal\t\${in}+1\n");
      printf($stream "variable\tin\tequal\t\${in}+\${nl_$m}\n");
      printf($stream "group\t\t$g\tmolecule <>\t\${i0}\t\${in}\n\n");
      if ($flag->{chunk}) {
	if ($dim->{"1d"}) {
	  printf($stream "compute\t\tchunk_1d_$m $g chunk/atom bin/1d &\n\t\t$x 0.0 $binsize units reduced\n"); }
	if ($dim->{"3d"}) {
	  printf($stream "compute\t\tchunk_3d_$m $g chunk/atom bin/3d &\n\t\tx 0.0 $binsize y 0.0 $binsize z 0.0 $binsize units reduced\n"); }
	if ($profiles->{flag}->{pressure}) {
	  printf($stream "compute\t\tpress_$m $g stress/atom NULL\n");
	}
	if ($dim->{"msd"}) {
	  my $ave = $dim->{"msd"}==2 ? "/ave" : "";
	  printf($stream "compute\t\tchunk_msd_$m $g chunk/atom molecule\n");
	  printf($stream "compute\t\tmsd_$m $g msd/chunk$ave chunk_msd_$m\n");
	}
	if ($dim->{"gyration"}) {
	  printf($stream "compute\t\tchunk_gyration_$m $g chunk/atom molecule\n");
	  printf($stream "compute\t\tgyration_$m $g gyration/chunk chunk_gyration_$m\n");
	}
      } elsif ($dim->{"3d"}) {
	EMC::Message::error("3D profiles can only be used in combination with LAMMPS chunks\n");
      } elsif ($dim->{"msd"}) {
	printf($stream "compute\t\tmsd_$m $g msd/molecule\n");
      } elsif ($dim->{"gyration"}) {
	EMC::Message::error("gyration can only be used in combination with LAMMPS chunks\n");
      }
      if ($profiles->{flag}->{density}) {
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	if ($flag->{chunk}) {
	  printf($stream "\"fix\t\tdens_1d_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_1d_$m &\n");
	  printf($stream "\t\tdensity/mass file $name.density\"\n");
	} else {
	  printf($stream "\"fix\t\tdens_$m $g ave/spatial &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} $x 0.0 $binsize &\n");
	  printf($stream "\t\tdensity/mass file $name.density units reduced\"\n");
	}
      }
      if ($profiles->{flag}->{density3d}) {
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	printf($stream "\"fix\t\tdens_3d_$m $g ave/chunk &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_3d_$m &\n");
	printf($stream "\t\tdensity/mass file $name.density3d\"\n");
      }
      if ($profiles->{flag}->{pressure}) {
	if (!$flag->{chunk}) {
	  EMC::Message::error("Pressure profiles can only be used in combination with LAMMPS chunks\n");
	}
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	printf($stream "\"fix\t\tpress_1d_$m $g ave/chunk &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_1d_$m &\n");
	printf($stream "\t\tc_press_$m\[1] c_press_$m\[2] c_press_$m\[3] &\n");
	printf($stream "\t\tc_press_$m\[4] c_press_$m\[5] c_press_$m\[6] &\n");
	printf($stream "\t\tfile $name.pressure\"\n");
      }
      if ($sample->{msd}) {
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	printf($stream "\"fix\t\tmsd_$m $g ave/time &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} &\n");
	printf($stream "\t\tc_msd_$m\[*\] mode vector file $name.msd\"\n");
      }
      if ($sample->{gyration}) {
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	printf($stream "\"fix\t\tgyration_$m $g ave/time &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} &\n");
	printf($stream "\t\tc_gyration_$m mode vector file $name.gyration\"\n");
      }
      #printf($stream "group\t\t$g\tdelete\n");
      printf($stream "\n");
      $l = $m;
    }
  }
  if (defined($profiles->{type})) {
    foreach (sort(keys %{$profiles->{type}})) {
      my $index = 1;
      my $m = $_; $g = $m;
      my $name = ($flag->{prefix} ? $global->{project}->{name}."_" : "").$m;
      my @a = @{${$profiles->{type}}{$m}};
      my $type = shift(@a);
      my $binsize = shift(@a);
      
      printf($stream "# Profile sampling: $m\n\n");
      print($stream "group\t\t$g\ttype");
      foreach (sort(@a)) {
	#printf($stream " \${type_".convert_key("type", $_)."}");
	printf($stream " \${type_$_}");
      }
      printf($stream "\n");
      if ($flag->{chunk}) {
	if ($type eq "density" || $type eq "pressure") {
	  printf($stream "compute\t\tchunk_$m $g chunk/atom bin/1d $x 0.0 $binsize units reduced\n");
	} elsif ($type eq "density3d") {
	  printf($stream "compute\t\tchunk_".$m."_3d $g chunk/atom bin/3d &\n\t\tx 0.0 $binsize y 0.0 $binsize z 0.0 $binsize units reduced\n");
	}
	if ($type eq "density") {
	  printf($stream "fix\t\tdens_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
	  printf($stream "\t\tdensity/mass file $name.density\n");
	} elsif ($type eq "density3d") {
	  printf($stream "fix\t\tdens_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_".$m."_3d &\n");
	  printf($stream "\t\tdensity/mass file $name.density3d\n");
	} elsif ($type eq "pressure") {
	  printf($stream "compute\t\tpress_$m $g stress/atom NULL\n");
	  printf($stream "fix\t\tpress_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
	  printf($stream "\t\tc_press_$m\[1] c_press_$m\[2] c_press_$m\[3] &\n");
	  printf($stream "\t\tc_press_$m\[4] c_press_$m\[5] c_press_$m\[6] &\n");
	  printf($stream "\t\tfile $name.pressure\n");
	}
      } else {
	printf($stream "\"fix\t\tdens_$m $g ave/spatial &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} $x 0.0 $binsize &\n");
	printf($stream "\t\tdensity/mass file $name.density units reduced\n");
      }
      #printf($stream "group\t\t$g\tdelete\n");
      printf($stream "\n");
    }
  }
  if (defined($profiles->{cluster})) {
    foreach (sort(keys %{$profiles->{cluster}})) {
      my $m = $_; $g = $m;
      my $name = ($flag->{prefix} ? $global->{project}->{name}."_" : "").$m;
      my @arg = @{${$profiles->{cluster}}{$m}};
      my $type = shift(@arg);
      my $binsize = shift(@arg);
      my $t = shift(@arg);
      
      printf($stream "# Profile sampling: $m\n\n");
      printf($stream "group\t\t$g\tmolecule <>\t\${n0_$t}\t\${n1_$t}\n");
      foreach (@arg) {
	if (0) {
	  printf($stream "group\t\ttmp0\tmolecule <>\t\${n0_$_}\t\${n1_$_}\n");
	  printf($stream "group\t\ttmp1\tunion\ttmp0\t$m\n");
	  printf($stream "group\t\ttmp0\tdelete\n");
	  printf($stream "group\t\t$g\tdelete\n");
	  printf($stream "group\t\t$g\tunion\ttmp1\n");
	  printf($stream "group\t\ttmp1\tdelete\n");
	} else {
	  printf($stream "group\t\ttmp\tmolecule <>\t\${n0_$_}\t\${n1_$_}\n");
	  printf($stream "group\t\t$g\tunion\t$g\ttmp\n");
	  printf($stream "group\t\ttmp\tdelete\n");
	}
      }
      if ($flag->{chunk}) {
	if ($type eq "density" || $type eq "pressure") {
	  printf($stream "compute\t\tchunk_$m $g chunk/atom bin/1d $x 0.0 $binsize units reduced\n");
	} elsif ($type eq "density3d") {
	  printf($stream "compute\t\tchunk_".$m."_3d $g chunk/atom bin/3d &\n\t\tx 0.0 $binsize y 0.0 $binsize z 0.0 $binsize units reduced\n");
	}
	if ($type eq "density") {
	  printf($stream "fix\t\tdens_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
	  printf($stream "\t\tdensity/mass file $name.density\n");
	} elsif ($type eq "density3d") {
	  printf($stream "fix\t\tdens_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_".$m."_3d &\n");
	  printf($stream "\t\tdensity/mass file $name.density3d\n");
	} elsif ($type eq "pressure") {
	  printf($stream "compute\t\tpress_$m $g stress/atom NULL\n");
	  printf($stream "fix\t\tpress_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
	  printf($stream "\t\tc_press_$m\[1] c_press_$m\[2] c_press_$m\[3] &\n");
	  printf($stream "\t\tc_press_$m\[4] c_press_$m\[5] c_press_$m\[6] &\n");
	  printf($stream "\t\tfile $name.pressure\n");
	}
      } else {
	printf($stream "\"fix\t\tdens_$m $g ave/spatial &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} $x 0.0 $binsize &\n");
	printf($stream "\t\tdensity/mass file $name.density units reduced\n");
      }
      #printf($stream "group\t\t$g\tdelete\n");
      printf($stream "\n");
    }
  }
}


sub write_footer {				# <= write_lammps_footer
  my $stream = shift(@_);
  my $root = shift(@_);
  my $flag = EMC::Common::element($root, "md", "lammps", "flag");
  my $box = $flag->{dump_box} ? " ix iy iz" : "";

  printf($stream
"# Run conditions

restart		\${dtrestart} \${project}.restart1 \${project}.restart2
dump		1 all custom \${dtdump} \${project}.dump id type x y z$box
run		\${trun}

");
}


# EMC script additions

sub write_emc {
  my $lammps = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $emc_flag = EMC::Common::element($root, "emc", "flag");
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $context = EMC::Common::element($lammps, "context");
  my $flag = EMC::Common::element($lammps, "flag");
  my $md = EMC::Common::element($lammps, "parent");

  # return if ($emc_flag->{test});
  return if (!(defined($flag) && $flag->{write}));
  return if ($emc_flag->{exclude}->{build});

  printf($stream "\nlammps\t\t= {name -> output, mode -> put, ".
    "forcefield -> $field->{type},\n");
  printf($stream
    "\t\t   parameters -> true, types -> false, unwrap -> true,\n");
  printf($stream
    "\t\t   charges -> %s", EMC::Math::boolean($global->{flag}->{charge}));
  printf($stream
    "%s", $global->{cutoff}->{repulsive} ? ", cutoff -> true" : "");
  printf($stream
    "%s", $global->{flag}->{ewald}>=0 ? ", ewald -> ".EMC::Math::boolean($global->{flag}->{ewald}) : "");
  printf($stream
    "%s", $global->{flag}->{cross} ? ", cross -> true" : "");
  printf($stream
    "%s", $field->{type} eq "colloid" ? ", sphere -> true" : "");
  if (defined($md->{shake}->{flag})) {
    printf($stream ", shake -> false") if (!$md->{shake}->{flag});
  }
  if ($emc_flag->{test}) {
    printf($stream ", data -> false");
  }
  if ($context->{version}<$context->{new_version}) {
    printf($stream ",\n\t\t   version -> $context->{version}");
  }
  printf($stream "};\n");
}


# BASH jobs workflow additions

sub write_job {
  my $lammps = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $global = EMC::Common::element($root, "global");
  my $context = EMC::Common::element($lammps, "context");
  my $flag = EMC::Common::element($lammps, "flag");
  my $project_name = EMC::Common::element($global, "project", "name");

  return if (!(defined($flag) && $flag->{write}));

  my $md = EMC::Common::element($root, "md", "context");
  my $md_flag = EMC::Common::element($root, "md", "flag");
  my $restart_dir = EMC::Common::element($md, "restart_dir");
  my $restart_name = "\${restart_dir}/*/*.restart?";
  my $restart_file = $md_flag->{restart} ? "\n".
    "  else\n".
    "    frestart=1;\n".
    "    restart=\$(first \$(ls -1t $restart_name));\n".
    "    if [ ! -e \"\${restart}\" ]; then\n".
    "      printf \"# $restart_name does not exist -> skipped\\n\\n\";\n".
    "      run cd \${WORKDIR};\n".
    "      return;\n".
    "    fi;\n".
    "    restart=\"-file \\\"'ls -1td $restart_name'\\\"\";" : "";
  my $shear_line = $global->{shear}->{rate} ? "\n      -var framp ".(
      $global->{shear}->{ramp} eq "" ? 0 : $global->{shear}->{ramp} eq "false" ? 0 : 1)." \\" : "";
  my $run_line = $flag->{trun} ?
      ($context->{trun} ne "" ? "\n\t-var trun ".eval($context->{trun})." \\" : "") : "";

  printf($stream
"
run_md() {
  local dir=\"\$1\"; shift;
  local frestart=\"\$1\"; shift;
  local ncores=\"\$1\"; shift;

  printf \"### \${dir}\\n\\n\";
  if [ ! -e \${dir} ]; then
    run mkdir -p \${dir};
  fi;

  local source=\"\$(path \"\${dir}\")\";
  local build=\"\$(path \"\${dir}/../build\")\";
  local restart_dir=\"\$(path ".(
    $md_flag->{restart} ? "$restart_dir" : "\${dir}/..").")\";
  local output restart file;
  
  if [ \${fbuild} != 1 ]; then
    if [ ! -e \${build}/$project_name.data ]; then
      printf \"# ../build/$project_name.data does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${build}/$project_name.params ]; then
      printf \"# ../build/$project_name.params does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${build}/$project_name.in ]; then
      printf \"# ../build/$project_name.in does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
  fi;

  if [ \${freplace} != 1 ]; then
    if [ \${frestart} != 1 ]; then
      if [ -e \${dir}/$project_name.dump ]; then
	printf \"# $project_name.dump exists -> skipped\\n\\n\";
	run_null;
	return;
      fi;
    else
      restart=\"-file \${restart_dir}\'/*/*.restart?\'\";".
      $restart_file."
      if [ \${ferror} == 1 ]; then
	if [ -e \"\$(first \${restart_dir}/*/$project_name.out)\" ]; then
	  file=\$(first \$(ls -1t \${restart_dir}/*/$project_name.out));
	  if [ \"\$(grep ERROR \${file})\" != \"\" ]; then
	    run_null;
	    return;
	  fi;
	else
	  frestart=0;
	fi;
      fi;
    fi;
  fi;

  run cd \${dir};
  run cp \${restart_dir}/build/$project_name.in .;
  set -f;
  WALLTIME=\${RUN_WALLTIME};
  run_pack -n \${ncores} -dir \"\${dir}\" \"\${restart}\" \\
    -walltime \${RUN_WALLTIME} -starttime \${START_TIME} -queue \${QUEUE} \\
    -input \${source}/$project_name.in -output $project_name.out \\
    -project $project_name \\
      lmp_\${HOST} -nocite \\
	-var source \${restart_dir}/build \\".
	$run_line.$shear_line."
	-var frestart \${frestart} \\
	-var restart \@FILE \\
	-var lseed \$(substr \${SEED} -8) \\
	-var vseed \$(substr \$(calc \"\${SEED}+1\") -8);
  set +f;

  SEED=\$(calc \${SEED}+2);
  run cd \"\${WORKDIR}\";
  echo;
}

set_restart() {
  RESTART=(\$1/*/*.restart?);
  echo \"\${RESTART[0]}\";
}
"); 
}

