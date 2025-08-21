#!/usr/bin/env perl
#
#  module:	EMC::Job.pm
#  author:	Pieter J. in 't Veld
#  date:	September 8, 2022.
#  purpose:	Job structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "job_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20220908	Inception of v1.0
#

package EMC::Job;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Job'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::Math;
use File::Path;


# defaults

$EMC::Job::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 8, 2022",
  version	=> "1.0"
};

$EMC::Job::Width = 80;


# construct

sub construct {
  my $job = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($job, $attr);
  set_defaults($job);
  set_commands($job);
  return $job;
}


# initialization

sub set_defaults {
  my $job = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $job->{context} = EMC::Common::attributes(
    EMC::Common::hash($job, "context"),
    {
      # H

      host_defaults	=> {
	quriosity	=> {
	  ppn		=> 64,
	  memory	=> 4
	},
	vdi		=> {
	  ppn		=> 8,
	  memory	=> 4
	}
      },

      # M

      modules		=> [],
      
      # N

      nchains		=> -1,

      # Q

      queue		=> {
	account		=> "none",
	analyze		=> "default",
	bind		=> "core",
	build		=> "default",
	headnode	=> "default",
	memory		=> "default",
	ncores		=> -1,
	ppt		=> 1,
	ppn		=> "default",
	project		=> "none",
	run		=> "default",
	scratch		=> "none",
	sync		=> 0,
	test		=> 0,
	user		=> "none"
      },

      # R

      run_time		=> {
	analyze		=> "00:30:00",
	build		=> "00:10:00",
	run		=> "24:00:00"
      }

    }
  );
  $job->{flag} = EMC::Common::attributes(
    EMC::Common::hash($job, "flag"),
    {
      norestart		=> 0
    }
  );
  $job->{identity} = EMC::Common::attributes(
    EMC::Common::hash($job, "identity"),
    $EMC::Job::Identity
  );
  return $job;
}


sub transfer {
  my $dummy = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($dummy, "flag");
  my $context = EMC::Common::element($dummy, "context");
  
  EMC::Element::transfer(
    [\%::EMC::HostDefaults,	\$context->{host_defaults}],
    [\@::EMC::Modules,		\$context->{modules}],
    [\$::EMC::NChains,		\$context->{nchains}],
    [\$::EMC::Flag{norestart},	\$flag->{norestart}],
    [\%::EMC::Queue,		\$context->{queue}],
    [\%::EMC::RunTime,		\$context->{run_time}]
  );
}


sub set_context {
  my $job = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $units = EMC::Common::element($global, "units");
  my $host = EMC::Common::element($global, "env", "host");
  
  my $flag = EMC::Common::element($job, "flag");
  my $context = EMC::Common::element($job, "context");
  my $queue = EMC::Common::element($job, "context", "queue");
  my $host_defaults = EMC::Common::element($job, "context", "host_defaults");
  
  $EMC::Job::Width = $global->{flag}->{width} ? 160 : 80;
  $context->{nchains} = -1 if ($context->{nchains}<2);

  if (defined($host_defaults->{$host})) {
    my $ptr = $host_defaults->{$host};
    foreach (keys(%{$ptr})) {
      if ($queue->{$_} eq "default") {
	$queue->{$_} = $ptr->{$_};
      }
    }
  }
  if ($queue->{ppn}>0) {
    if ($queue->{ncores}>$queue->{ppn}) {
      if ($queue->{ncores} % $queue->{ppn}) {
	EMC::Message::warning("queue_ncores %% queue_ppn != 0.\n");
      }
    } else {
      if ($queue->{ppn} % $queue->{ncores}) {
	EMC::Message::warning("queue_ppn %% queue_ncores != 0.\n");
      }
    }
  }
  if ($queue->{ncores}<$queue->{ppn} &&
      $context->{nchains}>1) {
    EMC::Message::error("cannot use chains when queue_ncores<queue_ppn.\n");
  }
  if ($queue->{ncores}<$queue->{ppn} && $context->{nchains}>1) {
    EMC::Message::error("cannot use chains when queue_ncores<queue_ppn.\n");
  }
  #if ($queue->{ppn}<2 && $queue->{bind} eq "default") {
  #  $queue->{bind} = "core";
  #}

  $queue->{sync} = EMC::Math::flag($queue->{sync});
  $queue->{test} = EMC::Math::flag($queue->{test});
}


