#!/usr/bin/env perl
#
#  script:	emc_opls.pl
#  author:	Pieter J. in 't Veld
#  date:	November 15-30, December 1-19, 2024.
#  purpose:	OPLS parameter conversion into EMC readable force field files
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  notes:
#    20241115	- Inception
#    		- Uses EMC modules Atoms, Fields, Increments, Residues,
#    		  and Rules
#

use strict;

# Identity

$::EMC_OPLS::Identity = {
  version		=> "2.0",
  date			=> "December 19, 2024",
  author		=> "Pieter J. in 't Veld",
};

# Module initialization

BEGIN {
  use File::Basename;
  if (-d dirname($0)."/modules") {
    $::EMC::Modules{dir} = dirname($0)."/modules";
  } else {
    $::EMC::Modules{dir} = $ENV{EMC_ROOT}."/scripts/modules";
  }
  if (! -d $::EMC::Modules{dir}) {
    print("Error: cannot locate modules directory: set EMC_ROOT?\n\n");
    exit(-1);
  }
}
use lib $::EMC::Modules{dir};

use EMC;

# functions

# registration

sub construct {
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::hash($root, "global");
  my $modules = {
    fields => [\&EMC::Fields::construct, {indicator => 0, special => 1}],
    message => [\&EMC::Message::construct, {commands => 1}]
  };

  foreach (keys(%{$modules})) {
    my $ptr = $modules->{$_};
    $root->{$_} = $ptr->[0]->(EMC::Common::element($root, $_), $ptr->[1]);
  }

  set_functions($root);
  set_identity($root);
  set_commands($root);
  set_defaults($root);

  EMC::Options::transcribe($root);

  return $root;
}


# initialization

sub set_identity {
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::hash($root, "global");
  
  $global = EMC::Common::attributes(
    EMC::Common::hash($global),
    {
      identity		=> {
	main		=> "OPLS",
	script		=> basename($0),
	name		=> "Conversion",
	version		=> $::EMC_OPLS::Identity->{version},
	date		=> $::EMC_OPLS::Identity->{date},
	author		=> $::EMC_OPLS::Identity->{author},
	copyright	=> "2004-".EMC::Common::date_year(),
	command_line	=> "[-option[=#]] project"
      }
    }
  );
  return $root;
}


sub set_defaults {
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::hash($root, "global");
  my $field = EMC::Fields::assign_field(EMC::Common::hash($root, "field"));

  $global->{flags} = EMC::Common::attributes(
    EMC::Common::hash($global, "flags"),
    {
      compress		=> 0,
      mass		=> 0,
      input		=> "oplsaa",
      lower		=> 1,
      offset		=> 135,
      output		=> "-",
      project		=> undef,
      rules		=> "-",
      show		=> 0,
      source		=> ".",
      special		=> 2000,
      target		=> ".",
      valid		=> ["HW", "OW", "LP"],
      united		=> 0,
      wildcards		=> [],
      xref		=> 0
    }
  );
  $field->{define}->{data} = EMC::Common::attributes(
    $field->{define}->{data},
    {
      FFMODE		=> "OPLS",
      VERSION		=> "JAN 2007"
    }
  );
  return $root;
}


