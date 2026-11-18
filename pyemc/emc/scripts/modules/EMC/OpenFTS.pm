#!/usr/bin/env perl
#
#  module:	EMC::OpenFTS.pm
#  author:	Pieter J. in 't Veld
#  date:	June 2, 2026.
#  purpose:	Empty structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2026 Pieter J. in 't Veld
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
#        indicator	BOOLEAN	include "openfts_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#
#  notes:
#    20260602	Inception of v1.0
#

package EMC::OpenFTS;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::OpenFTS'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use JSON;

use EMC::Common;
use EMC::Element;
use EMC::Math;
use EMC::Options;


# defaults

$EMC::OpenFTS::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "June 2, 2026",
  version	=> "1.0"
};


# construct

sub construct {
  my $openfts = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
 
  set_functions($openfts, $attr);
  set_defaults($openfts);
  set_commands($openfts);
  return $openfts;
}


# initialization

sub set_defaults {
  my $openfts = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $openfts->{context} = EMC::Common::attributes(
    EMC::Common::hash($openfts, "context"),
    {
      focus		=> {
	clusters	=> {},
	groups		=> {},
	sites		=> {}
      }
    }
  );
  $openfts->{flag} = EMC::Common::attributes(
    EMC::Common::hash($openfts, "flag"),
    {
      active		=> 0,
      binsize		=> 1,
      compress		=> 0,
      convolute		=> 1,
      engine		=> 1,
      normalize		=> 1,
      write		=> 0,
      ignore		=> ["engine", "write"]
    }
  );
  $openfts->{defaults} = EMC::Common::attributes(
    EMC::Common::hash($openfts, "defaults"),
    {
      driver => {
	dt => 1,
	field_updater => {
	  adaptive_timestep => bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ),
	  lambdas => undef,			# [1, ...] nmasses array of ones
	  type => "EMPEC",
	  update_order => "simultaneous",
	},
	nsteps => 4000,
	output_freq => 50,
	stop_tolerance => "1e-05",
	type => "SCFT",
      },
#      fieldlayout => {
#	npw => "auto",
#	random_seed => "\@{SEED}",
#      },
      include => {
	file => "\@{INCLUDE}"			# set to project_emc.json
      },
      model => {
	Nref => 1,
	bref => 1,
	initfields => {
	  field_type => "exchange",
	  file => "\@{FILE}"			# set to project_emc.dat
	},
	type => "ChiMultiSpecies"		# needs "chi_array" from EMC
      },
      # molecules => {},			# from EMC
      monitors => {},
      operators => {
	CellStress => {
	  averaging_type => "none",
	},
	Hamiltonian => {
	  averaging_type => "none",
	},
	SpeciesFields => {
	  averaging_type => "none",
	},
      },
      output => {
	field_errors => {
	  file => "error.dat",
	},
	fields => {
	  exchange_fields => {
	    file => undef,			# set to project_fields.dat
	    save_history => do{my $o}
	  },
	  file_format => "plain_text",
	  species_densities => {
	    file => undef,			# set to project_density.dat
	    save_history => do{my $o}
	  },
	},
	scalar_operators => {
	  file => "operators.dat",
	},
      },
      # species => {}				# from EMC
    }
  );
  $openfts->{identity} = EMC::Common::attributes(
    EMC::Common::hash($openfts, "identity"),
    $EMC::OpenFTS::Identity
  );
  return $openfts;
}


sub transfer {
  my $openfts = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($openfts, "flag");
  my $context = EMC::Common::element($openfts, "context");
  
  EMC::Element::transfer(shift(@_),
    [\$::EMC::OpenFTS{dummy},		\$context->{dummy}],
  );
}


sub set_context {
  my $openfts = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($openfts, "flag");
  my $context = EMC::Common::element($openfts, "context");
}


