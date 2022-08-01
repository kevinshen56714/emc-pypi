#!/usr/bin/env perl
#
#  module:	EMC::Field.pm
#  author:	Pieter J. in 't Veld
#  date:	December 25, 2021, January 15, 2022.
#  purpose:	Field routines; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
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
#        indicator	BOOLEAN	include "field_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    data		HASH	field data
#      type			data types
#	[type]
#	  [...]
#	    keyword1		data descriptors
#	    [keyword2]
#
#    flag		HASH
#      array		BOOLEAN	data as array of hashed in case of indexation
#      index		ARRAY	index descriptors
#      ntypes		INTEGER	number of types
#      table  		BOOLEAN	data contains a table
#
#    index		ARRAY
#      type1		STRING	type 1
#      [type2]		STRING	type 2
#      [...]			...
#      keyword1		STRING	constant 1 keyword
#      [keyword2]	STRING	constant 2 keyword
#      [...]
#
#
#  notes:
#    20211225	Inception of v1.0
#    20220115	Inclusion of commands, defaults, and functions
#

package EMC::Field;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Common;
use EMC::Item;
use EMC::Struct;


# defaults 

$EMC::Field::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "January 15, 2022",
  version	=> "1.0"
};

$EMC::Field::Guide = {
  index => [
    "header", "define", "references", "mass", "precedence", "rules",
    "templates", "equivalence", "increment", "nonbond", "bond", "angle",
    "torsion", "improper"],
  table => {
    nonbond => 1, bond => 1, angle => 1, torsion => 1, improper => 1},
  auto => {
    equivalence => 1, bond => 1, angle => 1, torsion => 1, improper => 1},
  ntypes => {
    define => 1, mass => 1, equivalence => 1, nonbond => 2, increment => 2,
    bond => 2, angle => 3, torsion => 4, improper => 4, cmap => 5}
};

$EMC::Field::Options = {
  angle => {
    error => 1, ignore => 1, warn => 1},
  density => {
    "g/cc" => 1, "kg/m^3" => 1, "reduced" => 1},
  energy => {
    "j/mol" => 1, "kj/mol" => 1, "cal/mol" => 1, "kcal/mol" => 1,
    "kelvin" => 1, "reduced" => 1},
  length => {
    angstrom => 1, nanometer => 1, micrometer => 1, meter => 1,
    reduced => 1},
  mix => {
    none => 1, berthelot => 1, arithmetic => 1, geometric => 1,
    sixth_power => 1},
  fftype => {
    atomistic => 1, united => 1, coarse => 1},
  torsion => {
    error => 1, ignore => 1, warn => 1},
};


# construct

sub construct {
  my $field = EMC::Common::obtain_hash(shift(@_));
  my $attr = shift(@_);
  
  set_functions($field, $attr);
  set_defaults($field);
  set_commands($field);
  return $field;
}


# initialization

sub set_defaults {
  my $field = EMC::Common::obtain_hash(shift(@_));

  $field = {} if (!defined($field));
  $field->{define} = EMC::Common::attributes(
    EMC::Common::obtain_hash($field, "define"),
    {
      angle		=> "warn",
      density		=> "g/cc",
      energy		=> "kcal/mol",
      ffapply		=> "all",
      ffmode		=> "table",
      fftype		=> "coarse",
      length		=> "angstrom",
      nbonded		=> "1",
      torsion		=> "warn",
      version		=> "1.0"
    }
  );
  $field->{identity} = EMC::Common::attributes(
    EMC::Common::obtain_hash($field, "identity"),
    $EMC::Field::Identity
  );
  return $field;
}


