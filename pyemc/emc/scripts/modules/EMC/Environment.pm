#!/usr/bin/env perl
#
#  module:	EMC::Environment.pm
#  author:	Pieter J. in 't Veld
#  date:	September 20, 2022.
#  purpose:	Environment structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "environment_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20220920	Inception of v1.0
#    20221106	Addition of item interpretation through set_item
#

package EMC::Environment;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Environment'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::IO;
use EMC::Math;
use EMC::Message;
use EMC::Script;
use EMC::Variables;
use File::Basename;
use File::Path;


# defaults

$EMC::Environment::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "November 6, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $environment = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($environment, $attr);
  set_defaults($environment);
  set_commands($environment);
  return $environment;
}


# initialization

sub set_defaults {
  my $environment = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $environment = EMC::Common::attributes(
    $environment,
    {
      # L

      loop		=> {},
      loop_variables	=> {
	active		=> [],
	expanded	=> [],
	stages		=> {},
	trials		=> [],
	vars		=> []
      },

      # R

      run_name		=> {
	analyze		=> "",
	build		=> "",
	run		=> "",
	test		=> "-"
      },

      # T

      trials		=> {},

      # V

      variables		=> {}
    }
  );
  $environment->{flag} = EMC::Common::attributes(
    EMC::Common::hash($environment, "flag"),
    {
      active		=> 0
    }
  );
  $environment->{identity} = EMC::Common::attributes(
    EMC::Common::hash($environment, "identity"),
    $EMC::Environment::Identity
  );
  return $environment;
}


sub transfer {
  my $environment = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($environment, "flag");
  my $context = EMC::Common::element($environment, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::Flag{environment},	\$flag->{active}],
    [\%::EMC::Loop,			\$environment->{loop}],
    [\%::EMC::LoopVariables,		\$environment->{loop_variables}],
    [\%::EMC::RunName,			\$environment->{run_name}],
    [\%::EMC::Trials,			$environment->{trials}],
  );
}


sub set_context {
  my $environment = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($root, "global", "units");
  my $flag = EMC::Common::element($environment, "flag");
  my $context = EMC::Common::element($environment, "context");

  my $name = (split("/", $global->{script}->{name}))[-1];

  foreach (keys(%{$environment->{run_name}})) {
    next if ($environment->{run_name}->{$_} ne "");
    $environment->{run_name}->{$_} = $name;
  }
}


sub set_commands {
  my $environment = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($environment, "set");
  my $context = EMC::Common::element($environment, "context");
  my $flag = EMC::Common::element($environment, "flag");

  EMC::Options::set_command(
    $environment->{commands} = EMC::Common::attributes(
      EMC::Common::hash($environment, "commands"),
      {
	# E

	environment	=> {
	  comment	=> "create project environment",
	  default	=> EMC::Math::boolean($flag->{active}),
	  gui		=> ["boolean", "chemistry", "top", "ignore"]},

	# N

	name_analyze	=> {
	  comment	=> "set job analyze script name",
	  default	=> $environment->{run_name}->{analyze},
	  gui		=> ["string", "chemistry", "top", "ignore"]},
	name_build	=> {
	  comment	=> "set job build script name",
	  default	=> $environment->{run_name}->{build},
	  gui		=> ["string", "chemistry", "top", "ignore"]},
	name_run	=> {
	  comment	=> "set job run script name",
	  default	=> $environment->{run_name}->{run},
	  gui		=> ["string", "chemistry", "top", "ignore"]},
	name_scripts	=> {
	  comment	=> "set analyze, job, and build script names simultaneously",
	  default	=> "",
	  gui		=> ["string", "chemistry", "top", "ignore"]},
	name_testdir	=> {
	  comment	=> "set job test directory as created in ./test/",
	  default	=> $environment->{run_name}->{test},
	  gui		=> ["string", "chemistry", "top", "ignore"]}
      }
    ),
    {
      set		=> \&set_options
    }
  );
  $environment->{items} = EMC::Common::attributes(
    EMC::Common::hash($environment, "items"),
    {
      # E

      environment	=> {
	chemistry	=> 0,
	environment	=> 1,
	order		=> 100,
	set		=> \&set_item_environment
      },
      
      # L

      loops		=> {
	chemistry	=> 0,
	environment	=> 1,
	order		=> 90,
	set		=> \&set_item_loops
      },
      
      # S

      stages		=> {
	chemistry	=> 0,
	environment	=> 1,
	order		=> 0,
	set		=> \&set_item_stages
      },

      # V

      variables		=> {
	chemistry	=> 1,
	environment	=> 1,
	order		=> 0,
	set		=> \&set_item_variables
      }
    }
  );
  return $environment;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $environment = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($environment, "flag");

  # E

  if ($option eq "environment") {
    return $flag->{active} = EMC::Math::flag($args->[0]);
  }

  # N

  if ($option eq "name_scripts" ) { 
    return
      $environment->{run_name}->{analyze} = 
      $environment->{run_name}->{build} = 
      $environment->{run_name}->{run} = $args->[0]; }
  if ($option eq "name_analyze") {
    return $environment->{run_name}->{analyze} = $args->[0]; }
  if ($option eq "name_build") { 
    return $environment->{run_name}->{build} = $args->[0]; }
  if ($option eq "name_run") { 
    return $environment->{run_name}->{run} = $args->[0]; }
  if ($option eq "name_testdir") { 
    return $environment->{run_name}->{test} = $args->[0]; }

  return undef;
}