sub set_commands {
  my $global = shift(@_);
  my $root = EMC::Common::hash(defined(@_[0]) ? shift(@_) : $global);
  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");

  init_output($root);
  $global->{commands} = EMC::Common::attributes(
    EMC::Common::hash($global, "commands"),
    {
      compress		=> {
	comment		=> "compress output",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{compress})
      },
      help		=> {
	comment		=> "this message",
	set		=> \&EMC::Options::set_help,
      },
      ignore		=> {
	comment		=> "ignore incorrect options",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{ignore})
      },
      input		=> {
	comment		=> "set input file base name",
	set		=> \&set_options,
	default		=> $flags->{input}
      },
      lower		=> {
	comment		=> "force lower case types",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{lower})
      },
      mass		=> {
	comment		=> "output mass conversion table",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{mass})
      },
      offset		=> {
	comment		=> "set offset start for all-atom parameters",
	set		=> \&set_options,
	default		=> $flags->{offset}
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
      show		=> {
	comment		=> "show indermediate results",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{show})
      },
      source		=> {
	comment		=> "set source directory",
	set		=> \&set_options,
	default		=> $flags->{source}
      },
      special		=> {
	comment		=> "set special substance start index",
	set		=> \&set_options,
	default		=> $flags->{special}
      },
      target		=> {
	comment		=> "set target directory",
	set		=> \&set_options,
	default		=> $flags->{target}
      },
      united		=> {
	comment		=> "interpret as united atoms",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{united})
      },
      wildcards		=> {
	comment		=> "transfer type to wildcard for bonded contributions",
	set		=> \&set_options,
	default		=> EMC::List::string($flags->{wildcards}, {parens => 0})
      },
      xref		=> {
	comment		=> "output xref table",
	set		=> \&set_options,
	default		=> EMC::Math::boolean($flags->{xref})
      }
    }
  );
  $global->{notes} = [
    "'-' as output denotes STDOUT"
  ];
  return $root;
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
  } elsif ($option eq "ignore") {
    return $flags->{ignore} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "input") {
    return $flags->{input} = $args->[0];
  } elsif ($option eq "lower") {
    return $flags->{lower} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "mass") {
    return $flags->{mass} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "offset") {
    return $flags->{offset} = EMC::Math::eval($args->[0])->[0];
  } elsif ($option eq "output") {
    return $flags->{output} = $args->[0];
  } elsif ($option eq "show") {
    return $flags->{show} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "source") {
    return $flags->{source} = EMC::IO::scrub_dir($args->[0]);
  } elsif ($option eq "special") {
    return $flags->{special} = EMC::Math::eval($args->[0])->[0];
  } elsif ($option eq "target") {
    return $flags->{target} = EMC::IO::scrub_dir($args->[0]);
  } elsif ($option eq "united") {
    return $flags->{united} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "xref") {
    return $flags->{xref} = EMC::Math::flag($args->[0]);
  } elsif ($option eq "wildcards") {
    $flags->{wildcards} = [split(",", $args->[0])];
    return scalar(@{$flags->{wildcards}});
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
    option => "message_quiet", emc => $root, args => $args});
}


sub set_functions {
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::hash($root, "global");
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
  return $root;
}


sub initialize {
  my $root = construct({files => []});
  my $struct = {root => $root, line => -1};
  my $global = $root->{global};
  my $flags = $global->{flags};
  my $result = undef;
  my $project = 0;

  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @arg = split("=", substr($_,1));
      $struct->{option} = shift(@arg);
      $struct->{args} = [@arg];
      $result = EMC::Options::set_options($root->{options}, $struct);
      #if (defined($result) ? 0 : $flags->{ignore} ? 0 : 1) {
      if (defined($result) ? 0 : 1 ? 0 : 1) {
	EMC::Options::set_help($struct);
      }
    } else {
      #my @found = EMC::IO::find($flags->{source}, $_);
      #push(@{$root->{files}}, @found) if (scalar(@found));
      push(@{$root->{files}}, $_);
      $project = 1;
    }
  }
  EMC::Options::set_help($struct) if (!$project);
  if (!scalar(@{$root->{files}})) {
    EMC::Options::header($root->{options});
    EMC::Message::error("no files found.\n");
  }
  set_quiet($root) if ($flags->{output} eq "-");
  $flags->{project} = shift(@{$root->{files}});
  $flags->{output} = $flags->{project} if (!$flags->{mass});
  init_output($root);
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
  if (substr($flags->{output}, -4) eq ".prm") {
    $flags->{output} = substr($flags->{output}, 0, length($flags->{output})-4);
  }
  if ($flags->{output} ne "-") {
    $flags->{rules} = $flags->{output}.".top";
    $flags->{rules} .= ".gz" if ($flags->{compress});
    $flags->{output} .= ".prm";
    $flags->{output} .= ".gz" if ($flags->{compress});
  }
}


# import i/o