sub set_commands {
  my $field = EMC::Common::obtain_hash(shift(@_));
  my $set = EMC::Common::element($field, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  
  $indicator = $indicator ? "field_" : "";
  $field->{commands} = EMC::Common::attributes(
    EMC::Common::obtain_hash($field, "commands"),
    {
      $indicator."angle"	=> {
	comment		=> "field error handling for angles",
	set		=> \&EMC::Field::set_options,
	default		=> $field->{define}->{angle}
      },
      $indicator."energy"	=> {
	comment		=> "field units of energy",
	set		=> \&EMC::Field::set_options,
	default		=> $field->{define}->{energy}
      },
      $indicator."length"	=> {
	comment		=> "field units of length",
	set		=> \&EMC::Field::set_options,
	default		=> $field->{define}->{length}
      },
      $indicator."nbonded"	=> {
	comment		=> "number of bonded sites",
	set		=> \&EMC::Field::set_options,
	default		=> $field->{define}->{nbonded}
      },
      $indicator."torsion"	=> {
	comment		=> "field error handling for torsions",
	set		=> \&EMC::Field::set_options,
	default		=> $field->{define}->{torsion}
      },
      $indicator."version"	=> {
	comment		=> "field version",
	set		=> \&EMC::Field::set_options,
	default		=> $field->{define}->{version}
      }
    }
  );
  return $field;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $emc = EMC::Common::element($struct, "emc");
  my $field = EMC::Common::obtain_hash($emc, "field");
  my $define = EMC::Common::obtain_hash($field, "define");
  my $set = EMC::Common::element($field, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "field_" : "";
  if ($option eq $indicator."angle") {
    return $define->{angle} = EMC::Field::set_select($struct);
  } elsif ($option eq $indicator."density") {
    return $define->{density} = EMC::Field::set_select($struct);
  } elsif ($option eq $indicator."energy") {
    return $define->{energy} = EMC::Field::set_select($struct);
  } elsif ($option eq $indicator."length") {
    return $define->{length} = EMC::Field::set_select($struct);
  } elsif ($option eq $indicator."nbonded") {
    return $define->{nbonded} =
	EMC::Math::bound(int(EMC::Math::eval($args->[0])->[0]), 0, 3);
  } elsif ($option eq $indicator."torsion") {
    return $define->{torsion} = EMC::Field::set_select($struct);
  } elsif ($option eq $indicator."version") {
    return $define->{version} = $args->[0];
  }
  return undef;
}


sub set_select {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");

  if (defined($EMC::Field::Options->{$option})) {
    if (defined($EMC::Field::Options->{$option}->{$args->[0]})) {
      return $args->[0];
    }
    EMC::Message::error_line([$file, $line], "illegal argument '$args->[0]'");
  }
  EMC::Message::error_line([$file, $line], "illegal option '$option'");
}


sub set_functions {
  my $field = EMC::Common::obtain_hash(shift(@_));
  my $attr = EMC::Common::attributes(@_);
  my $set = EMC::Common::obtain_hash($field, "set");
  my $flags = {"commands" => 1, "indicator" => 1};

  $set->{commands} = \&EMC::Field::set_commands;
  $set->{defaults} = \&EMC::Field::set_defaults;
  $set->{options} = \&EMC::Field::set_options;
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $field;
}


# functions

sub compare {
  return 0 if (@_[0] eq "*");
  return 1 if (@_[1] eq "*");
  return @_[0] lt @_[1] ? 1 : 0;
}


sub arrange {
  return @_ if (scalar(@_)<2);
  return @_ if (compare(@_[0, -1]));
  if (@_[0] eq @_[-1]) {
    return @_ if (scalar(@_)<4);
    return @_ if (compare(@_[1, 2]));
    return @_[3,2,1,0];
  }
  return @_[1,0] if (scalar(@_) == 2);
  return @_[2,1,0] if (scalar(@_) == 3);
  return @_[3,2,1,0];
}


sub arrange_imp {
  return @_[0,2,3,1] if (
    (compare(@_[2,3])||(@_[2] eq @_[3])) && compare(@_[2, 1]));
  return @_[0,3,1,2] if (
    (compare(@_[3,1])||(@_[3] eq @_[1])) && compare(@_[3, 2]));
  return @_;
}


sub arrange_t {
  my $arrange = shift(@_);
  my $ntypes = shift(@_);

  if ($ntypes<scalar(@_)) {
    my $t = pop(@_);
    return ($arrange->(@_), $t);
  }
  return $arrange->(@_);
}


sub arrange_none {
  return @_;
}


sub index {
  my $index = [];
  my $guide = $EMC::Field::Guide;

  foreach (@{$guide->{index}}) {
    if (defined($guide->{auto}->{$_})) {
      push(@{$index}, $_."_auto");
    }
    push(@{$index}, $_);
  }
  return $index;
}


# application

sub from_item {
  my $item = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $indexed = defined($attr->{indexed}) ? $attr->{indexed} ? 1 : 0 : 0;
  my $field = defined($attr->{field}) ? $attr->{field} : undef;
  my $guide = $EMC::Field::Guide;

  foreach (@{$guide->{index}}) {
    my $class = $_;
    my $define = $class eq "define";

    foreach (defined($guide->{auto}->{$class}) ? ("_auto", "") : ("")) {
      my $key = $class.$_;
      my $index;
      my $array;
      
      next if (!defined($item->{$key}));

      $field->{$key}->{flag} = {} if (!defined($field->{$key}->{flag}));

      my $ftable = defined($guide->{table}->{$class}) ? 1 : 0;
      my $entry = $item->{$key};
      my $flag = $field->{$key}->{flag};
      my $ntypes = defined($guide->{ntypes}) ? $guide->{ntypes}->{$class} : 0;

      $flag->{array} = 0;
      $flag->{ntypes} = $ntypes;
      if (defined($item->{$key}->{header})) {
	$field->{$key}->{header} = [@{$item->{$key}->{header}}];
      }
      if ($ntypes) {

	# section with data indexed by types

	my $arrange = $class eq "improper" ? \&arrange_none : \&arrange;
	my $table;
	my $n;
	
	foreach (@{$entry->{data}}) {
	  my $arg = [];

	  foreach (@{$_}) {				# filter out empty
	    push(@{$arg}, $_) if ($_ ne "");
	  }
	  if (defined($table)) {			# populate table
	    push(@{$table}, @{$arg});
	    next if (scalar(@{$table})<$n);
	    undef($table);
	    undef($n);
	  } elsif(substr($_->[0],0,1) eq "#") {		# create index
	    if (!defined($index)) {
	      $index = [@{$arg}];
	      $index->[0] =~ s/^# //g;
	      if ($index->[-1] eq "[...]") {
		$flag->{array} = $array = 1;
		pop(@{$index});
	      }
	      $field->{$key}->{index} = [@{$index}];
	      for (my $i=0; $i<$ntypes; ++$i) {
		shift(@{$index});
	      }
	      $flag->{index} = [@{$index}] if ($indexed);
	    }
	  } else {					# deal with data
	    my $t = [];
	    
	    for (my $i=0; $i<$ntypes; ++$i) {
	      push(@{$t}, shift(@{$arg}));
	    }
	    $t = [$arrange->(@{$t})];
	    $field->{$key}->{data} = {} if (!defined($field->{$key}->{data}));

	    my $ptr = $field->{$key}->{data};
	    my $lptr;

	    if ($arg->[0] eq "T") {			# data contains temp
	      shift(@{$arg});
	      push(@{$t}, shift(@{$arg}));
	      $flag->{ntypes} = $ntypes+1;
	      $flag->{t} = 1;
	    } 
	    if ($define) {
	      $ptr = \$ptr->{$t->[0]};
	    } else {
	      foreach (0..$#{$t}) {			# hash
		my $s = $t->[$_];
		if (!defined($ptr->{$s}) || $_==$#{$t}) {
		  $ptr->{$s} = $_==$#{$t} && 
			       (defined($array) || !$indexed) ? [] : {};
		}
		$ptr = $ptr->{$s};
	      }
	    }
	    if ($ftable && $arg->[0] eq "TABLE") {	# data contains table
	      shift(@{$arg});
	      $n = shift(@{$arg});
	      if ($indexed) {
		$ptr->{n} = $n;
		$ptr->{x0} = shift(@{$arg}) if (defined($arg->[0]));
		$ptr->{dx} = shift(@{$arg}) if (defined($arg->[0]));
		$table = $ptr->{table} = [];
	      } else {
		push(@{$ptr}, $n);
		push(@{$ptr}, shift(@{$arg})) if (defined($arg->[0]));
		push(@{$ptr}, shift(@{$arg})) if (defined($arg->[0]));
		push(@{$ptr}, $table = []);
	      }
	      $flag->{table} = 1;
	    } else {
	      if ($indexed && defined($index)) {	# index exists

		if (defined($array)) {			# data is array
		  my $entry;
		  my $i = 0;

		  foreach (@{$arg}) {
		    $entry->{$index->[$i]} = $_;
		    if ($i==$#{$index}) {
		      push(@{$ptr}, $entry);
		      undef($entry);
		      $i = 0;
		    } else {
		      ++$i;
		    }
		  }
		  if (defined($entry)) {
		    push(@{$ptr}, $entry);
		  }
		} else {				# regular data
		  foreach (0..$#{$index}) {
		    $ptr->{$index->[$_]} = $arg->[$_];
		    last if (!defined($arg->[$_]));
		  }
		}
	      } else {					# unindexed data
		if ($define) {
		  ${$ptr} = $arg->[0];
		} else {
		  push(@{$ptr}, @{$arg});
		}
	      }
	    }
	  }
	}
      } else {

	# section without indexed data
	
	my $data;
	foreach (@{$entry->{data}}) {
	  my $arg = [];

	  foreach (@{$_}) {				# filter out empty
	    push(@{$arg}, $_) if ($_ ne "");
	  }
	  if(substr($_->[0],0,1) eq "#") {		# determine index
	    if (!defined($index)) {
	      $index = [@{$arg}];
	      $index->[0] =~ s/^# //g;
	      $field->{$key}->{index} = [@{$index}];
	      $flag->{index} = [@{$index}] if ($indexed);
	    }
	  } else {					# collect data
	    $data = [] if (!defined($data));
	    if ($indexed && defined($index)) {
	      my $ptr;
	      foreach (0..$#{$index}) {
		$ptr->{$index->[$_]} = $arg->[$_];
		last if (!defined($arg->[$_]));
	      }
	      push(@{$data}, $ptr);
	    } else {
	      push(@{$data}, [@{$arg}]);
	    }
	  }
	}
	if (defined($data)) {				# store data
	  $field->{$key}->{data} = $data;
	}
      }
    }
  }

  return EMC::Struct::set_index($field, EMC::Field::index());
}


sub append_table {
  my $data = shift(@_);
  my $table = shift(@_);
  my $entry = shift(@_);
  my $flag = shift(@_);
  my $n = 5;
  my $i = $n-1;

  push(@{$data}, []) if (!$flag->{first});
  $flag->{first} = 0;
  foreach (@{$table}) {
    if (++$i==$n) {
      push(@{$data}, $entry) if (scalar(@{$entry}));
      $entry = [];
      $i = 0;
    }
    push(@{$entry}, $_);
  }
  return $entry;
}

sub append_index {
  my $data = shift(@_);
  my $ptr = shift(@_);
  my $index = shift(@_);
  my $entry = shift(@_);

  foreach (@{$index}) {
    if ($_ eq "table") {
      $entry = append_table($data, $ptr->{$_}, $entry);
    } else {
      push(@{$entry}, $ptr->{$_});
    }
  }
  return $entry;
}


sub append_entry {
  my $data = shift(@_);
  my $type = shift(@_);
  my $ptr = shift(@_);
  my $flag = shift(@_);
  my $array = defined($flag->{array}) ? $flag->{array} : 0;
  my $index = defined($flag->{index}) ? $flag->{index} : undef;
  my $table = defined($flag->{table}) ? $flag->{table} : 0;
  my $entry = [];

  $ptr = $ptr->{data} if ((ref($ptr) eq "HASH") && (defined($ptr->{data})));
  if (defined($type) && scalar(@{$type})) {
    if (defined($flag->{t})) {
      my @t = @{$type};
      my $temp = pop(@t);
      push(@{$entry}, @t, "T", $temp);
    } else {
      push(@{$entry}, @{$type});
    }
  }
  push(@{$entry}, "TABLE") if ($table);
  if (defined($index)) {
    if (ref($ptr) eq "ARRAY") {
      foreach (@{$ptr}) {
	$entry = append_index($data, $_, $index, $entry);
      }
    } else {
      $entry = append_index($data, $ptr, $index, $entry);
    }
  } elsif (defined($ptr)) {
    if ($table) {
      if (ref($ptr) eq "ARRAY") {
	foreach (@{$ptr}) {
	  if (ref($_) eq "ARRAY") {
	    $entry = append_table($data, $_, $entry, $flag);
	  } else {
	    push(@{$entry}, $_);
	  }
	}
      } else {
	push(@{$entry}, $ptr);
      }
    } else {
      push(@{$entry}, ref($ptr) eq "ARRAY" ? @{$ptr} : $ptr);
    }
  }
  push(@{$data}, $entry) if (scalar(@{$entry}));
}


sub to_item {
  my $field = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $item = defined($attr->{item}) ? $attr->{item} : undef;
  my $guide = $EMC::Field::Guide;

  foreach (@{$guide->{index}}) {
    my $class = $_;
    my $define = $class eq "define";

    foreach (defined($guide->{auto}->{$class}) ? ("_auto", "") : ("")) {
      my $key = $class.$_;
      
      next if (!defined($field->{$key}));
      
      my $sub = $field->{$key};
      my $ptr = [$sub->{data}];
      my $flag = defined($sub->{flag}) ? $sub->{flag} : undef;
      my $ntypes = defined($flag->{ntypes}) ? $flag->{ntypes} : 0;
      my $nt = defined($guide->{ntypes}) ? $guide->{ntypes}->{$class} : 0;

      $item->{$key} = {} if (!defined($item->{$key}));
      my $data = defined($item->{$key}->{data}) ? $item->{$key}->{data} : [];
      my $type = [];
      my $i = 0;

      if (defined($sub->{header})) {
	$item->{$key}->{header} = [@{$sub->{header}}];
      }
      if (defined($sub->{index})) {
	my @arg = @{$sub->{index}};
	@arg[0] = "# ".@arg[0];
	append_entry($data, undef, \@arg, undef);
      }
      if ($ntypes>0) {
	my $arrange = $class eq "improper" ? \&arrange_none : \&arrange;

	$flag->{first} = 1;
	foreach (sort(keys(%{$ptr->[0]}))) {
	  $type->[0] = $_;
	  $ptr->[1] = $ptr->[0]->{$_};
	  if ($ntypes>1) {
	    foreach (sort(keys(%{$ptr->[1]}))) {
	      $type->[1] = $_;
	      $ptr->[2] = $ptr->[1]->{$_};
	      if ($ntypes>2) {
		foreach (sort(keys(%{$ptr->[2]}))) {
		  $type->[2] = $_;
		  $ptr->[3] = $ptr->[2]->{$_};
		  if ($ntypes>3) {
		    foreach (sort(keys(%{$ptr->[3]}))) {
		      $type->[3] = $_;
		      $ptr->[4] = $ptr->[3]->{$_};
		      if ($ntypes>4) {
			foreach (sort(keys(%{$ptr->[4]}))) {
			  $type->[4] = $_;
			  $ptr->[5] = $ptr->[4]->{$_};
			  my $local = [arrange_t($arrange, $nt, @{$type})];
			  append_entry($data, $local, $ptr->[-1], $flag);
			}
		      } else { 
			my $local = [arrange_t($arrange, $nt, @{$type})];
			append_entry($data, $local, $ptr->[-1], $flag);
		      }
		    }
		  } else {
		    my $local = [arrange_t($arrange, $nt, @{$type})];
		    append_entry($data, $local, $ptr->[-1], $flag);
		  }
		}
	      } else {
		my $local = [arrange_t($arrange, $nt, @{$type})];
		append_entry($data, $local, $ptr->[-1], $flag);
	      }
	    }
	  } else {
	    append_entry($data, $type, $ptr->[-1], $flag);
	  }
	}
      } else {
	if (ref($ptr->[-1]) eq "ARRAY") {
	  foreach (@{$ptr->[-1]}) {
	    append_entry($data, $type, $_, $flag);
	  }
	} else {
	  append_entry($data, $type, $ptr->[-1], $flag);
	}
      }
      $item->{$key}->{data} = $data if (scalar(@{$data}));
    }
  }
  return EMC::Struct::set_index($item, EMC::Field::index());
}


# I/O

sub read {
  my $stream = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $item = EMC::Item::read($stream);
  my $field = from_item($item, $attr);

  return $field;
}


sub write {
  my $stream = shift(@_);
  my $field = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $item = to_item($field, $attr);

  #EMC::Message::dumper($item); exit(-1);
  EMC::Item::write($stream, $item);
  return $field;
}