sub set_functions {
  my $environment = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($environment, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&set_commands;
  $set->{context} = \&set_context;
  $set->{defaults} = \&set_defaults;
  $set->{options} = \&set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $environment;
}


# set item

sub set_item_environment {
  my $struct = shift(@_);
  my $flag = EMC::Common::element($struct, "root", "environment", "flag");

  $flag->{active} = 1;
  return EMC::Script::set_item_options($struct);
}


sub set_item_loops {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $option = EMC::Common::element($struct, "option");
  my $environment = EMC::Common::element($struct, "module");
  my $variables = EMC::Common::element($root, "emc", "variables", "item");
  my $global = EMC::Common::element($root, "global");

  my $loop = EMC::Common::hash($environment, "loop");
  my $loop_variables = EMC::Common::hash($environment, "loop_variables");
  my $loop_stages = EMC::Common::hash($loop_variables, "stages");
  my $loop_trials = EMC::Common::hash($loop_variables, "trials");
  
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $i = 0;

  my $loop_pair = "";
  my $nloop_pairing = -1;
  my $loop_stage = $global->{default};
  my $loop_trial = $global->{default};
  my %loop_check = (stage => 1, trial => 1, copy => 1);
  my @previous_variables = ();
  my $flags = {
    double => {d => 1, double => 1, doubled => 1},
    hide => {h => 1, hide => 1, hidden => 1},
    list => {l => 1, list => 1},
    pair => {p => 1, pair => 1, paired => 1},
    permutation => {2 => 1, 3 => 1, 4 => 1}};
 
  #EMC::Message::dumper("environment = ", $environment);
  $loop_variables->{active} = EMC::Common::array($loop_variables, "active");
  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$i++];

    if (scalar(@arg)>1) {
      my $variable = lc(shift(@arg));
      my @f = split(":", $variable);
      
      @f[0] = "stage" if (@f[0] eq "phase");			# legacy
      
      my $name = @f[0];
      my $flag = {
	map({$_ => defined($flags->{$_}->{@f[1]}) ? 1 : 0} keys(%{$flags}))};

      $flag->{pair} = 1 if ($flag->{hide});
      foreach (@arg) {
	if ($_ =~ m/:/) {
	  my @a = split(":");
	  next if (@a[0] ne "s" && @a[0] ne "seq");
	  if (@f[0] ne "copy" && !$flag->{pair}) {
	    #EMC::Message::error_line(
	    #  $line, "sequences are not allowed when not paired\n");
	  }
	  if (scalar(@a)<3 || scalar(@a)>5) {
	    EMC::Message::error_line($line, "incorrect sequence definition\n");
	  }
	}
      }
      
      $variable = join(":", @f);
      if (scalar(@f)>1) {
	if ($flag->{permutation} ? scalar(@f)>3 : scalar(@f)>2) {
	  EMC::Message::error_line($line, "too many modes for '$name'\n");
	}
	if (!($flag->{pair}||$flag->{double}||$flag->{list}||
	      $flag->{permutation})) {
	  EMC::Message::error_line($line, "unknown mode '@f[1]'\n");
	}
      }
      if ($nloop_pairing<0 || !$flag->{pair}) {
	$nloop_pairing = scalar(@arg);
	$loop_pair = @f[0];
      } elsif ($nloop_pairing != scalar(@arg)) {
	print("nloop = $nloop_pairing != ", scalar(@arg), " {", join(", ", @arg), "}\n");
	EMC::Message::error_line(
	  $line, "unequal pair '$loop_pair' and '@f[0]'\n");
      }
      my $changed = 0;
      foreach (@{$loop_variables->{active}}) {
	my @f = split(":");
	next if (@f[0] ne $name);
	next if ($flag->{pair}^(scalar(@f)>1 ? 1 : 0) ? 0 : 1);
	delete $loop->{$_};
	$_ = $variable;
	$changed = 1;
	last;
      }
      my $v = (split(":", $variable))[0];
      $variable = $v if (defined($loop_check{$v}));
      if (!(defined($loop->{$variable}) || $changed)) {
	push(@{$loop_variables->{active}}, $variable);
      }
      foreach (@arg) {
	my $s = $_;
	foreach (@previous_variables) { my $v = uc($_); $s =~ s/\@$v//g; }
	if ($s =~ m/\@/) {
	  my $ls = $s;
	  $s = EMC::Variables::variable_replace($variables, $s);
	  if ($s eq $ls && !$global->{flag}->{expert}) {
	    EMC::Message::error_line(
	      $line, "unallowed variable reference '$s'\n");
	  }
	  $_ = $s;
	}
      }
      if ($variable eq "copy") {
	@{$loop->{$variable}} = @arg;
	foreach (@{$loop->{$variable}}) {
	  my @arg = split(":");
	  next if (scalar(@arg)>2 && (@arg[0] eq "s" || @arg[0] eq "seq"));
	  $_ = 1 if ($_ < 1);
	  $_ = int($_);
	}
      } elsif ($variable eq "ncores") {
	@{$loop->{$variable}} = @arg;
	foreach (@{$loop->{$variable}}) {
	  $_ = 1 if ($_ < 1);
	  $_ = int($_);
	}
      } else {
	if ($flag->{list}) {
	  my $x0 = shift(@arg);
	  my $xn = shift(@arg);
	  my $dx = shift(@arg);
	  my $n = int(($xn-$x0)/$dx+0.5);
	  my @a = ();
	  my $i;
	  for ($i=0; $i<$n; ++$i) { push(@a, $x0+$i*$dx); }
	  $loop->{$variable} = [@a];
	} else {
	  $loop->{$variable} = [$flag->{pair} ? @arg : 
		$flag->{double} ? @arg : EMC::List::unique($line, @arg)];
	}
      }
      if ($variable eq "stage") {
	$loop_stage = [
	  $flag->{double} ? @arg : EMC::List::unique($line, @arg)];
	$loop_variables->{stages} = EMC::Common::attributes(
	  $loop_variables->{stages}, EMC::List::hash($loop_stage));
      } elsif ($variable eq "trial") {
	if (!defined($loop_stage)) {
	  EMC::Message::error_line($line, "cannot set trial before stage\n");
	}
	$loop_trial = [
	  $flag->{double} ? @arg : EMC::List::unique($line, @arg)];
	$loop_variables->{trials} = EMC::Common::attributes(
	  $loop_variables->{trials}, EMC::List::hash($loop_trial));
      }
      push(@previous_variables, $name);
    } 
  }
  return $root;
}