sub get_par {
  my $root = shift(@_);
  my $name = shift(@_);

  my $parameters = EMC::Common::hash($root, "parameters");
  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");
  my $table = EMC::Mass::list();
  
  my $allowed = EMC::List::hash($flags->{valid});
  my $input = EMC::IO::open($name, "r", {warn => 1});
  my $imode = 0;
  my $mode = 0;

  return if (!defined($input));
  EMC::Message::info("reading '$name'\n");
  foreach (<$input>) {
    next if (substr($_,0,1) eq '#');
    next if (substr($_,0,1) eq '*');

    my @arg = split(" ");
    my $index = shift(@arg);
 
    next if (!scalar(@arg));
    $mode = 0 if (lc(join(" ", $index, @arg[0..1])) eq "do not modify");
    if ($mode==0) {
      $mode = ++$imode if (EMC::Math::number_q($index));
    }
    $index *= 1;
    if ($mode==1) {
      next if (scalar(@arg)<5);
      next if (substr($_,5,5) eq "     ");
      my $masses = EMC::Common::hash($parameters, "masses");
      my $nonbonds = EMC::Common::hash($parameters, "nonbonds");
      my $indices = EMC::Common::hash($parameters, "indices");
      my $id = shift(@arg);
      my $type = shift(@arg);
      my $charge = eval(shift(@arg));
      my $sigma = eval(shift(@arg));
      my $epsilon = eval(shift(@arg));
      my $comment = join(" ", @arg);
      my $entry = uc($type) eq "LP" ? $table->[0] : $table->[$id];

      if (!defined($allowed->{$type})) {
	next if ($index<54);
	next if ($flags->{united} ?
	  $index>=$flags->{offset} : $index<$flags->{offset});
      }
      next if (uc($type) eq "DM");
      $sigma = 1.0 if ($sigma == 0 && $entry->{element} eq "H");
      $id = 0 if (uc($type) eq "LP");
      $comment =~ s/\"//g;
      $comment =~ s/^\s+|\s+$//g;
      if (!defined($masses->{$type})) {
	$masses->{$type} = {
	  index => $index,
	  element => $entry->{element},
	  mass => $entry->{mass},
	  comment => $comment};
      }
      my $list = EMC::Common::list(
	  $nonbonds, $type, join("\t", $sigma, $epsilon));
      push(@{$list}, $index);
      if (!defined($indices->{$index})) {
	my $entry = EMC::Common::hash($indices, $index);
	$entry->{charge} = $charge;
	$entry->{comment} = $comment;
	$entry->{original} = $type;
	$entry->{xref} = $list->[0];
      }
    } elsif ($mode==2) {
      my $torsions = EMC::Common::hash($parameters, "torsion");
      my $impropers = EMC::Common::hash($parameters, "improper");
      my @v = (shift(@arg), shift(@arg), shift(@arg), shift(@arg));
      my $s = join(" ", @arg);
      my @type = map({EMC::Common::trim($_)}
	substr($s,0,2), substr($s,3,2), substr($s,6,2), substr($s,9,2));
      my $comment = EMC::Common::trim(substr($s,11));

      @v = map({eval($_)} @v);
      if ($comment =~ m/improper/) {
	@type[0,1] = @type[1,0];
	push(
	  @{EMC::Common::list($impropers,
	    EMC::Fields::arrange_imp(@type))}, @v);
      } else {
	push(
	  @{EMC::Common::list($torsions,
	    EMC::Fields::arrange(@type))}, @v);
      }
    }
  }
  EMC::IO::close($input, $name);
}