sub set_commands {
  my $job = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($job, "set");
  my $flag = EMC::Common::element($job, "flag");
  my $context = EMC::Common::element($job, "context");
  my $queue = EMC::Common::element($job, "context", "queue");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  
  $indicator = $indicator ? "job_" : "";
  my $commands = $job->{commands} = EMC::Common::attributes(
    EMC::Common::hash($job, "commands"),
    {
      # M

      memorypercore	=> {
	comment		=> "set queue memory per core in gb",
	default		=> $queue->{memory},
	gui		=> ["string", "environment", "top", "ignore"]},
      modules		=> {
	comment		=> "manipulate runtime modules in format [command=]module",
	default		=> "", # @{$context->{modules}},
	gui		=> ["string", "environment", "top", "ignore"]},

      # N

      nchains		=> {
	comment		=> "set number of chains for execution of MD jobs",
	default		=> $context->{nchains}<0 ? "" : $context->{nchains},
	gui		=> ["integer", "chemistry", "lammps", "standard"]},
      ncores		=> {
	comment		=> "set number of cores for execution of MD jobs",
	default		=> $queue->{ncores},
	gui		=> ["integer", "environment", "lammps", "standard"]},
      ncorespernode	=> {
	comment		=> "set queue cores per node for packing jobs",
	default		=> $queue->{ppn},
	gui		=> ["integer", "environment", "top", "ignore"]},
#      norestart		=> {
#	comment		=> "control possibility of restarting when rerunning",
#	default		=> EMC::Math::boolean($flag->{norestart}),
#	gui		=> ["integer", "chemistry", "emc", "ignore"]},
      nthreads		=> {
	comment		=> "set number of cores for per thread for MD jobs",
	default		=> $queue->{ppt},
	gui		=> ["integer", "environment", "lammps", "ignore"]},

      # Q

      queue		=> {
	comment		=> "queue settings",
	default		=> EMC::Hash::text($queue, "string"),
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_account	=> {
	comment		=> "set queue account for billing",
	default		=> $queue->{account},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_analyze	=> {
	comment		=> "set job analyze script queue",
	default		=> $queue->{analyze},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_bind	=> {
	comment		=> "set binding policy for processes",
	default		=> $queue->{bind},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_build	=> {
	comment		=> "set job build script queue",
	default		=> $queue->{build},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_headnode	=> {
	comment		=> "set alternate stageout headnode",
	default		=> $queue->{headnode},
	gui		=> ["integer", "environment", "lammps", "advanced"]},
      queue_memory	=> {
	comment		=> "set queue memory per core in gb",
	default		=> $queue->{memory},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_ncores	=> {
	comment		=> "set number of cores for execution of MD jobs",
	default		=> $queue->{ncores},
	gui		=> ["integer", "environment", "lammps", "standard"]},
      queue_ppn		=> {
	comment		=> "set queue cores per node for packing jobs",
	default		=> $queue->{ppn},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_ppt		=> {
	comment		=> "set queue cores per thread",
	default		=> $queue->{ppt},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_project	=> {
	comment		=> "set queue project name (PBS only)",
	default		=> $queue->{project},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_run		=> {
	comment		=> "set job run script queue",
	default		=> $queue->{run},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_scratch	=> {
	comment		=> "set queue scratch directory variable",
	default		=> $queue->{scratch},
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_sync	=> {
	comment		=> "set rsync of scratch results back to origin",
	default		=> EMC::Math::boolean($queue->{sync}),
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_test	=> {
	comment		=> "activate queue scripts testing mode",
	default		=> EMC::Math::boolean($queue->{test}),
	gui		=> ["string", "environment", "top", "advanced"]},
      queue_user	=> {
	comment		=> "options to be passed directly to queuing system",
	default		=> $queue->{user},
	gui		=> ["string", "environment", "top", "advanced"]},

      # R

      time_analyze	=> {
	comment		=> "set job analyze script wall time",
	default		=> $context->{run_time}->{analyze},
	gui		=> ["string", "environment", "analysis", "standard"]},
      time_build	=> {
	comment		=> "set job build script wall time",
	default		=> $context->{run_time}->{build},
	gui		=> ["string", "environment", "emc", "standard"]},
      time_run		=> {
	comment		=> "set job run script wall time",
	default		=> $context->{run_time}->{run},
	gui		=> ["string", "environment", "lammps", "standard"]}
    }
  );

  foreach (keys(%{$commands})) {
    my $ptr = $commands->{$_};
    if (!defined($ptr->{set})) {
      $ptr->{set} = \&EMC::Job::set_options;
    }
  }

  return $job;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $job = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($job, "flag");
  my $context = EMC::Common::hash($job, "context");
  my $queue = EMC::Common::hash($job, "context", "queue");
  my $set = EMC::Common::element($job, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "job_" : "";

  # M

  if ($option eq "memorypercore") { 
    return $queue->{memory} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "modules") {
    $context->{modules} = [];
    foreach (@${args}) {
      my @arg = split("=");
      foreach (@arg) { $_ =~ s/^\s+|\s+$//g; }	# remove space from start/end
      if (scalar(@arg)>2) { 
	EMC::Message::error_line($line, "expecting [command=]module\n");
      }
      if (scalar(@arg)>1) {
	push(@{$context->{modules}}, "@arg[0]=@arg[1]");
      } elsif (@arg[0] eq "purge") {
	push(@{$context->{modules}}, "@arg[0]");
      } else {
	push(@{$context->{modules}}, "load=@arg[0]");
      }
    }
    return $context->{modules};
  }
  
  # N

  if ($option eq "ncores") {
    return $queue->{ncores} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "ncorespernode") { 
    return $queue->{ppn} = EMC::Math::eval($args->[0])->[0]; }
#  if ($option eq "norestart") {
#  $::EMC::Flag{norestart} = EMC::Math::flag($args->[0]); }
  if ($option eq "nchains") {
    return $context->{nchains} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "nthreads") { 
    return $queue->{nthreads} = EMC::Math::eval($args->[0])->[0]; }

  # Q

  if ($option eq "queue") {
    EMC::Hash::set($line, $context->{queue}, "string", "", [], @{$args});
    return $context->{queue};
  }
  if ($option eq "queue_account") {
    return $queue->{account} = $args->[0]; }
  if ($option eq "queue_analyze") {
    return $queue->{analyze} = $args->[0]; }
  if ($option eq "queue_bind") {
    my $allowed = {
      none => 1, hwthread => 1, core => 1,
      l1cache => 1, l2cache => 1, l3cache => 1,
      socket => 1, numa => 1, board => 1, default => 1
    };
    if (!defined($allowed->{$args->[0]})) {
      EMC::Message::error_line($line, "unallowed queue_bind value\n");
    }
    return $queue->{bind} = $args->[0]; }
  if ($option eq "queue_build") {
    return $queue->{build} = $args->[0]; }
  if ($option eq "queue_headnode") { 
    return $queue->{headnode} = $args->[0]; }
  if ($option eq "queue_memory") {
    return $queue->{memory} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "queue_ncores") {
    return $queue->{ncores} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "queue_ppn") {
    return $queue->{ppn} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "queue_ppt") {
    return $queue->{ppt} = EMC::Math::eval($args->[0])->[0]; }
  if ($option eq "queue_project") {
    return $queue->{project} = $args->[0]; }
  if ($option eq "queue_run") {
    return $queue->{run} = $args->[0]; }
  if ($option eq "queue_scratch") {
    $args->[0] =~ s/\$/@/g;
    return $queue->{scratch} = $args->[0]; }
  if ($option eq "queue_sync") {
    return $queue->{sync} = EMC::Math::flag($args->[0]); }
  if ($option eq "queue_test") {
    return $queue->{test} = EMC::Math::flag($args->[0]); }
  if ($option eq "queue_user") {
    return $queue->{user} = join(" ", @{$args}); }

  # R

  if ($option eq "time_analyze") {
    return $context->{run_time}->{analyze} = $args->[0]; }
  if ($option eq "time_build") {
    return $context->{run_time}->{build} = $args->[0]; }
  if ($option eq "time_run") {
    return $context->{run_time}->{run} = $args->[0]; }
  
  return undef;
}


sub set_functions {
  my $job = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($job, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Job::set_commands;
  $set->{context} = \&EMC::Job::set_context;
  $set->{defaults} = \&EMC::Job::set_defaults;
  $set->{options} = \&EMC::Job::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $job;
}


# functions

sub print {					# <= my_job_print
  my $stream = shift(@_);
  my $indent = shift(@_);
  my $s = shift(@_);
  my $nspace = $indent%8;
  my $ntab = ($indent-$nspace)/8;
  my $i;

  for ($i=0; $i<$ntab; ++$i) { printf($stream "\t"); }
  for ($i=0; $i<$nspace; ++$i) { printf($stream " "); }
  printf($stream $s."\n");
}

 
sub queue_entry {
  my $arg = shift(@_);
  $arg =~ m/"([^"]*)"/;
  return $arg eq "none" ? "" : $arg;
}


# Job script

sub write_script {				# <= write_job
  my $root = shift(@_);
  my $type = shift(@_);

  my $job = EMC::Common::element($root, "job");
  my $replace = EMC::Common::element($root, "global", "replace");
  my $run_name = EMC::Common::element($root, "environment", "run_name");
  my $script = $run_name->{$type}.".sh";

  return if ($run_name->{$type} eq "" || $run_name->{$type} eq "-");
  if ($type eq "test") {
    mkpath($run_name->{$type}) unless(-d $run_name->{$type});
    $script = "$run_name->{$type}/setup.sh";
  }
  if ((-e $script)&&!$replace->{flag}) {
    warning("\"$script\" exists; use -replace flag to overwrite\n");
    return;
  }

  EMC::Message::info("writing job $type script \"$script\"\n");

  my $stream = EMC::IO::open($script, "w");

  chmod(0755, $stream);
  write_header($stream, $job, $type);
  write_functions($stream, $job, $type);
  write_submit($stream, $job, $type);
  write_settings($stream, $job, $type);
  write_footer($stream, $job, $type);

  EMC::IO::close($stream);
}


sub write_create {				# <= write_job_create
  my $root = shift(@_);
  my $stream = shift(@_);
  my $nlevels = shift(@_);
 
  my $environment = EMC::Common::element($root, "environment");
  my $loop_variables = EMC::Common::element($environment, "loop_variables");
  my $variables = EMC::Common::element($environment, "variables");
  my $global = EMC::Common::element($root, "global");
  my $identity = EMC::Common::element($global, "identity");
  my $flag = EMC::Common::element($global, "flag");

  my $date = EMC::Common::date_full();
  my $ext = ".dat";
  my $root = ".."; while (--$nlevels) { $root .= "/.."; }
  my $replacements;
  my $cases;
  my $loops;

  foreach (@{$loop_variables->{vars}}) {		# loop vars
    next if ($_ eq "trial");
    next if ($_ eq "stage");
    my $var = (split(":"))[0];
    $cases .= "\n      -$var) shift; $var=\"\$1\";;";
    $loops .= "\n  replace \"\@".uc($var)."\" \"\${$var}\";";
  }
  $replacements = $loops if ($flag->{expert});
  if (defined($variables->{data})) {
    foreach (reverse(@{$variables->{data}})) {		# environment vars
      my @var = @{$_};
      
      $replacements .= 
	"\n  replace \"\@".uc(shift(@var))."\" \"".
	join(" ", @var)."\";";
    }
    $replacements .= $loops;
  } elsif (!$flag->{expert}) {
    $replacements .= $loops;
  }

  printf($stream					# script
"#!/bin/bash
#
#  script:	scripts/$global->{project}->{script}.sh
#  author:	$identity->{script} v$identity->{version}, $identity->{date}
#  date:	$date
#  purpose:	Create chemistry file based on sample definitions; this
#  		script is auto-generated
#

# functions

init() {
  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -project) shift; project=\"\$1\";;
      -trial) shift; trial=\"\$1\";;
      -phase) shift; stage=\"\$1\";;
      -stage) shift; stage=\"\$1\";;$cases
      -*) shift;;
      *) if [ \"\${chemistry}\" = \"\" ]; then chemistry=\"\${home}/\$1$global->{script}->{extension}\"; fi;;
    esac;
    shift;
  done;

  if [ \"\${chemistry}\" = \"\" ]; then chemistry=\"\${home}/chemistry$global->{script}->{extension}\"; fi;
  if [ \"\${trial}\" = \"\" ]; then trial=\"default\"; fi;
  if [ \"\${stage}\" = \"\" ]; then stage=\"default\"; fi;
  
  template=templates/\${project}/\${stage}/\${trial}$global->{script}->{extension};
  if [ ! -e \$template ]; then
    template=templates/\${project}/\${stage}/default$global->{script}->{extension};
    if [ ! -e \$template ]; then
      template=templates/\${project}/default/\${trial}$global->{script}->{extension};
      if [ ! -e \$template ]; then
	template=templates/\${project}/default/default$global->{script}->{extension};
      fi;
    fi;
  fi;
  if [ ! -e \$template ]; then 
    error \"cannot locate a template for stage \'\$stage\' and trial \'\$trial\'\";
  fi;
}

error() {
  echo \"Error: \$@\";
  echo;
  exit -1;
}

# create chemistry file

create() {
  cp \"\$template\" \"\$chemistry\";

  replace \"\@GROUPS\" \"groups/\${project}/\${stage}\" \"\${trial}\";
  replace \"\@CLUSTERS\" \"clusters/\${project}/\${stage}\" \"\${trial}\";
  replace \"\@POLYMERS\" \"polymers/\${project}/\${stage}\" \"\${trial}\";
  replace \"\@SHORTHAND\" \"shorthand/\${project}/\${stage}\" \"\${trial}\";
  replace \"\@STRUCTURE\" \"structures/\${project}/\${stage}\" \"\${trial}\";
  $replacements
  
  replace \"\@WORKDIR\" \"$global->{work_dir}\";
  replace \"\@EMCROOT\" \"$global->{root}\";
  replace \"\@STAGE\" \"\${stage}\";
  replace \"\@TRIAL\" \"\${trial}\";

  chmod a+rx \"\${chemistry}\";
}

replace() {
  if [ \"\$3\" = \"\" ]; then
    if [ \"\$2\" != \"\" ]; then
      replace.pl -v -q \"\$1\" \"\$2\" \"\${chemistry}\";
    fi;
  elif [ -f \"\$2/\$3$ext\" ]; then 
    replace.pl -v -q \"\$1\" \"\$(cat \$2/\$3$ext)\" \"\${chemistry}\";
  fi;
}

# main

  home=\$(pwd);
  project=\"$global->{project}->{directory}$global->{project}->{name}\";
  cd \$(dirname \$0)/$root;
  init \"\$@\";
  create;
");
}


sub write_dir {					# <= write_job_dir
  my $text;
  my $flag;
 
  foreach (@_) { 
    my @arg = split(":");
    my $name = uc(@arg[0]);
    my $fhide = @arg[1] eq "h" || @arg[1] eq "hide" ? 1 : 0;
    if ($name eq "copy") {
      $flag = 1;
    } elsif ($fhide) {
      next;
    } else {
      $text .= "/\${$name}";
    }
  }
  $text .= "/\${copy}" if ($flag);
  return $text;
}


sub write_footer {				# <= write_job_footer
  my $stream = shift(@_);
  my $job = shift(@_);
  my $type = shift(@_);

  my $root = EMC::Common::element($job, "root");
  my $context = EMC::Common::element($job, "context");
  my $md = EMC::Common::element($root, "md");
  my $environment = EMC::Common::element($root, "environment");
  my $global = EMC::Common::element($root, "global");
  my $flag = EMC::Common::element($global, "flag");

  my $header = "\n  printf \"### started script at \$(date)\\n\\n\";";
  my $trailer;
  my $host = $global->{env}->{host};

  $host = "\n  HOST=\"${host}\";" if ($host ne "");
  
  if ($type eq "analyze") {
    printf($stream "archive() {
  local select;

  cd \"\${target}\";
  if [ \"\${farchive}\" == \"0\" ]; then return; fi;
  if [ ! -e \${files} ]; then return; fi;
  for file in \${files}; do
    if [ ! -e \${file} ]; then continue; fi;
    if [ \"\${select}\" == \"\" ]; then select=\${file};
    else select=\"\${select} \${file}\"; fi;
  done;
  if [ \"\${fdata}\" == \"0\" ]; then return; fi;
  if [ \"\${select}\" != \"\" ]; then
    run tar -zvcf \${data} -T \${select};
  fi;
  rm -f \${files};
  cd \"\${WORKDIR}\";
}\n
");
    $header .= " 
  run_init \"\$@\";

  mkdir -p exchange/files;
  files=\$(mktemp exchange/files/XXXXXXXX);
  mkdir -p exchange/data;
  data=exchange/data/\$(basename \${files}).tgz;
  
  target=\"\${WORKDIR}\";
  if [ \"\${source}\" != \"\" ]; then
    data=\"\${WORKDIR}/\${data}\";
    cd \"\${source}\";
    WORKDIR=\"\$(pwd)\";
  fi;
  
  cutoff=$global->{cutoff}->{pair};
";
  } elsif ($type eq "build") {
    $header .= "\n  run_init \"\$@\";\n";
  } elsif ($type eq "run") {
    $header .= "\n  run_init \"\$@\";\n" if (!$md->{flag}->{restart});
  } elsif ($type eq "test") {
    printf($stream
"# main
$host
  set_root;
  
  cd \"$global->{work_dir}\";
  WORKDIR=\"\$(pwd)\";
  CHEMISTRY=\"\${WORKDIR}/chemistry\";
  cd \"test/$environment->{run_name}->{$type}\";

  submit;
");
    return;
  }

  $trailer = "\n  STAGE=generic;" if (!defined($environment->{loop}->{stage}));
  
  foreach (@{$context->{modules}}) {
    my @arg = split("=", $_);
    if (@arg[0] eq "purge") {
      $header .= "\n  run module purge;\n";
    } elsif (@arg[0] eq "unload") {
      $header .= "\n  module unload @arg[1];";
    } elsif (@arg[0] eq "load") { 
      $header .= "
  if [ \"\$(module load @arg[1] 2>&1 | grep error)\" != \"\" ]; then
    echo \"Error: cannot load module @arg[1]\";
    echo; exit -1;
  fi;
  run module load @arg[1];
";
    }
  }

  $trailer .= "\n  MODULES=\"".join(",", @{$context->{modules}})."\";";

  printf($stream "%s",
"# main
$host
  set_root;

  cd \"$global->{work_dir}\";
  WORKDIR=\"$global->{work_dir}\";
  LOG_FILE=\"\${WORKDIR}/$type/\$(basename \$0 .sh).log\";
  CHEMISTRY=\"\${WORKDIR}/chemistry\";
$header
  QUEUE=$context->{queue}->{$type};
  QUEUE_ACCOUNT=\"".queue_entry($context->{queue}->{account})."\";
  QUEUE_BIND=\"".queue_entry($context->{queue}->{bind})."\";
  QUEUE_HEADNODE=\"".queue_entry($context->{queue}->{headnode})."\";
  QUEUE_PROJECT=\"".queue_entry($context->{queue}->{project})."\";
  QUEUE_SCRATCH=\'$context->{queue}->{scratch}\';
  QUEUE_SYNC=\"$context->{queue}->{sync}\";
  QUEUE_USER=\"".queue_entry($context->{queue}->{user})."\";
  START_TIME=\"now\";
".($type eq "analyze" ? "
  WALLTIME=$context->{run_time}->{analyze};" : "
  BUILD_WALLTIME=$context->{run_time}->{build};
  RUN_WALLTIME=$context->{run_time}->{run};")."
  SEED=\$(date +%s);
  NCORES_PER_NODE=$context->{queue}->{ppn};
  NCORES_PER_THREAD=$context->{queue}->{ppt};
  MEMORY_PER_CORE=$context->{queue}->{memory};
  NCORES=".($type eq "run" ? $context->{queue}->{ncores} : 1).";$trailer

  FLAG_PACK=0;
  WAIT_IDS=();
  NPACK=(0 0);
  PACK_DIR=\"$type/\$(basename \${script} .sh)\";
  if [ -e \"\${PACK_DIR}\" ]; then run_check \${PACK_DIR}; fi;

");

  foreach (@{$environment->{loop_variables}->{active}}) {
    my @vars;
    foreach (@{$environment->{loop}->{$_}}) { push(@vars, split(", ", $_)); }
    @vars = map({"'$_'"} @vars);
    printf($stream "  ".uc((split(":"))[0])."s=(".join(" ", @vars).");\n")
  }
  
  printf($stream "\n  submit 2>&1 | tee \"\${LOG_FILE}\";\n");
  printf($stream "\n  archive;\n") if ($type eq "analyze");
  printf($stream "  %s\n", "printf \"### finished script at \$(date)\\n\\n\";");
  printf($stream "\n");
}


sub write_func {				# <= write_job_func
  my $job = shift(@_);
  my $stream = shift(@_);
  my $type = shift(@_);
  my $text = shift(@_);

  my $loop_variables = 
    EMC::Common::element($job, "root", "environment", "loop_variables");
  my @vars = $type eq "run" ? 
    split(" ", "dir serial iserial nserials ichoice restart frestart values") :
    split(" ", "dir last values");
  my $i;
  my @replacements;

  if ($type eq "test") {
    return;
  }

  foreach (@{$loop_variables->{active}}) {
    my @arg = split(":");
    my $name = @arg[0];
    my $fpair = 
      @arg[1] eq "p" || @arg[1] eq "pair" ||
      @arg[1] eq "h" || @arg[1] eq "hide" ? 1 : 0;
    my $fperm = 
      @arg[1] eq "2" || @arg[1] eq "3" || @arg[1] eq "4" ? 1 : 0;

    push(@vars, "i_$name") if (!$fpair && $name ne "copy");
    push(@vars, "v_$name") if ($fperm && $name ne "copy");
    ++$i;
  }

  printf($stream "\nsubmit() {\n");
  write_indent($stream, 1, join(" ", "local", sort(@vars)).";");
  printf($stream "\n  %s\n", "printf \"\\n### started submit at \$(date)\\n\\n\";");
  write_loops($stream, $job, $type, 1, $text);
  printf($stream "  %s\n}\n\n", "printf \"### finished submit at \$(date)\\n\\n\";");
}


sub write_func_options {
  my $job = shift(@_);

  my $root = EMC::Common::element($job, "root");
  my $md = EMC::Common::element($root, "md");
  my $modules = EMC::Common::element($md, "modules");
  my $global = EMC::Common::element($root, "global");
  my $flag = EMC::Common::element($global, "flag");
  my $project = EMC::Common::element($global, "project");

  my $options = [
    " \\\n      -project \"$project->{directory}$project->{name}\""
  ];

  foreach (@{$modules}) {
    next if (!EMC::Common::element($md, $_, "set", "flag", "md"));
    next if (EMC::Common::element($md, $_, "flag", "write")<1);
    if (EMC::Common::element($md, $_, "context", "version")) {
      $options->[1] .= " \\\n      -".$_."=".
	EMC::Common::element($md, $_, "context", "version");
    } else {
      $options->[1] .= " \\\n      -".$_."=".EMC::Math::flag(
	EMC::Common::element($md, $_, "flag", "write")
      );
    }
  }
  return $options; 
}


sub write_func_test {				# <= write_job_func_test
  my $job = shift(@_);
  my $stream = shift(@_);

  my $root = EMC::Common::element($job, "root");
  my $md = EMC::Common::element($root, "md");
  my $modules = EMC::Common::element($md, "modules");
  my $global = EMC::Common::element($root, "global");
  my $flag = EMC::Common::element($global, "flag");
  my $project = EMC::Common::element($global, "project");
  my $loop_variables = 
    EMC::Common::element($root, "environment", "loop_variables");

  my $options = write_func_options($job);
  my $preprocess = $flag->{environment} ? 0 : $flag->{preprocess};
  my $md_engine = EMC::MD::get_engine($md);

  printf($stream "\nsub submit {\n");
  foreach (@{$loop_variables->{active}}) {
    my $var = (split(":"))[0];
    $options->[0] .= " \\\n    -$var \"\${$var}\"";
    printf($stream 
      "  local $var=\"@{$job->{loop}->{$_}}[0]\";\n")
  }
  printf($stream "
  run \\
    \"\${chemistry}/scripts/$project->{script}.sh\"$options->[0] \\
      $project->{name};
  run \\
    emc.pl$options->[1] \\
      -preprocess=$preprocess \\
      -project=$project->{name} \\
      -md_engine=$md_engine \\
      -workdir=\"\${WORKDIR}\" \\
      $project->{name}$global->{script}->{extension};
}\n\n");
}


sub write_functions {				# <= write_job_functions
  my $stream = shift(@_);
  my $job = shift(@_);
  my $type = shift(@_);

  my $queue = EMC::Common::hash($job, "context", "queue");

  my $root = EMC::Common::element($job, "root");
  my $analyze = EMC::Common::element($root, "analyze");
  my $build = EMC::Common::element($root, "emc", "context", "build");
  my $fexecute = EMC::Common::element($root, "emc", "flag", "execute");
  my $executable = EMC::Common::element($root, "emc", "flag", "executable");
  my $emc = $fexecute ? $executable : "emc_\${HOST}";
  
  my $md = EMC::Common::element($root, "md");
  my $lammps = EMC::Common::element($md, "lammps");
  my $shear = EMC::Common::element($md, "context", "shear");
  my $namd = EMC::Common::element($md, "namd");
  
  my $global = EMC::Common::element($root, "global");
  my $flag = EMC::Common::element($global, "flag");
  my $identity = EMC::Common::element($global, "identity");
  my $project = EMC::Common::element($global, "project");
  
  my $environment = EMC::Common::element($root, "environment");
  my $loop_variables = EMC::Common::element($environment, "loop_variables");

  my $preprocess = $flag->{environment} ? 0 : $flag->{preprocess};
  my $md_engine = EMC::MD::get_engine($md);
  my @test = $queue->{test} ?
    ("tmp=1\n", "JOB_ID=\$tmp; tmp=\$((tmp+1)); echo \${JOB_ID}; return;\n  ") :
    ("", "");

  # GENERAL

  if ($type ne "test") {
    printf($stream 
"
# variables

script=\$(basename \"\$0\");

# functions

run() {
  echo \"\$@\"; \"\$@\";
}

first() {
  echo \"\$1\";
}

shft() {
  shift; echo \"\$@\";
}

pop() {
  local a=(\$\@); echo \"\${a[\@]:0:\${#a[\@]}-1}\";
}

calc() {
  perl -e 'print(eval(\$ARGV[0]));' -- \$@;
} 

zero() {
  perl -e '
    \@a = \@ARGV;
    \$n = eval(shift(\@a));
    foreach (\@a) { \$n = length(\$_) if (\$n<length(\$_)); }
    foreach (\@a) { \$_ =~ s/^0+//; \$_ = sprintf(\"\%0\".\$n.\"d\", int(eval(\$_))); }
    print(join(\" \", \@a));
    ' -- \$@;
}

split() {
  perl -e '
    \@a = split(\@ARGV[1], \@ARGV[0]);
    print(defined(\@ARGV[2]) ? \@a[\@ARGV[2]] : join(\" \", \@a));
  ' -- \$@;
}

join() {
  perl -e 'print(join(\",\", \@ARGV).\"\\n\");' -- \$@;
}

last() { 
  local s=\$1;
  while [ \"\$1\" != \"\" ]; do s=\$1; shift; done;
  echo \"\$s\";
}

start() {
  perl -e '
    \$h = \$ARGV[0]+0; \$m = \$ARGV[1]+\$ARGV[2];
    if ((\$d = int(\$m/60))) { \$h += \$d; \$m -= 60*\$d; }
    \$h = \"0\".\$h if (\$h<10); \$m = \"0\".\$m if (\$m<10);
    print(\"\$h\$m\\n\");
    ' -- \$(date +\%H) \$(date +\%M) \$1;
}

substr() {
  perl -e 'print(substr(\$ARGV[0],eval(\$ARGV[1])));' -- \$@;
}

strip() {
  local dir=\$(echo \$1 | awk '{split(\$0,a,\"'\$HOME/'\"); print a[2]}');

  if [ \"\$dir\" = \"\" ]; then dir=\$1; fi;
  if [ \"\$dir\" = \"\$HOME\" ]; then dir=\"\"; fi;
  echo \"\$dir\";
}

path() {
  local file;

  for file in \$@; do 
    cd \"\$(dirname \"\${file}\")\";
    case \"\$(basename \"\${file}\")\" in
      ..) echo \"\$(dirname \"\$(pwd)\")\";;
      .)  echo \"\$(pwd)\";;
      *)  echo \"\$(pwd)/\$(basename \"\${file}\")\";;
    esac;
  done;
}

create_list() {
  local list=(\$(perl -e \'
    \@arg = split(\":\", \$ARGV[0]);
    \@a = shift(\@arg); foreach(\@arg) { push(\@a, eval(\$_)); }
    print(join(\" \", \@a))\' -- \$1));

  if [ \"\${list[0]}\" == \"s\" -o \"\${list[0]}\" == \"seq\" ]; then
    if [ \"\${list[4]}\" == \"w\" ]; then
      echo \$(seq -\${list[4]} \${list[1]} \${list[3]} \${list[2]});
    else
      echo \$(seq \${list[1]} \${list[3]} \${list[2]});
    fi;
  else
    echo \"\$1\";
  fi;
}

create_copies() {
  local list=(\$(split \$1 \":\"));

  if [ \"\${list[0]}\" == \"s\" -o \"\${list[0]}\" == \"seq\" ]; then
    echo \$(seq -w \${list[1]} \${list[3]} \${list[2]});
  else
    echo \$(seq -w 0 \$(calc \"\$1-1\"));
  fi;
}

@test[0]run_sh() {
  local output;
  local line=(-memory \${MEMORY_PER_CORE} -ppn \${NCORES_PER_NODE});

  if [ \"\${QUEUE_ACCOUNT}\" != \"\" ]; then
    line+=(-account \${QUEUE_ACCOUNT});
  fi;
  if [ \"\${QUEUE_BIND}\" != \"default\" ]; then
    line+=(-bind \${QUEUE_BIND});
  fi;
  if [ \"\${QUEUE_PROJECT}\" != \"\" ]; then
    line+=(-queue_project \${QUEUE_PROJECT});
  fi;
  if [ \"\${QUEUE_USER}\" != \"\" ]; then
    line+=(\${QUEUE_USER});
  fi;
  if [ \"\${MODULES}\" != \"\" ]; then
    line+=(-modules \"\${MODULES}\");
  fi;
  line+=(\$@);
  echo \"run.sh \${line[@]}\"; 
  @test[1]if [ \"\${fsubmit}\" != 1 ]; then JOB_ID=-1; return; fi;
  while IFS= read -r; do output+=(\"\$REPLY\"); done < <(run.sh \${line[@]});
  printf \"%%s\\n\" \"\${output[@]}\";
  JOB_ID=\$(perl -e '
    \$a = (split(\" \", \@ARGV[0]))[-1];
    \$a =~ s/[<|>]//g; 
    print(\$a);\' -- \"\${output[\${#output[@]} - 3]}\");
}

run_check() {
  local dir=\"\$1\";
  local error=();
  local file;
  local stat;

  for file in \"\${dir}/\"*.sh; do
    if [ -x \"\${file}\" ]; then 
      stat=\"\$(run_stat.sh \$(\"\${file}\" job))\";
      case \"\${stat}\" in 
	Q) error+=(\"queued \\\"\${file}\\\"\");;
	R) error+=(\"running \\\"\${file}\\\"\");;
      esac;
    fi;
  done;
  if [ \${#error[@]} -gt 0 ]; then
    for file in \"\${error[@]}\"; do
      echo \"ERROR: cannot overwrite \${file}\";
    done;
    printf \"\\nERROR: $type script not executed\\n\\n\";
    exit;
  fi;
  run rm -rf \"\${dir}\";
  run mkdir \"\${dir}\";
}

wait_id() {
  local id;

  JOB_ID=0;
  if [ \${#LAST_JOB_IDS[@]} -gt 0 ]; then
    JOB_ID=\"\${LAST_JOB_IDS[0]}\";			# determine dependence
    LAST_JOB_IDS=(\${LAST_JOB_IDS[@]:1});
    if [ \${#WAIT_IDS[@]} -gt 0 ]; then
      for id in \${WAIT_IDS[@]}; do
	if [ \"\${JOB_ID}\" == \"\${id}\" ]; then return; fi;
      done;
    fi;
    if [ \"\${JOB_ID}\" != \"-1\" -a \"\${JOB_ID}\" != \"0\" ]; then
      if [ \"\${WAIT_IDS}\" == \"\" ]; then WAIT_IDS=\"\${JOB_ID}\";
      else WAIT_IDS=\"\${WAIT_IDS}:\${JOB_ID}\"; fi;
    fi;
  fi;
}

pack_file() {
  local dir=\"\${WORKDIR}/\${PACK_DIR}\";
  echo \$(perl -e \'printf(\"%%s/%%04d%%s\", \@ARGV);\' -- \"\${dir}\" \${NPACK[0]} \$1);
}

pack_exec() {
  local i wait;
  local work=\"\$1\"; shift;
  local file=\"\$(pack_file)\";
  local dir=\"\$(dirname \"\${file}\")\";
  local commands=();
 
  file=\$(basename \"\${file}\");
  if [ \${NPACK[1]} -lt 1 ]; then return; fi;		# skip on empty
  if [ \"\${WAIT_IDS}\" != \"\" ]; then commands+=(-wait \${WAIT_IDS}); fi;
  if [ \"\${QUEUE_HEADNODE}\" != default ]; then
    commands+=(-headnode \${QUEUE_HEADNODE});
  fi;
  if [ \"\${QUEUE_SCRATCH}\" != none ]; then
    commands+=(-sync \${QUEUE_SYNC});
    commands+=(-work \"\${work}\");
    commands+=(-scratch \"\${QUEUE_SCRATCH}\");
  fi;
  if [ \${FLAG_PACK} == 1 ]; then			# based on scripts
    run pushd \"\${dir}\";
    chmod +x \"\${file}.sh\";
    printf \"\\n  wait;\\n\\n\" >>\"\${file}.sh\";
    printf 'elif [ \"\$1\" == \"job\" ]; then\\n\\n' >>\"\${file}.sh\";
    if [ \"\${QUEUE}\" == \"local\" ]; then
      printf \"  echo \${JOB_ID};\\n\\n\" >>\"\${file}.sh\";
      printf \"fi;\\n\\n\" >>\"\${file}.sh\";
    fi;
    commands+=(-scratch_cd 0);
    run_sh \\
      -n \${NCORES_PER_NODE} -single \"\${commands[@]}\" \\
      -walltime \${WALLTIME} -starttime \${START_TIME} -queue \${QUEUE} \\
      -project \${file} -output \${file}.log ./\${file}.sh run;
    if [ \"\${QUEUE}\" != \"local\" ]; then
      printf \"  echo \${JOB_ID};\\n\\n\" >>\"\${file}.sh\";
      printf \"fi;\\n\\n\" >>\"\${file}.sh\";
    fi;
    run popd;
  else
    run_sh \"\${commands[@]}\" \"\$@\";			# direct execution
  fi;
  for i in \${!JOB_IDS[@]}; do
    if [ \"\${JOB_IDS[\$i]}\" == \"-1\" ]; then JOB_IDS[\$i]=\${JOB_ID}; fi;
  done;
  NPACK[0]=\$(calc \"\${NPACK[0]}+1\");
  NPACK[1]=0;
  WAIT_IDS=();
}

pack_header() {
  printf '#!/bin/bash\\n\\n';
  printf 'run() { echo \"\$@\"; \"\$@\"; }\\n\\n';
  printf 'if [ \"\$1\" == \"run\" ]; then\\n';
}

run_pack() {
  local command=\"\$1\"; shift;				# should be -n
  local n=\"\$1\"; shift; 		\t		# ncores to run with

  if [ \${command} != \"-n\" ]; then
    echo \"panic: first argument of run_pack != '-n'\"; echo; exit;
  fi;
  
  local command=\"\$1\"; shift;				# should be -dir
  local dir=\"\$1\"; shift; 				# target directory

  if [ \"\${command}\" != \"-dir\" ]; then
    echo \"panic: second argument of run_pack != '-dir'\"; echo; exit;
  fi;

  local first=(-n \${n});

  if [ \"\$1\" == \"-single\" ]; then			# for e.g. GROMACS
    first=(\${first[@]} -single);			# when run scripts
    shift;	 					# include mpiexec
  fi;

  local root=\${WORKDIR};
  local target=\$(pwd);
  local line=(-system local);
  local target;
  local file;

  if [ \"\${MODULES}\" != \"\" ]; then
    line+=(-modules \"\${MODULES}\");
  fi;

  wait_id;
  JOB_IDS+=(-1);					# future dependence

  FLAG_PACK=0;						# set FLAG_PACK
  if [ \"\${NCORES_PER_NODE}\" != \"default\" ]; then
    if [ \${n} -lt \${NCORES_PER_NODE} ]; then 
      FLAG_PACK=1;
      if [ ! -e \"\${WORKDIR}/\${PACK_DIR}\" ]; then 
	mkdir -p \"\${WORKDIR}/\${PACK_DIR}\";
      fi;
    fi;
  fi;
  
  if [ \${FLAG_PACK} == 1 ]; then			# execute packing
    file=\"\$(pack_file)\";
    echo \"run_pack \${first[@]} \$@\"; 
    if [ ! -e \"\${file}.sh\" ]; then pack_header >\"\${file}.sh\"; fi;
    echo >>\"\${file}.sh\";
    if [ \"\${QUEUE_SCRATCH}\" != none ]; then
      root=\$(echo \${QUEUE_SCRATCH} | tr \\\@ \\\$);
      target=\"\${root}/\${dir}\";
      echo \"  run mkdir -p \\\"\${target}\\\"\" >>\"\${file}.sh\";
    fi;
    echo \"  run cd \\\"\${target}\\\"\" >>\"\${file}.sh\";
    echo \"  run run.sh \${first[@]} \${line[@]} \$@ &\" >>\"\${file}.sh\";
    echo \"\${target}\" >>\"\${file}.dirs\";
    NPACK[1]=\$(calc \"\${NPACK[1]}+\${n}\");
    if [ \"\$(calc \"\${NPACK[1]}+\${n}\")\" -gt \"\${NCORES_PER_NODE}\" ]; then
      pack_exec \"\${WORKDIR}\";
    fi;
  else
    NPACK[1]=1;						# direct execution
    pack_exec \"\$(pwd)\" \${first[@]} \"\$@\";
  fi;
}

run_null() {
  JOB_IDS+=(0);						# no dependence
}
");
  }
  print($stream "
location() {
  local home=\"\$(pwd -P)\";
  cd \"\$1\";
  pwd -P;
  cd \"\${home}\";
}

local_which() {
  local output=\"\$(which \$1 2>&1)\";

  if [ \"\${output}\" != \"\" ]; then
    if [ \"\$(echo \"\${output}\" | grep \"no \$1\")\" == \"\" ]; then
      echo \${output};
    fi;
  fi;
}

set_root() {
  local emc=\"\$(local_which $emc)\";
  local root=\"\${EMC_ROOT}\";

  if [ \"\${emc}\" != \"\" ]; then
    root=\"\$(location \"\$(dirname \"\${emc}\")/..\")\";
  fi;
  if [ \"\${root}\" == \"\" ]; then
    echo \"ERROR: cannot determine EMC location (EMC_ROOT undefined)\";
    echo;
    exit;
  fi;
  ROOT=\"\${root}\";
}

replace() {
  perl -e \'
    for (\$i=1; \$i<scalar(\@ARGV); \$i+=2) {
      my \$a; foreach(split(\"\", \$ARGV[\$i])) {
       	\$a .= \$l eq \"@\" && \$_ ne \"{\" ? \"{\$_\" : \$_; \$l = \$_; }
      \$a .= \"}\" if (\$l ne \"}\");
      \$h{\$a} = \$ARGV[\$i+1]; \$h{\$a} =~ s/^0+//;
    }
    foreach(split(\"\", \$ARGV[0])) {
      if (\$_ eq \"[\") {
	++\$brackets;
      } elsif (\$_ eq \"]\") {
	--\$brackets;
      }
      if (\$_ eq \"@\" && !\$brackets) {
	if (\$v ne \"\") { 
	  \$v .= \"}\"; \$r .= (defined(\$h{\$v}) ? \$h{\$v} : \$v);
	}
	\$v = \$_.\"{\"; \$f = 1; \$b = 0;
      } elsif (\$f) {
	if ((\$_ =~ /[a-zA-Z]/)||(\$_ =~ /[0-9]/)||(\$b && \$_ ne \"}\")) {
	  \$v .= \$_;
	} elsif (\$_ eq \"{\" && \$l eq \"@\") {
	  \$b = 1;
	} else {
	  \$v .= \"}\";
	  \$r .= (defined(\$h{\$v}) ? \$h{\$v} : \$v).(\$b && \$_ eq \"}\" ? \"\" : \$_);
	  \$v = \"\"; \$f = \$b = 0;
	}
      } else {
	\$r .= \$_;
      }
      \$l = \$_;
    }
    \$v .= \"}\" if (\$v ne \"\");
    \$r .= (defined(\$h{\$v}) ? \$h{\$v} : \$v);
    print(\$r);
  \' -- \"\$@\";
}
");

  # ANALYZE

  if ($type eq "analyze" && defined($analyze->{scripts})) {
    if ($analyze->{scripts}->{cavity}->{active}) {
      $analyze->{data} = 0;
    }
    printf($stream
"
help() {
  echo \"EMC analyze script created by $identity->{script} v$identity->{version}, $identity->{date}\n\";
  echo \"Usage:\n  \$script [-option [#]]\n\";
  echo \"Options:\";
  echo \"  -help\t\tthis message\";
  echo \"  -[no]archive\tcontrol creation of exchange tar archive\";
  echo \"  -[no]data\tcontrol transferral of exchange file list into tar archive\";
  echo \"  -[no]emc\tcontrol creation of last trajectory structure in EMC format\";
  echo \"  -[no]pdb\tcontrol creation of last trajectory structure in PDB format\";
  echo \"  -[no]replace\tcontrol replacement of exiting results\";
  echo \"  -skip\t\tset number of entries to skip [\${skip}]\";
  echo \"  -source\tset data source directory [\${source}]\";
  echo \"  -[no]submit\tcontrol job submission\";
  echo \"  -window\tset averaging window [\${window}]\";
  echo;
  exit;
}

run_init() {
  femc=0;
  fpdb=1;
  fsubmit=1;
  farchive=$analyze->{flag}->{archive};
  fdata=$analyze->{flag}->{data};
  freplace=$analyze->{flag}->{replace};
  skip=$analyze->{context}->{skip};
  window=$analyze->{context}->{window};
  source=\"$analyze->{context}->{source}\";

  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -archive) farchive=1;;
      -noarchive) farchive=0;;
      -data) fdata=1;;
      -nodata) fdata=0;;
      -submit) fsubmit=1;;
      -nsubmit) fsubmit=0;;
      -emc) femc=1;;
      -noemc) femc=0;;
      -pdb) fpdb=1;;
      -nopdb) fpdb=0;;
      -replace) freplace=1;;
      -noreplace) freplace=0;;
      -skip) shift; skip=\$(calc \"\$1\");;
      -window) shift; window=\$(calc \"\$1\");;
      -source) shift; source=\"\$1\";;
      *) help;;
    esac
    shift;
  done;
}

run_analyze() {
  local script=\"\$1\"; shift;

  if [ \"\$(basename \${script})\" == \"\${script}\" -a ! -e \"\${script}\" ]; then
    if [ -e \"\${ROOT}/scripts/analyze/\${script}\" ]; then
      script=\"\${ROOT}/scripts/analyze/\${script}\";
    elif [ -e \"\${ROOT}/scripts/analyze/\${script}.sh\" ]; then
      script=\"\${ROOT}/scripts/analyze/\${script}.sh\";
    elif [ -e \"\${WORKDIR}/chemistry/analyze/\${script}\" ]; then
      script=\"\${WORKDIR}/chemistry/analyze/\${script}\";
    elif [ -e \"\${WORKDIR}/chemistry/analyze/\${script}.sh\" ]; then
      script=\"\${WORKDIR}/chemistry/analyze/\${script}.sh\";".
($analyze->{context}->{user} ne "" ? "
    if [ -e \"$analyze->{context}->{user}/\${script}\" ]; then
      script=\"$analyze->{context}->{user}/\${script}\";
    elif [ -e \"$analyze->{context}->{user}/\${script}.sh\" ]; then
      script=\"$analyze->{context}->{user}/\${script}.sh\";" : "")."
    fi;
  fi;
  run \"\$script\" \"\$@\";
}

analyze() {
  local dir=\"\$1\"; shift;
  local target=\"\$1\"; shift;
  local archive=\"\$1\"; shift;
  local main=\$(dirname \"\${dir}\");
  local project=\"$project->{name}\";
  local home=\$(pwd);

");
    foreach (sort(keys(%{$analyze->{scripts}}))) {
      my $key = $_;
      my $hash = $analyze->{scripts}->{$key};

      next if (!$hash->{active});
      
      my $copy = defined($hash->{options}->{copy}) ? $hash->{options}->{copy}:0;
      my $script = $hash->{script};
      my $check = $hash->{check};
      my %options = (
	archive => "\${archive}",
	dir	=> $copy ? "\${main}" : "\${dir}",
	replace => "\${freplace}",
	skip	=> "\${skip}".($key eq "green-kubo" ? "+1" : ""),
	target	=> "\${target}",
	window	=> "\${window}"
      );
      my $lines = "run_analyze $script \\\n";
      my $line = " ";
      my $option;

      foreach (keys(%{$hash->{options}})) {
	$options{$_} = $hash->{options}->{$_} if ($_ ne "copy");
      }
      foreach (sort(keys(%options))) {
	$line .= " -$_ \"$options{$_}\"";
      }
      $option = " \\\n  $project->{name}";
      if ($copy) {
	write_indent($stream, 1, "if \[ \"\${COPY}\" != \"\" -a \$(calc \${COPY}) == 0 \]; then");
	write_indent($stream, 2, "cd ..;");
	write_indent($stream, 2, "if [ -e \"\$(first $check)\" ]; then");
	write_indent($stream, 3, $lines.$line.$option);
	write_indent($stream, 2, "else");
	write_indent($stream, 3, "echo \"# $check does not exist -> skipping\";");
	write_indent($stream, 3, "echo;");
	write_indent($stream, 2, "fi;");
	write_indent($stream, 2, "cd \${home};");
	write_indent($stream, 1, "fi;");
      } else {
	write_indent($stream, 1, "if [ -e \"\$(first $check)\" ]; then");
	write_indent($stream, 2, $lines.$line.$option);
	write_indent($stream, 1, "else");
	write_indent($stream, 2, "echo \"# $check does not exist -> skipping\";");
	write_indent($stream, 2, "echo;");
	write_indent($stream, 1, "fi");
      }
    }
    printf($stream "}\n");
  }

  # BUILD

  if ($type eq "build" || ($type eq "run" && !$md->{flag}->{restart})) {

    my $options = write_func_options($job);
    my $values = "";
   
    foreach(@{$loop_variables->{vars}}) {
      my $var = (split(":"))[0];
      $options->[0] .= " \\\n      -$var \"\${".uc($var)."}\"";
    }

    printf($stream
"
run_emc() {
  local dir=\"\$1\"; shift;$values

  printf \"### \${dir}\\n\\n\";
  if [ ! -e \${dir} ]; then
    run mkdir -p \${dir};
  fi;

  local source=\"\$(path \"\${WORKDIR}/\${dir}\")\";

  if [ -e \${dir}/$project->{name}.emc.gz -a \${freplace} = 0 ]; then
    printf \"# $project->{name}.emc.gz already exists -> skipped\\n\\n\";
    run_null;
    return;
  fi;

  run cd \${dir};
  run \\
    \"\${CHEMISTRY}/scripts/$project->{script}.sh\"$options->[0] \\
      $project->{name};
  run \\
    emc.pl$options->[1] \\
      -preprocess=$preprocess \\
      -project=$project->{name} \\
      -md_engine=$md_engine \\
      -workdir=\"\${WORKDIR}\" \\
      -emc_execute=false \\
      $project->{name}$global->{script}->{extension};
  
  if [ \${femc} = 1 ]; then
    WALLTIME=\${BUILD_WALLTIME};
    run_pack -n 1 -dir \"\${dir}\" \\
      -walltime \${BUILD_WALLTIME} -starttime \${START_TIME} -queue \${QUEUE} \\
      -project $project->{name} -output build.out \\
      $emc -seed=\${SEED} \"\\\"\${source}/build.emc\\\"\"
    SEED=\$(calc \${SEED}+1);
  else
    run_null;
  fi;

  run cd \"\${WORKDIR}\";
  echo;
}
");
  }
  if ($type eq "build") {
    printf($stream
"
help() {
  echo \"EMC build script created by $identity->{script} v$identity->{version}, $identity->{date}\n\";
  echo \"Usage:\n  \$script [-option]\n\";
  echo \"Options:\";
  echo \"  -help\t\tthis message\";
  echo \"  -[no]emc\tcontrol execution of EMC\";
  echo \"  -[no]replace\tcontrol replacement of emc and lammps scripts\";
  echo \"  -[no]submit\tcontrol job submission\";
  echo;
  exit;
}


run_init() {
  femc=1;
  fbuild=1;
  fsubmit=1;
  freplace=$build->{replace};
  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -submit) fsubmit=1;;
      -nosubmit) fsubmit=0;;
      -emc) femc=1;;
      -noemc) femc=0;;
      -replace) freplace=1;;
      -noreplace) freplace=0;;
      *) help;;
    esac
    shift;
  done;
}
");
  }

  # RUN

  if ($type eq "run") {
    my $restart_name = "$md->{context}->{restart_dir}/*/*.restart?";
    my $restart_file = $md->{flag}->{restart} ? "\n".
      "  else\n".
      "    frestart=1;\n".
      "    restart=\$(first \$(ls -1t $restart_name));\n".
      "    if [ ! -e \"\${restart}\" ]; then\n".
      "      printf \"# $restart_name does not exist -> skipped\\n\\n\";\n".
      "      run cd \${WORKDIR};\n".
      "      return;\n".
      "    fi;\n".
      "    restart=\"-file \\\"'ls -1td $restart_name'\\\"\";" : "";
    my $shear_line = $shear->{rate} ? "\n      -var framp ".(
	$shear->{ramp} eq "" ? 0 : $shear->{ramp} eq "false" ? 0 : 1)." \\" : "";
    my $run_line = $lammps->{context}->{trun_flag} ?
	($lammps->{context}->{trun} ne "" ? "\n\t-var trun ".eval($lammps->{context}->{trun})." \\" : "") : "";

    if (!$md->{flag}->{restart}) {
      printf($stream
"
help() {
  echo \"EMC run script created by $identity->{script} v$identity->{version}, $identity->{date}\n\";
  echo \"Usage:\n  \$script [-option]\n\";
  echo \"Options:\";
  echo \"  -help\t\tthis message\";
  echo \"  -[no]build\tcontrol inclusion of building initial structures\";
  echo \"  -[no]emc\tcontrol execution of EMC\";
  echo \"  -[no]error\tcontrol restart mode upon error\";
  echo \"  -[no]replace\tcontrol replacement of emc and lammps scripts\";
  echo \"  -[no]restart\tcontrol restarting already run MD simulations\";
  echo \"  -[no]submit\tcontrol job submission\";
  echo;
  exit;
}

run_init() {
  fbuild=0;
  femc=1;
  fsubmit=1;
  ferror=$lammps->{context}->{error};
  fnorestart=$flag->{norestart};
  freplace=$build->{replace};
  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -build) fbuild=1;;
      -nobuild) fbuild=0;;
      -submit) fsubmit=1;;
      -nosubmit) fsubmit=0;;
      -emc) femc=1;;
      -noemc) femc=0;;
      -error) ferror=1;;
      -noerror) ferror=0;;
      -replace) freplace=1; fnorestart=1;;
      -noreplace) freplace=0; fnorestart=0;;
      -restart) fnorestart=0;;
      -norestart) if [ \${freplace} != 1 ]; then fnorestart=1; fi;;
      *) help;;
    esac
    shift;
  done;
}
");
    }

    EMC::Options::write($stream, $root, "job");
  }

  write_permutations($stream, $job, $type);
  write_replace_vars($stream, $job, $type);

  # TEST

  if ($type eq "test") {
    my $dim = 1;
    my $fpair = 0;
    my $first = 1;
    my $options = write_func_options($job);
  
    printf($stream "\n# functions\n\n");
    printf($stream "run() {\n  echo \"\$@\"; \"\$@\"; }\n\n");
    printf($stream "submit() {\n  local values=();\n");
    foreach (@{$loop_variables->{active}}) {
      my @v = (split(":"));
      my $fpair =
	@v[1] eq "p" || @v[1] eq "pair" ||
	@v[1] eq "h" || @v[1] eq "hide" ? 1 : 0;
      my @a = split(":", @{$environment->{loop}->{$_}}[0]);
      my $value = @a[0] eq "s" || @a[0] eq "seq" ? @a[1] : @a[0];

      $value = "00" if (@v[0] eq "copy"); 

      $dim =
	@v[1] eq "2" || @v[1] eq "3" || @v[1] eq "4" ? @v[1] : 
	$fpair ? $dim : 1;

      for (my $i=1; $i<=$dim; ++$i) {
	my $var = $dim>1 ? @v[0]."_".$i : @v[0];

	$options->[0] .= " \\\n      -$var \"\${$var}\"";
	if ($first) {
	  printf($stream "  local $var=\"$value\"; ");
	  $first = 0;
	} else {
	  printf($stream 
	    "  local $var=\"\$(replace_vars '$value' \"\${values[\@]}\")\"; ");
	}
	printf($stream "values+=(\"\$$var\");\n");
      }
    }

    printf($stream "
  run \\
    \"\${CHEMISTRY}/scripts/$project->{script}.sh\"$options->[0] \\
      $project->{name};
  run \\
    emc.pl$options->[1] \\
      -preprocess=$preprocess \\
      -project=$project->{name} \\
      -md_engine=$md_engine \\
      -workdir=\"\${WORKDIR}\" \\
      $project->{name}$global->{script}->{extension};
}\n\n");
  }
}


sub write_indent {				# <= write_job_indent
  my $stream = shift(@_);
  my $nindent = shift(@_);
  my $i;

  foreach (split("\n", shift(@_))) {
    my $arg = $_;
    my $ntab = length(($arg =~ /^(\t*)/)[0]); $arg =~ s/^\t+//;
    my $nspace = length(($arg =~ /^( *)/)[0]); $arg =~ s/^\s+//;
    my $indent = 2*$nindent+8*$ntab+$nspace;
    my $n = $EMC::Job::Width*int(($indent+10)/$EMC::Job::Width+1);
    my $npars = 0;
    my $first = 1;
    my $s = "";
    my @words = split(" ", $arg);

    if (scalar(@words)>1) {
      foreach (@words) {
	my $tmp = $s.(length($s) ? " $_" : $_);
	if ($indent+length($tmp)+1<=$n-2) { $s = $tmp; next; }
	EMC::Job::print($stream, $indent+2*$npars, $s." \\");
	$npars += ($s =~ tr/\(//)-($s =~ tr/\)//)+$first;
	$first = 0;
	$s = $_;
      }
    } else {
      $s = @words[0];
    }
    EMC::Job::print($stream, $indent+2*$npars, $s) if (length($s));
  }
}


sub write_header {				# <= write_job_header
  my $stream = shift(@_);
  my $job = shift(@_);
  my $type = shift(@_);

  my $identity = EMC::Common::element($job, "root", "global", "identity");
  my $date = EMC::Common::date_full();
  my $text;

  if ($type eq "test") {
    $text = "EMC test script for setting up a single test configuration";
  } else {
    $text = "EMC wrap around script for setting up multiple configurations";
  }
  printf($stream
"#!/bin/bash
#
#  script:	run_$type.sh
#  author:	$identity->{script} v$identity->{version}, $identity->{date}
#  date:	$date
#  purpose:	$text;
#		to be used in conjuction with EMC v$identity->{emc}->{version} or higher;
#		this script is auto-generated
#
#  Copyright (c) $identity->{copyright} Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
");
}


sub write_loop {				# <= write_job_loop
  my $stream = shift(@_);
  my $indent = shift(@_);
  my $index = shift(@_);
  my $NAME = shift(@_);
  my $name = shift(@_);
  my $paired = shift(@_);
  my $dim = shift(@_);
  my $first = shift(@_);
  my $q = shift(@_) ? "" : "\"";

  for (my $i=0; $i<$dim; ++$i) {
    my $list = $first ? 
      "\${$NAME"."s[\$i_$name]}" :
      "$q\$(replace_vars \"\${$NAME"."s[\${i_$paired"."[$i]}]}\" \"\${values[\@]}\")$q";
    my $VAR = $NAME.($dim<2 ? "" : "_".($i+1));

    write_indent($stream,
      ${$indent}++, "for $VAR in $list; do");
    if (${$index}) {
      write_indent($stream,
	${$indent}, "values=(\${values[@]:0:${$index}} \"\$$VAR\");");
    } else {
      write_indent($stream,
	${$indent}, "values=(\"\$".uc($_)."\");");
    }
    ++${$index};
  }
}


sub write_loops {				# <= write_job_loops
  my $stream = shift(@_);
  my $job = shift(@_);
  my $type = shift(@_);
  my $indent = shift(@_);
  my $text = shift(@_);

  my $root = EMC::Common::element($job, "root");
  my $environment = EMC::Common::element($root, "environment");
  my $loop = EMC::Common::element($environment, "loop");
  my $loop_variables = EMC::Common::element($environment, "loop_variables");
  
  my $indent0 = $indent;
  my $nchains = $job->{context}->{nchains};
  my @unset = ();
  my $first = 1;
  my $copy = 0;
  my $pairing = {};
  my $index = [];
  my $vars = [];

  $nchains = 1 if ($nchains<1);
  EMC::Environment::job_loop_pairing($loop_variables, $pairing, $vars, $index);
  if ($type eq "run") {
    write_indent(
      $stream, $indent++,
	"for ichoice in \$(seq \$(calc \"1-\${fbuild}\") 1); do");
    write_indent(
      $stream, $indent,
	"if [ \${ichoice} == 0 ]; then nserials=1; else nserials=$nchains; fi;");
    write_indent(
      $stream, $indent++, 
	"for iserial in \$(create_copies \${nserials}); do");
    write_indent(
      $stream, $indent, "JOB_IDS=();");
  }
  my $index = 0;
  foreach (@{$vars}) {					# create loops
    my @arg = split(":");
    my $name = @arg[0];
    my $NAME = uc($name);
    my $perm = 1;
    my $dim = 1;
    my @pairs;
    my $sequence = EMC::Environment::job_loop_sequence_q($loop, $_);

    if ($name eq "copy") {
      write_indent(
	$stream, $indent++, 
	  "for $NAME in \$(zero 2 \$(create_copies \${$NAME"."s[0]})); do");
      push(@unset, 0);
      $copy = 1;
    } else {
      $dim = $pairing->{$name}->{dim};
      $perm = $pairing->{$name}->{perm};
      @pairs = @{$pairing->{$name}->{list}};
      write_indent(
	$stream, $indent, "COPY=\"\";") if ($first && !$copy);
      if ($dim>1) {
	write_indent(
	  $stream, $indent++, "for v_$name in \$(permutations $perm \${#$NAME"."s[@]}); do");
	write_indent(
	  $stream, $indent, "i_$name=(\$(split \$v_$name \":\"));");
      } else {
	write_indent(
	  $stream, $indent++, "for i_$name in \${!$NAME"."s[@]}; do");
      }
      push(@unset, 0);
      write_loop(
	$stream, \$indent, \$index, $NAME, $name, $name, $dim, $first, $sequence);
      push(@unset, 1);
    }
    my $paired = $name;
    foreach (@pairs) {
      my $name = $_;
      my $NAME = uc($name);
      my $names = "l_$_"."s";
      my $sequence = EMC::Environment::job_loop_sequence_q($loop, $_);
      
      if ($_ eq "copy") {
	write_indent($stream, $indent++,
	  "for $NAME in \$(zero 2 \$(create_copies \${$NAME"."s[\$i_$name]})); do");
	push(@unset, 0);
      } else {
	write_loop(
	  $stream, \$indent, \$index, $NAME, $name, $paired, $dim, $first, $sequence);
	push(@unset, 1);
      }
    }
    $first = 0;
  }

  write_indent($stream, $indent, $text);		# write text
 
  $indent0 += 2 if ($type eq "run"); 
  while ($indent>$indent0) {				# write postamble
    write_indent($stream, --$indent, "done;");
  }
  write_indent($stream, $indent,
    "pack_exec \"\${WORKDIR}\";\necho;\nLAST_JOB_IDS=(\"\${JOB_IDS[@]}\");");
  write_indent($stream, --$indent, "done;") if ($type eq "run");
  write_indent($stream, --$indent, "done;") if ($type eq "run");
}


sub write_permutations {			# <= write_job_permutations
  my $stream = shift(@_);
  my $job = shift(@_);
  my $type = shift(@_);

  printf($stream 
"
permutations() {
  perl -e '
    \@a = split(\":\", \@ARGV[0]);
    \$dim = shift(\@a);
    \$s = shift(\@a);
    \$n = \@ARGV[1];
    \$hash = {};
    \$i = [];
    
    \$s %= \$n if (defined(\$s));
    for (\$k=0; \$k<\$dim; ++\$k) { push(\@{\$i}, 0); }
    for (\$k=0; \$k<\$dim; ) {
      my \@f;
      foreach (\@{\$i}) { \@f[\$_] = 1; }
      if (defined(\$s) ? defined(\@f[\$s]) : 1) {
	my \@r = reverse(\@{\$i});
	my \@index = map({join(\":\", \@{\$_})} (\$i, \\\@r));
	++\$hash->{\@index[defined(\$hash->{\@index[0]}) ? 0 : 1]};
      }
      \$k = 0; foreach (\@{\$i}) {
	last if (++\$_<\$n);
	\$_ = 0;
	++\$k;
      }
    }
    print(join(\" \", sort(keys(\%{\$hash}))), \"\\n\");
  ' -- \$1 \$2;
}
");
}


sub write_replace_vars {			# <= write_job_replace_vars
  my $stream = shift(@_);
  my $job = shift(@_);

  my $environment = EMC::Common::element($job, "root", "environment");
  my $loop_variables = EMC::Common::element($environment, "loop_variables");

  my @replacements = 
    map({'"@{'.uc((split(":"))[0]).'}"'} @{$loop_variables->{vars}});
  my $result = 
    shift(@_) eq "test" ? "\"\${result}\"" : "\"\$(create_list \"\${result}\")\"";

  printf($stream "\nreplace_vars() {\n");
  write_indent($stream, 1, "local var=(".join(" ", @replacements).");");
  print($stream "
  local result=\"\$1\"; shift;
  local value=(\"\$@\");
  local i;

  for i in \${!value[@]}; do
    result=\$(replace \"\${result}\" \"\${var[\$i]}\" \"\${value[\$i]}\");
  done;
  echo $result;
}
");
}


sub write_settings {				# <= write_job_settings
  my $stream = shift(@_);
  my $job = shift(@_);
  my $type = shift(@_);

  printf($stream "");
}


sub write_stage {				# <= write_job_stage
  my $root = shift(@_);
  my $name = shift(@_);
  my $data = shift(@_);

  my $global = EMC::Common::element($root, "global");
  my $flag = EMC::Common::element($global, "flag");
  my $identity = EMC::Common::element($global, "identity");
  my $work_dir = EMC::Common::element($global, "work_dir");

  my $emc_setup = $flag->{preprocess} ? "-S emc.pl -preprocess" : "emc.pl";
  my $date = EMC::Common::date_full();

  my $stream = EMC::IO::open("$work_dir/chemistry/$name", "w");

  chmod(0755, $stream);
  printf($stream "#!/usr/bin/env $emc_setup
#
#  script:	$name
#  author:  	$identity->{script} v$identity->{version}, $identity->{date}
#  date:	$date
#  purpose:	EMC setup chemistry file as part of a multiple simulation
#  		workflow; this file is auto-generated
#

");
  EMC::IO::put($stream, $data);
  EMC::IO::close($stream);
}


sub write_submit {				# <= write_job_submit
  my $stream = shift(@_);
  my $job = shift(@_);
  my $type = shift(@_);

  my $global = EMC::Common::element($job, "root", "global");
  my $project = EMC::Common::element($global, "project");
  my $environment = EMC::Common::element($job, "root", "environment");

  my @loop_variables;
  my @loop_values;

  foreach (@{$environment->{loop_variables}->{active}}) { 
    push(@loop_variables, (split(":"))[0]);
    push(@loop_values, "\${".uc((split(":"))[0])."}");
  }

  if ($type eq "analyze") {
    
    # ANALYZE

    write_func($job, $stream, $type,
"dir=\"data".write_dir(@{$environment->{loop_variables}->{expand}})."\";
printf \"# \${dir}\\n\\n\";
if [ ! -e \"\${dir}\" ]; then
  printf \"# no such directory -> skipped\\n\\n\";
fi;
run cd \"\${dir}\";
run analyze \"\${dir}\" \"\${target}\" \"\${files}\";
if [ -e \"build/$project->{name}.params\" ]; then
  echo \"\${dir}/build/$project->{name}.params\" >>\"\${target}/\${files}\";
  if [ ! -e \"\${target}/\${dir}/build/$project->{name}.params\" ]; then
    mkdir -p \"\${target}/\${dir}/build\";
    cp -p \"build/$project->{name}.params\" \"\${target}/\${dir}/build\";
  fi;
fi;
run cd \"\${WORKDIR}\";
echo;
"); 

  } elsif ($type eq "build") {

    # BUILD

    write_func($job, $stream, $type,
      "dir=\"data".write_dir(@{$environment->{loop_variables}->{expand}})."\";\n".
      "run_emc \"\${dir}/build\";");
  
  } elsif ($type eq "run") {

    # RUN

    write_func($job, $stream, $type,
"dir=\"data".write_dir(@{$environment->{loop_variables}->{expand}})."\";
serial=0;
frestart=0;

if [ \${fnorestart} != 1 -a -e \"\$(set_restart \"\$dir\")\" ]; then
  frestart=1;
  restart=\"\$(first \$(ls -1t \"\${RESTART[@]}\"))\";
  serial=\$(calc \$(basename \$(dirname \"\${restart}\"))+1);
fi;

case \$ichoice in 
  0)  if [ \${frestart} != 1 ]; then
	run_emc \"\${dir}/build\";
      else
	run_null;
      fi;;
  1)  serial=\$(calc \"\${serial}+\${iserial}\");
      if [ \${iserial} -gt 0 ]; then frestart=1; fi;
      run_md \\
	\"\${dir}/\$(zero 2 \${serial})\" \${frestart} \${NCORES};;
esac
");
  } elsif ($type eq "test") {

    # TEST

    write_func($job, $stream, $type, "");

  } else {

    EMC::Message::error("unsupported type \'$type\'\m");

  }
}