sub set_commands {
  my $openfts = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($openfts, "set");
  my $context = EMC::Common::element($openfts, "context");
  my $flag = EMC::Common::element($openfts, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated =  $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "openfts_" : "";

  $context->{depricated} = $flag_depricated;
  $openfts->{commands} = EMC::Common::hash($openfts, "commands");
  while (1) {
    my $commands = {
      openfts		=> {
	comment		=> "OpenFTS settings",
	set		=> \&EMC::OpenFTS::set_options,
	default		=> EMC::Hash::text($flag)
      },
      $indicator."binsize"	=> {
	comment		=> "Set voxel bin size",
	set		=> \&EMC::OpenFTS::set_options,
	default		=> $flag->{binsize}
      },
      $indicator."compress"	=> {
	comment		=> "Compress data file",
	set		=> \&EMC::OpenFTS::set_options,
	default		=> EMC::Math::boolean($flag->{compress})
      },
      $indicator."convolute"	=> {
	comment		=> "Toggle convolution of volume over voxels",
	set		=> \&EMC::OpenFTS::set_options,
	default		=> EMC::Math::boolean($flag->{convolute})
      },
      $indicator."normalize"	=> {
	comment		=> "Toggle normalization of voxels",
	set		=> \&EMC::OpenFTS::set_options,
	default		=> EMC::Math::boolean($flag->{normalize})
      }
    };

    if ($flag_depricated) {
      foreach (keys(%{$commands})) {
	$commands->{$_}->{original} = $pre.$_;
      }
    }
    EMC::Options::set_command(
      $openfts->{commands} = EMC::Common::attributes(
	$openfts->{commands}, $commands
      ),
      {
	set		=> \&EMC::OpenFTS::set_options
      }
    );
    last if ($indicator eq "" || !$depricated);
    $flag_depricated = 1;
    $indicator = "";
  }
  
  EMC::Options::set_command(
    $openfts->{items} = EMC::Common::attributes(
      EMC::Common::hash($openfts, "items"),
      {
	openfts		=> {		# added "openfts" to verbatim in
	}				# EMC::Script::read()
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0,
      set		=> \&EMC::OpenFTS::set_item
    }
  );

  return $openfts;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $openfts = EMC::Common::element($struct, "module");
  my $context = EMC::Common::hash($openfts, "context");
  my $flag = EMC::Common::hash($openfts, "flag");
  my $set = EMC::Common::element($openfts, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "openfts_" : "";
  while (1) {
    if ($option eq "openfts") {
      my $result = 0;
      my @a = split("=", $args->[0]);
      if (scalar(@a)>0 || scalar(@{$args})>0) {
	EMC::Hash::set($line, $flag, "boolean", "active", [], @{$args});
	$result = $flag->{active};
      } else {
	$result = $flag->{active} = EMC::Math::flag($args->[0]);
      }
      if ($result) {
	EMC::MD::set_flags(
	  EMC::Common::element($openfts, "parent"), "write", 0);
      }
      return $flag->{write} = $result;
    }
    if ($option eq $indicator."binsize") {
      return $flag->{binsize} = EMC::Math::eval($args->[0])->[0];
    }
    if ($option eq $indicator."compress") {
      return $flag->{compress} = EMC::Math::flag($args->[0]);
    }
    if ($option eq $indicator."convolute") {
      return $flag->{convolute} = EMC::Math::flag($args->[0]);
    }
    if ($option eq $indicator."normalize") {
      return $flag->{normalize} = EMC::Math::flag($args->[0]);
    }
    last if ($indicator eq "" || !$context->{depricated});
    $indicator = "";
  }
  return undef;
}


sub set_item {
  
  # could use EMC::Script::set_item_verbatim() instead, provided
  # no merging between several 'ITEM OPENFTS' should occur
  
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
  
  my $module = EMC::Common::element($struct, "module");
  my $option = EMC::Common::element($struct, "option");
  my $data = EMC::Common::element($item, "data");

  $module->{verbatim} = $item;
  return $root;
}


sub set_functions {
  my $openfts = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($openfts, "set");
  my $write = EMC::Common::hash($openfts, "write");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&set_commands;
  $set->{context} = \&set_context;
  $set->{defaults} = \&set_defaults;
  $set->{options} = \&set_options;
  $set->{items} = \&set_items;

  $write->{emc} = \&write_emc;
  $write->{job} = \&write_job;
  $write->{script} = \&write_script;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $openfts;
}


# functions

# OpenFTS script

sub write_script {
  my $root = shift(@_);
  my $name = shift(@_);

  my $openfts = EMC::Common::element($root, "md", "openfts");
  my $flag = EMC::Common::element($openfts, "flag");

  return if (!EMC::Common::element($flag, "active"));

  write_json($root, $name);
  write_run_script($root);
}


sub write_run_script {
  my $root = shift(@_);
  my $name = "run_openfts.sh";

  my $global = EMC::Common::element($root, "global");
  my $project = EMC::Common::element($global, "project", "name");
  my $build = EMC::Common::element($root, "emc", "context", "build");

  my $identity = EMC::Common::element($global, "identity");
  my $date = EMC::Common::date_full();

  EMC::Message::info("creating OpenFTS execution script \"$name\"\n");

  my $stream = EMC::IO::open($name, "w");
  my $id = "$identity->{script} v$identity->{version}, $identity->{date}";

  chmod(0700, $name);
  printf($stream "%s",
"!/bin/bash
#
#  script:	$name
#  author:	Created by $id
#  date:	$date
#  purpose:	OpenFTS run workflow; this script is auto-generated
#

# defaults

build=\"$build->{dir}\";
include=\"".$project."_emc.json\";
init_file=\"".$project."_emc.dat\";
exchange_file=\"".$project."_field.dat\";
density_file=\"".$project."_density.dat\";
field_type=\"exchange\";
project=\"$project\";
frestart=0;
seed=-1;

# functions

run() {
  echo \"\$@\";
  \"\$@\";
}

calc() {
  perl -e \'printf(\"%%.10g\\n\",\'\$1\');\'
}

append() {
  if [ \"\$1\" == \"\" ]; then shift; fi;
  echo \"\$@\";
}

script_header() {
  echo \"Wrap-around for GROMACS; created by $id\";
  echo;
}

script_timestamp() {
  echo \"# $name \$1 at \$(date)\";
  echo;
}

script_help() {
  echo \"Usage:\";
  echo \"  $name -n nprocs [-option [value]]\";
  echo;
  echo \"Options:\";
  echo -e \"  -help\t\tthis message\";
  echo -e \"  -build\tset build directory [\${build}]\";
  echo -e \"  -project\tset project name [\${project}]\";
  echo -e \"  -restart\trestart file name [\${restart}]\";
  echo -e \"  -seed\t\tset seed [\${seed}]\";
  echo;
  exit -1;
}

init() {
  if [ \"\$1\"  == \"\" ]; then script_help; fi;
  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -help)	script_help;;
      -backup)	shift; backup=\$1;;
      -build)	shift; build=\"\$1\";;
      -n)	shift; nprocs=\$1;;
      -project)	shift; 
		project=\"\$1\";
		include=\"\${project}_emc.json\";
		init_file=\"\${project}_emc.dat\";
		exchange_file=\"\${project}_field.dat\";
		density_file=\"\${project}_density.dat\";
		;
      -frestart) shift; frestart=\"\$1\";;
      -restart)	shift; restart_file=\"\$1\";;
      -seed)	shift; seed=\$1;;
    esac;
    shift;
  done;
  error=();
  if [ \"\${nprocs}\" == \"\" ]; then
    error=(\"\${error[@]}\" \"number of processors not set\");
  fi;
  if [ \${#error[@]} != 0 ]; then
    for i in \"\${error[@]}\"; do
      echo \"ERROR: \$i\";
    done;
    echo;
    exit -1;
  fi;
  if [ \${seed} == -1 ]; then
    seed=\$(date +\%s);
  fi;
  if [ \"\${field_type}\" == \"exchange\" ]; then
    file=\"\${build}/\${file}\";
  fi;
  if [ \"\${frestart}\" != 0 ]; then
    file_type=\"species\";
    init_file=\"\${restart_file}\";
  fi;
  include=\"\${build}/\${include}\";
}

copy() {
  run cp \"\${build}/\$1_var.json\" \"\$1.json\";
  run replace.pl -q -v \@INCLUDE \${include} \"\$1.json\";
  run replace.pl -q -v \@FIELD_TYPE \${field_type} \"\$1.json\";
  run replace.pl -q -v \@INIT_FILE \${init_file} \"\$1.json\";
  run replace.pl -q -v \@EXCHANGE_FILE \${exchange_file} \"\$1.json\";
  run replace.pl -q -v \@DENSITY_FILE \${density_file} \"\$1.json\";
  run replace.pl -q -v \@SEED \${seed} \"\$1.json\";
  echo;
}

execute() {
  script_header;
  
  init \"\$@\";

  script_timestamp started;

  copy \${project};
  #mpiexec -n \${nprocs} OpenFTS.x \${project}.json;

  script_timestamp ended;
}

# main

{
  execute \"\$@\" 2>&1 | tee \${project}.out;
}
");

  EMC::IO::close($stream);
}


sub write_json {
  my $root = shift(@_);
  my $name = shift(@_)."_var.json";

  my $global = EMC::Common::element($root, "global");
  my $project = EMC::Common::element($global, "project", "name");
  my $build = EMC::Common::element($root, "emc", "context", "build");
  
  my $openfts = EMC::Common::element($root, "md", "openfts");
  my $verbatim = EMC::Common::element($openfts, "verbatim");
  my $data = EMC::Common::element($verbatim, "data");

  EMC::Message::info("creating OpenFTS input script \"$name\"\n");

  my $stream = EMC::IO::open($name, "w");

  if ($data) {
    my $json = JSON->new->allow_nonref;
    my $ptr = EMC::Hash::merge(
      EMC::Hash::copy($openfts->{defaults}),
      $json->decode(join("\n", @{$data})));

    $ptr->{include}->{file} = $build->{dir}."/".$project."_emc.json";

    #$ptr->{model}->{initfields}->{file} = $project."_emc.dat";
    $ptr->{include}->{file} = "\@{INCLUDE}";
    $ptr->{model}->{initfields}->{file} = "\@{INIT_FILE}";
    $ptr->{model}->{initfields}->{field_type}= "\@{FIELD_TYPE}";
    $ptr->{output}->{fields}->{exchange_fields}->{file} = "\@{EXCHANGE_FILE}";
    $ptr->{output}->{fields}->{species_densities}->{file} = "\@{DENSITY_FILE}";

    printf($stream "%s", $json->canonical->pretty->encode($ptr));
  }
  EMC::IO::close($stream);
}


# EMC script additions

sub write_emc {
  my $openfts = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $emc_flag = EMC::Common::element($root, "emc", "flag");
  my $global = EMC::Common::element($root, "global");
  my $field = EMC::Common::element($root, "fields", "field");
  my $context = EMC::Common::element($openfts, "context");
  my $flag = EMC::Common::element($openfts, "flag");
  my $md = EMC::Common::element($openfts, "parent");

  return if (!EMC::Common::element($flag, "active"));

  printf($stream
    "\nopenfts\t\t= {name -> output, ");
  printf($stream
    "binsize -> $flag->{binsize}, ");
  printf($stream
    "seed -> seed,\n");
  printf($stream
    "\t\t   compress -> %s, ", EMC::Math::boolean($flag->{compress}));
  printf($stream
    "convolute -> %s, ", EMC::Math::boolean($flag->{convolute}));
  printf($stream
    "normalize -> %s", EMC::Math::boolean($flag->{normalize}));
  printf($stream "};\n");
}


# BASH jobs workflow additions

sub write_job {
  my $openfts = shift(@_);
  my $root = shift(@_);

  my $stream = EMC::Common::element($root, "io", "stream");
  my $global = EMC::Common::element($root, "global");
  my $context = EMC::Common::element($openfts, "context");
  my $flag = EMC::Common::element($openfts, "flag");
  my $project = EMC::Common::element($global, "project", "name");

  return if (!(defined($flag) && $flag->{write}));

  my $md = EMC::Common::element($root, "md", "context");
  my $md_flag = EMC::Common::element($root, "md", "flag");
  my $restart_dir = EMC::Common::element($md, "restart_dir");
  my $restart_name = "\${restart_dir}/*/".$project."_density.dat";
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

  printf($stream
"run_md() {
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
    if [ ! -e \${build}/".$project."_emc.dat ]; then
      printf \"# ../build/".$project."_emc.dat does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${build}/".$project."_emc.json ]; then
      printf \"# ../build/".$project."_emc.json does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${build}/".$project."_var.json ]; then
      printf \"# ../build/".$project."_var.json does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${build}/run_openfts.sh ]; then
      printf \"# ../build/run_openfts.sh does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
  fi;

  if [ \${freplace} != 1 ]; then
    if [ \${frestart} != 1 ]; then
      if [ -e \${dir}/*_density.dat ]; then
	printf \"# ".$project."_density.dat exists -> skipped\\n\\n\";
	run_null;
	return;
      fi;
    else
      restart=\"-file \${restart_dir}\'/*/*_density.dat\'\";".
      $restart_file."
      if [ \${ferror} == 1 ]; then
	if [ -e \"\$(first \${restart_dir}/*/$project.out)\" ]; then
	  file=\$(first \$(ls -1t \${restart_dir}/*/$project.out));
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
  set -f;
  WALLTIME=\${RUN_WALLTIME};
  run_pack -n \${ncores} -dir \"\${dir}\" \"\${restart}\" \\
    -walltime \${RUN_WALLTIME} -starttime \${START_TIME} -queue \${QUEUE} \\
    -input \${source}/$project.in -output $project.out \\
    -project $project \\
      run_openfts.sh \\
	-project \${project} \\
	-frestart \${frestart} \\
	-restart \@FILE \\
	-seed \$(substr \${SEED} -8) \\
  set +f;

  SEED=\$(calc \${SEED}+1);
  run cd \"\${WORKDIR}\";
  echo;
}

set_restart() {
  RESTART=(\$1/*/*_density.dat);
  echo \"\${RESTART[0]}\";
}

"); 
}