sub get_sb {
  my $root = shift(@_);
  my $name = shift(@_);
  my $input = EMC::IO::open($name, "r", {warn => 1});
  my $parameters = EMC::Common::hash($root, "parameters");

  return if (!defined($input));
  EMC::Message::info("reading '$name'\n");
  foreach (<$input>) {
    next if (substr($_,0,1) eq '#');
    next if (substr($_,0,1) eq '*');

    my @type = ();
    push(@type, substr($_,0,2), substr($_,3,2)) if (substr($_,2,1) eq "-");
    push(@type, substr($_,6,2)) if (substr($_,5,1) eq "-");
    next if (!scalar(@type));
    @type = map({EMC::Common::trim($_)} @type);

    my @arg = split(" ", substr($_, scalar(@type)*3, -1));
    my @par = (eval(shift(@arg)), eval(shift(@arg)));
    my $comment = join(" ", @arg);

    my $ptr = EMC::Common::list(
      $parameters,  scalar(@type)==2 ? "bond" : "angle",
      EMC::Fields::arrange(@type));
    @{$ptr} = (@par, "! ".$comment);
  }
  EMC::IO::close($input, $name);
}


sub get_parameters {
  my $root = shift(@_);
  my $field = EMC::Common::hash($root, "field");
  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");
  
  my $source = $flags->{source};
  my $name = $flags->{input};

  get_par($root, $source."/".$name.".par");
  get_sb($root, $source."/".$name.".sb");
}


sub transfer_parameters {
  my $root = shift(@_);
  my $field = EMC::Common::hash($root, "field");
  my $wildcards = EMC::Common::hash($root, "global", "flags", "wildcards");
  my $parameters = EMC::Common::hash($root, "parameters");
  my $types = EMC::Common::hash($parameters, "types");

  my @original = sort(keys(%{$types}));
  my $bonded = {bond => 2, angle => 3, torsion => 4, improper => 4};
  my $nconstants = {bond => 2, angle => 2, torsion => 4, improper => 2};

  foreach (sort(keys(%{$bonded}))) {
    my $key = $_;
    my $data = EMC::Common::element($parameters, $key);
    my $normal = EMC::Common::hash($field, $key);
    my $auto = EMC::Common::hash($field, $key."_auto");
    my $arrange = $key eq "improper" ?
      \&EMC::Fields::arrange_imp : \&EMC::Fields::arrange;

    next if (!defined($data));

    my $ptr = [$data];
    my $keys = [[sort(keys(%{$data}))]];
    my $n = $bonded->{$key};
    my @key;

    EMC::Message::info("transfering $key parameters\n");
    for (my $i=1; $i<$n; ++$i) { 
      push(@{$keys}, []);
    }
    while (1) {
      my $i = 0; 					# terminate
      foreach (@{$keys}) {
       	$i += scalar(@{$_});
      }
      last if (!$i);
      
      for ($i=1; $i<$n; ++$i) { 			# advance
	last if(scalar(@{$keys->[-$i]}));
      }
      $i = $n-$i+1;
      @key[$i-1] = shift(@{$keys->[$i-1]});
      for (; $i<$n; ++$i) { 
	$ptr->[$i] = $ptr->[$i-1]->{@key[$i-1]};
	$keys->[$i] = [sort(keys(%{$ptr->[$i]}))];
	@key[$i] = shift(@{$keys->[$i]});
      }
      $ptr->[$i] = $ptr->[$i-1]->{@key[-1]};

      next if (ref($ptr->[-1]) ne "ARRAY");

      my $success = 1;					# apply
      my @type = @key;
      my $select = $normal;
      my $content = EMC::List::take([@{$ptr->[-1]}], $nconstants->{$key});

      foreach (@type) {					# check for wildcards
	if ($_ =~ m/\?/) {
	  $_ =~ s/\?\?/\*/g;
	  if (substr($_,0,1) ne "?") {			# wildcard
	    $_ =~ s/\?/\*/g;				# wildcard at end
	    $_ = lc($_);
	  } else {
	    my @l;					# wildcard at begin
	    my $c = substr($_,1);
	    foreach(@original) {
	      push(@l, $types->{$_}) if (substr($_,1) eq $c);
	    }
	    $_ = [@l];
	  }
	  $select = $auto;
	} else {
	  if (!defined($types->{$_})) {			# cross-reference
	    $success = 0;
	    last;
	  }
	  $_ = $types->{$_};
	}
      }
      next if (!$success);				# abandon upon failure

      if ($key eq "torsion") {				# convert parameters
	my @k;
	for (my $i=0; $i<4; ++$i) {
	  my $v = eval($content->[$i]);
	  next if (!$v);
	  push(@k, $v, $i+1, 0);
	}
	@{$content} = scalar(@k) ? @k : (0, 1, 0);
      } elsif ($key eq "improper") {			# swap for improper
	@{$content}[0,1] = @{$content}[1,0];
      }
      while ($success) {
	foreach (@{EMC::List::permutations(\@type)}) {	# assign content
	  next if (EMC::Common::element($select, "data", @{$_}));
	  @{EMC::Common::list($select, "data", @{$_})} = @{$content};
	}
	$select = $auto;
	$success = 0;
	foreach (@{$wildcards}) {
	  my $wildcard = $_;
	  foreach (@type) {
	    next if ($_ ne $wildcard);
	    $_ = $wildcard."*";
	    $success = 1;
	  }
	}
      }
    }
  }
}