sub set_item_stages {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $option = EMC::Common::element($struct, "option");
  my $stages = EMC::Common::element($struct, "item");

  my $global = EMC::Common::element($root, "global");
  my $extension = EMC::Common::element($global, "script", "extension");
  my $project = EMC::Common::element($global, "project");
  my $work_dir = EMC::Common::element($global, "work_dir");
  
  my $module = EMC::Common::element($struct, "module");
  my $loop_variables = EMC::Common::element($module, "loop_variables");
  my $allowed = {
    stages => EMC::Common::element($loop_variables, "stages"),
    trials => EMC::Common::element($loop_variables, "trials")
  };

  foreach (sort(keys(%{$stages}))) {
    my $stage = $_;
    my $item_stage = $stages->{$_};

    if (!($stage eq "default" || defined($allowed->{stages}->{$stage}))) {
      EMC::Message::warning("skipping undefined stage '$stage'\n");
      next;
    }
    foreach (sort(keys(%{$item_stage}))) {
      my $trial = $_;
      my $item_trial = $item_stage->{$_};

      if (!($trial eq "default" || defined($allowed->{trials}->{$trial}))) {
	EMC::Message::warning("skipping undefined trial '$trial'\n");
	next;
      }
      foreach (sort(keys(%{$item_trial}))) {
	next if ($_ eq "index");
	my $option = $_;
	my $item = $item_trial->{$_};
	my $options = EMC::Hash::arguments(
	  EMC::Common::element($item, "options"));

	next if (EMC::Common::element($options, "comment"));

	$option .= "s" if ($option eq "template");
	my $ext = $option eq "templates" ? $extension : ".dat";
	my $sub_dir = "$option/$project->{directory}$project->{name}/$stage";
	my $dir = "$work_dir/chemistry/$sub_dir";
	my $full = EMC::IO::expand($dir);

	if (!(-d $full || scalar(File::Path::make_path($full)))) {
	  EMC::Message::error("could not create '$dir/'\n");
	}
	if ($option eq "structures") {	
	  # !!! check structures better with trials
	  # !!! structures only with stage
	  foreach (@{$item->{data}}) {
	    my $name = "$dir/".$_->[0].$ext;
	    
	    if (!EMC::IO::check_exist($root, $option, $name)) {
	      my $stream = EMC::IO::open($name, "w");
	      EMC::Message::info("writing chemistry '$sub_dir/$_->[0]$ext'\n");
	      EMC::IO::put($stream, [$_->[1]]);
	      EMC::IO::close($stream, $name);
	    }
	  }
	} else {
	  my $name = "$dir/$trial$ext";

	  if (!EMC::IO::check_exist($root, $option, $name)) {
	    EMC::Message::info("writing chemistry '$sub_dir/$trial$ext'\n");
	    if ($option eq "templates") {
	      EMC::Job::write_stage(
		$root, "$sub_dir/$trial$ext", $item->{data});
	    } else {
	      my $stream = EMC::IO::open($name, "w");
	      EMC::IO::put($stream, $item->{data});
	      EMC::IO::close($stream, $name);
	    }
	  }
	}
      }
    }
  }
}