sub xref_parameters {
  my $root = shift(@_);
  my $xref = EMC::Common::hash($root, "parameters", "xref");
  my $indices = EMC::Common::hash($root, "parameters", "indices");

  foreach (keys(%{$indices})) {
    my $index = $indices->{$_};
    $index->{type} = $xref->{$index->{xref}};
  }
  return $root;
}


# import and interpret define

sub get_define {
  my $root = shift(@_);

  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");

  my $item = {
    define => {
      func => \&EMC::Fields::item_define
    },
    references => {
      func => \&EMC::Fields::item_references, info => "reading references\n"
    },
    mass => {
      func => \&item_mass, info => "defining masses\n"
    },
    equivalence => {
      func => \&EMC::Fields::item_equivalence, info => "defining equivalence\n"
    },
    increment => {
      func => \&EMC::Fields::item_increment, info => "defining increment\n"
    },
    bond => {
      func => \&EMC::Fields::item_bonded, info => "defining bonds\n"
    },
    angle => {
      func => \&EMC::Fields::item_bonded, info => "defining angles\n"
    },
    torsion => {
      func => \&EMC::Fields::item_bonded, info => "defining torsions\n"
    },
    improper => {
      func => \&EMC::Fields::item_bonded, info => "defining impropers\n"
    },
    stream => {
      func => \&EMC::Residues::item_stream, info => "defining residues\n"
    },
    rules => {
      func => \&EMC::Rules::item_rules, info => "reading rules\n"
    }
  };
  my @order = ("equivalence", "mass", "bond", "angle", "torsion", "improper");

  my $name = $flags->{project}.".define";

  EMC::Message::info("reading '$name'\n");

  my $stream = EMC::IO::open($name, "r");
  my $items = EMC::Item::read($stream);
  my $attr = {
    root => $root,
    flags => $flags,
    field => EMC::Common::hash($root, "field"),
    residues => EMC::Common::hash($root, "residues"),
    rules => EMC::Common::hash($root, "residues", "rules"),
    override => EMC::Common::hash($root, "residues", "override")
  };

  EMC::IO::close($stream, $name);
  foreach (@order, sort(keys(%{$items}))) {
    next if (defined($item->{$_}->{visited}));
    if (defined($item->{$_}->{info})) {
      EMC::Message::info($item->{$_}->{info});
    }
    $attr->{index} = $_;
    $item->{$_}->{func}->($items, $attr);
    $item->{$_}->{visited} = 1;
  }
}


sub item_mass {
  my $items = shift(@_);
  my $attr = shift(@_);
  my $lower = EMC::Common::element($attr, "flags", "lower");

  my $root = EMC::Common::element($attr, "root");
  my $field = EMC::Common::element($attr, "field");
  my $index = EMC::Common::element($attr, "index");
  my $data = EMC::Common::element($items, $index, "data");
  my $lines = EMC::Common::element($items, $index, "lines");

  return if (!($root && $field && $index && $data && $lines));

  my $mass = EMC::Common::hash($field, "mass");
  my $nonbond = EMC::Common::hash($field, "nonbond");
  my $equivalence = EMC::Common::hash($field, "equivalence");

  my $xref = EMC::Common::hash($root, "parameters", "xref");
  my $types = EMC::Common::hash($root, "parameters", "types");

  my $tmp = {};
  my $line = -1;
  my $fdest = {pair => 1, incr => 1};
  my $id = EMC::List::hash([
      "dest", "src", "mass", "element", "ncons", "index", "charge",
      "sigma", "epsilon", "comment"
    ]
  );

#  my $sorted = [
#    sort(
#      {
#	substr($a->[0],0,2) ne substr($b->[0],0,2) ? $a->[0] cmp $b->[0] :
#	$a->[1] ne $b->[1] ? $a->[1] cmp $b->[1] :
#	$a->[0] cmp $b->[0]
#      } 
#      @{$data})];

#  foreach (@{$sorted}) {
#    EMC::Message::tprint(@{$_}[0,1,7,8,9]);
#  }
#  exit();

  foreach (@{$data}) {						# retyping
    my $arg = EMC::List::extract("", @{$_}, {not => 1});

    next if (ref($arg) ne "ARRAY");
    next if (substr($arg->[0],0,1) eq "#");
    next if (defined($types->{$arg->[1]}));
    $types->{$arg->[1]} = $lower ? lc($arg->[0]) : $arg->[0];
  }

  foreach (@{$data}) {						# storage
    my $arg = EMC::List::extract("", @{$_}, {not => 1});
    my $ncons = $arg->[$id->{ncons}];

    ++$line;
    next if (ref($arg) ne "ARRAY");
    if (substr($arg->[0],0,1) eq "#") {
      $arg->[0] = EMC::Common::trim(substr($arg->[0],1));
      $id = EMC::Common::attributes($id, EMC::List::hash($arg));
      next;
    }
    if (scalar(@{$arg}!=10)) {
      EMC::Message::error_line($lines->[$line],
       	"incorrect number of entries\n");
    }
    $arg->[0] = $lower ? lc($arg->[0]) : $arg->[0];
    $arg->[1] = $types->{$arg->[1]};
    $xref->{$arg->[$id->{index}]} = $arg->[0];
    foreach ("mass", "nonbond", "equivalence") {
      my $key = $_;
      my $entry = EMC::Common::hash($field, $key);
      my $index = EMC::Common::list($entry, "index");
      my $flag = $key eq "equivalence" ? 1 : 0;
      my @type = $key eq "nonbond" ? ($arg->[0], $arg->[0]) : ($arg->[0]);
      
      next if ($flag && EMC::Common::element($entry, "data", @type));

      my $list = EMC::Common::list($entry, "data", @type);
      foreach (@{$index}) {
	next if (substr($_,0,4) eq "type");
	if ($flag) {
	  push(@{$list}, $arg->[$fdest->{$_} ? 0 : $ncons ? 1 : 0]);
	} else {
	  push(@{$list}, $arg->[$id->{$_}]);
	}
      }
    }
  }
  transfer_parameters($root);
}


# parameter output

# analysis 

sub put_define_mass {
  my $root = shift(@_);
  my $name = shift(@_);

  my $parameters = EMC::Common::hash($root, "parameters");
  my $nonbonds = EMC::Common::element($parameters, "nonbonds");
  my $indices = EMC::Common::element($parameters, "indices");
  my $masses = EMC::Common::element($parameters, "masses");
  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");

  return if (!$flags->{mass} || !defined($nonbonds));
  $name = $flags->{output} if (!defined($name));
  
  my $stream = EMC::IO::open($name, "w");

  EMC::Message::info("writing mass to '$name'\n");
  
  print($stream "ITEM\tMASS\n\n");
  print($stream "# dest\tsrc\tmass\telement\tncons\tindex\tcharge\tsigma\tepsilon\tcomment\n\n");
  
  foreach (sort(keys(%{$nonbonds}))) {
    my $type = $_;
    my $p = $nonbonds->{$type};
    my $m = $masses->{$type};

    my @keys = sort({
	scalar(@{$p->{$a}})==scalar(@{$p->{$b}}) ? $a cmp $b :
	  scalar(@{$p->{$b}})<=>scalar(@{$p->{$a}})} keys(%{$p}));
    
    foreach (@keys) {
      my $a = $p->{$_};
      my $comment = $indices->{$a->[0]}->{comment};
      print($stream 
	join("\t",
	  $type, $type, $m->{mass}, $m->{element},
	  "-", "$a->[0]", 0, $_, $comment), "\n");
    }
  }

  print($stream "\nITEM\tEND\n");
  EMC::IO::close($stream, $name);
}