sub set_item_variables {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $environment = EMC::Common::element($struct, "module");
  my $variables = EMC::Common::element($environment, "variables");
 
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $i = 0;

  return if (!(defined($data) && scalar(@{$data})));

  $variables->{data} = [] if (!defined($variables->{data}));
  foreach (@{$data}) {
    my @arg;
    
    foreach (split(" ")) {
      last if (substr($_,0,1) eq "#");
      push(@arg, $_);
    }
    next if (!scalar(@arg));
    push(@{$variables->{data}}, [shift(@arg), join(" ", @arg)]);
  }
  return $root;
}


# functions

sub check_loop {
  my $emc = shift(@_);
  my $type = shift(@_);
  my $value = shift(@_);
  my $line = shift(@_);
  my $global = $emc->{global};
  my $environment = $emc->{environment};
  my $loop = $environment->{loop};

  if (!$environment->{flag}->{active}) {
    EMC::Message::error(
      "'$type' section only allowed in environment mode\n");
  }
  if (defined($loop->{$type})) {
    my $flag = 0;
    foreach (@{$loop->{$type}}) {
      if ($_ eq $value) { $flag = 1; last; }
    }
    if (!$flag) {
      return $loop->{$type}->[0] if ($global->{flag}->{expert});
      EMC::Message::error_line($line, "no loop '$type' value '$value'\n");
    }
    return $value eq "" ? "default" : $value;
  }
  return "default";
}