sub put_xref {
  my $root = xref_parameters(shift(@_));
  my $flags = EMC::Common::hash($root, "global", "flags");
  my $indices = EMC::Common::hash($root, "parameters", "indices");

  my $name = $flags->{project}.".xref";

  EMC::Message::info("writing cross-reference to '$name'\n");

  my $stream = EMC::IO::open($name, "w");
  my $order = ["xref", "original", "type", "charge", "comment"];

  print($stream "# index");
  foreach (@{$order}) {
    print($stream "\t", $_ eq "original" ? "orig" : $_);
  }
  print($stream "\n\n");
  foreach (sort({$a <=> $b} keys(%{$indices}))) {
    my $index = $indices->{$_};

    print($stream join("\t", $_, map({$index->{$_}} @{$order})), "\n");
  }
  EMC::IO::close($stream, $name);
}


# force field output

sub put_header {
  my $stream = shift(@_);
  my $root = EMC::Common::hash(shift(@_));
  my $type = shift(@_);

  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");
  my $identity = EMC::Common::hash($root, "global", "identity");

  my $name = $flags->{project}.".define";

  print($stream "#EMC/FIELD/OPLS/".EMC::Common::date_year()."
#
#  OPLS $type using oplsaa.par, oplsaa.sb, and $name
#  converted by $identity->{script}, v$identity->{version}, $identity->{date} by $identity->{author}
#  created on ".EMC::Common::date_full()."
#
#  Copyrights (c) 2004-".EMC::Common::date_year()." Pieter J. in 't Veld
#  Distributed under GNU Public License v3.0 as stated in the LICENSE file in
#  the EMC root directory
#

");
}


# parameters

sub put_parameters {
  my $root = shift(@_);
  
  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");
  
  my $name = $flags->{output};
  my $field = {};

  foreach (keys(%{$root->{field}})) {			# filter out empty
    my $ptr = $root->{field}->{$_};

    next if (ref($ptr) eq "HASH" && !defined($ptr->{data}));
    $field->{$_} = $ptr;
  }
  
  EMC::Message::info("writing parameters to '$name'\n");

  my $stream = EMC::IO::open($name, "w");		# write field

  put_header($stream, $root, "parameters");

  EMC::Fields::write($stream, $field);
  EMC::IO::close($stream, $name);
}


# topology

sub put_topology {
  my $root = shift(@_);

  my $global = EMC::Common::hash($root, "global");
  my $flags = EMC::Common::hash($global, "flags");
  my $field = EMC::Common::element($root, "field");
  my $residues = EMC::Common::hash($root, "residues");

  my $name = $flags->{rules};

  EMC::Message::info("writing topology to '$name'\n");

  my $stream = EMC::IO::open($name, "w");

  put_header($stream, $root, "topology");
  EMC::Residues::write_precedence($stream, $residues);
  EMC::Residues::write_rules($stream, $residues, {
      field => $field, residues => $residues});
  EMC::Residues::write_templates($stream, $residues);

  EMC::IO::close($stream, $name);
}


# main

{
  my $root = initialize(@ARGV);
  my $flags = EMC::Common::hash($root, "global", "flags");

  EMC::Options::header($root->{options});
  get_parameters($root);
  if ($flags->{mass}) {
    put_define_mass($root);
  } else {
    get_define($root);
    put_topology($root);
    put_parameters($root);
    put_xref($root) if ($flags->{xref});
  }
  EMC::Message::message("\n");
}