sub create {					# <= create_environment
  my $root = shift(@_);
  my $job = EMC::Common::hash($root, "job");
  my $global = EMC::Common::hash($root, "global");
  my $environment = EMC::Common::hash($root, "environment");

  return if (!EMC::Common::element($environment, "flag", "active"));
  
  if (!defined($environment->{loop})) {
    EMC::Message::error("cannot create environment with undefined loops\n");
  }
  if (EMC::Common::element($job, "context", "queue", "ncores")<1) {
    EMC::Message::error("queue_ncores not set\n");
  }
  create_loop_variables_expansion($environment);

  my $loop = EMC::Common::hash($environment, "loop");

  push(@{$loop->{stage}}, "default") if (!defined($loop->{stage}));
  push(@{$loop->{trial}}, "default") if (!defined($loop->{trial}));

  my $stored = {
    root => $global->{root}, work_dir => $global->{work_dir}};
  my $work_dir = $global->{work_dir};

  $work_dir =~ s/^~/$ENV{HOME}/;
  $global->{work_dir} =~ s/^~/\${HOME}/g;
  $global->{root} =~ s/^$ENV{HOME}/\${HOME}/g;

  EMC::Options::set_context($root);
  EMC::Environment::create_dirs(
    $environment, "analyze", "build", "chemistry", "run", "test");
  
  chdir("chemistry");
  mkdir("scripts") if (! -e "scripts");
  my $name = "scripts/$global->{project}->{script}.sh";
  EMC::Environment::create_dirs($environment, dirname($name));
  if (!EMC::IO::check_exist($root, "chemistry", $name)) {
    EMC::Message::info("writing job create chemistry script \"$name\"\n");
    my $stream = EMC::IO::open($name, "w");
    chmod(0755, $stream);
    EMC::Job::write_create($root, $stream, $name =~ tr/\///);
    EMC::IO::close($stream);
  }
  chdir($work_dir);
  
  foreach ("analyze", "build", "run", "test") {
    chdir($_);
    EMC::Job::write_script($root, $_);
    chdir($work_dir);
  }

  $global->{work_dir} = $stored->{work_dir};
  $global->{root} = $stored->{root};
}


sub create_dirs {
  my $environment = shift(@_);
  my $run_name = EMC::Common::hash($environment, "run_name");
  my %check = ("analyze", "build", "run", "test");

  foreach (@_) {
    return if (defined($check{$_}) && 
              ($run_name->{$_} eq "" || $run_name->{$_} eq "-"));
    my $last = "";
    foreach (split("/", $_)) { 
      mkdir($last.$_);
      $last .= "$_/";
    }
  }
}


sub create_loop_variables_expansion {
  my $environment = shift(@_);
  my $loop_variables = EMC::Common::element($environment, "loop_variables");
  my $pairing = {};
  my $index = [];
  my $vars = [];

  job_loop_pairing($loop_variables, $pairing, $vars, $index);

  $loop_variables->{expand} = [];
  foreach (@{$index}) {
    my $name = $_;
    my $def = defined($pairing->{$name}) ? 1 : 0;
    my $dim = $def ? $pairing->{$name}->{dim} : 1;
   
    for (my $i=1; $i<=$dim; ++$i) {
      push(@{$loop_variables->{expand}}, $name.($dim>1 ? "_".$i:""));
    }
    next if (!$def);

    my $list = $pairing->{$name}->{list};
    my $hide = $pairing->{$name}->{hide};
    
    for (my $i=0; $i<scalar(@{$list}); ++$i) {
      next if ($hide->[$i]);
      my $p = $list->[$i];
      for (my $j=1; $j<=$dim; ++$j) {
	push(@{$loop_variables->{expand}}, $p.($dim>1 ? "_".$j : ""));
      }
    }
  }

  $loop_variables->{vars} = [];
  foreach (@{$vars}) {
    next if (!defined($pairing->{$_}));

    my $name = $_;
    my $list = $pairing->{$name}->{list};
    my $dim = $pairing->{$name}->{dim};
   
    for (my $i=1; $i<=$dim; ++$i) {
      push(@{$loop_variables->{vars}}, $name.($dim>1 ? "_".$i:""));
    }
    foreach (@{$list}) {
      for (my $i=1; $i<=$dim; ++$i) {
	push(@{$loop_variables->{vars}}, $_.($dim>1 ? "_".$i : ""));
      }
    }
  }
  push(@{$loop_variables->{vars}}, "copy") if ($vars->[0] eq "copy");
}


sub job_loop_pairing {					# setup pairing
  my $loop_variables = shift(@_);
  my $pairing = shift(@_);
  my $vars = shift(@_);
  my $index = shift(@_);
  my $last = "";
  my $fcopy = 0;
  my $i = 0;

  foreach (@{$loop_variables->{active}}) {
    my @arg = split(":");
    my $name = shift(@arg);
    my $fpair = @arg[0] eq "p" || @arg[0] eq "pair" ? 1 : 0;
    my $fhide = @arg[0] eq "h" || @arg[0] eq "hide" ? 1 : 0;
    my $dim = @arg[0] eq "2" ? 2 : @arg[0] eq "3" ? 3 : @arg[0] eq "4" ? 4 : 1;
    
    if (($fpair || $fhide) && $i>0) {
      push(@{$pairing->{$last}->{list}}, $name);
      push(@{$pairing->{$last}->{hide}}, $fhide);
    } elsif ($name eq "copy") {
      push(@{$index}, $name) if (defined($index));
      $fcopy = 1;
    } else {
      push(@{$index}, $name) if (defined($index));
      push(@{$vars}, $name);
      $pairing->{$name}->{dim} = $dim;
      $pairing->{$name}->{perm} = join(":", @arg);
      @{$pairing->{$name}->{list}} = ();
      @{$pairing->{$name}->{hide}} = ();
      $last = $name;
    }
    ++$i;
  }
  unshift(@{$vars}, "copy") if ($fcopy);
}


sub job_loop_sequence_q {
  my $loop = shift(@_);
  my $var = shift(@_);

  foreach (keys(%{$loop})) {
    my @a = split(":");
    next if (@a[0] ne $var);
    foreach (@{$loop->{$_}}) {
      my @a = split(":");
      next if (scalar(@a)<2);
      return 1 if (@a[0] eq "s" || @a[0] eq "seq");
    }
  }
  return 0;
}

