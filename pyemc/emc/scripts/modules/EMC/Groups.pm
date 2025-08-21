#!/usr/bin/env perl
#
#  module:	EMC::Groups.pm
#  author:	Pieter J. in 't Veld
#  date:	September 20, 2022.
#  purpose:	Groups structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "groups_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    context		HASH	optional settings
#    flag		HASH	optional flags
#    group		HASH
#      id		STRING	identitier
#      field		ARRAY	list of field to apply to group
#      polymer		BOOLEAN	flags polymeric interpretation of group
#      connect		ARRAY	connectivity
#      nconnects	VALUE	number of connection
#
#  notes:
#    20220920	Inception of v1.0
#

package EMC::Groups;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Groups'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::Math;
use EMC::Message;


# defaults

$EMC::Groups::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 20, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $groups = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($groups, $attr);
  set_defaults($groups);
  set_commands($groups);
  return $groups;
}


# initialization

sub set_defaults {
  my $groups = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $groups = EMC::Common::attributes(
    $groups,
    {
      context		=> {
	ngrafts		=> 0,
	nregulars	=> 0,
	nselects	=> 0
      },
      group		=> {},
      index		=> []
    }
  );
  $groups->{identity} = EMC::Common::attributes(
    EMC::Common::hash($groups, "identity"),
    $EMC::Groups::Identity
  );
  return $groups;
}


sub transfer {
  my $groups = EMC::Common::hash(shift(@_));
  my $context = EMC::Common::element($groups, "context");
  
  EMC::Element::transfer(shift(@_),
    [\@::EMC::Groups,			\$groups->{index}],
    [\%::EMC::Group,			\$groups->{group}]
  );
}


sub set_context {
  my $groups = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $units = EMC::Common::element($root, "global", "units");
  my $flag = EMC::Common::element($groups, "flag");
  my $context = EMC::Common::element($groups, "context");
}


sub set_commands {
  my $groups = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($groups, "set");
  my $context = EMC::Common::element($groups, "context");
  my $flag = EMC::Common::element($groups, "flag");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
  my $depricated = defined($set) ? $set->{flag}->{depricated} : 1;
  my $flag_depricated = $indicator ? 0 : $depricated;
  my $pre = $indicator = $indicator ? "groups_" : "";

  $groups->{commands} = EMC::Common::attributes(
    EMC::Common::hash($groups, "commands"),
    {
    }
  );

  foreach (keys(%{$groups->{commands}})) {
    my $ptr = $groups->{commands}->{$_};
    $ptr->{set} = \&EMC::Clusters::set_options if (!defined($ptr->{set}));
  }

  $groups->{items} = EMC::Common::attributes(
    EMC::Common::hash($groups, "items"),
    {
      groups		=> {
	chemistry	=> 1,
	environment	=> 1,
	order		=> 20,
	set		=> \&set_item_groups
      }
    }
  );

  return $groups;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $root = EMC::Common::element($struct, "root");
  my $groups = EMC::Common::element($struct, "module");
  my $flag = EMC::Common::hash($groups, "flag");
  my $set = EMC::Common::element($groups, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "groups_" : "";
  if ($option eq $indicator."dummy") {
    return $flag->{dummy} = EMC::Math::flag($args->[0]);
  }
  return undef;
}


sub set_functions {
  my $groups = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($groups, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Groups::set_commands;
  $set->{context} = \&EMC::Groups::set_context;
  $set->{defaults} = \&EMC::Groups::set_defaults;
  $set->{options} = \&EMC::Groups::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $groups;
}


# functions

sub check_group {
  my $line = shift(@_);
  my $group = shift(@_);
  my $name = shift(@_);
  my $index = shift(@_);

  if (!defined($group->{$name})) {
    EMC::Message::error_line(
      $line, "undefined group '$name'\n");
  }
  if (!EMC::Math::number_q($index)) {
    EMC::Message::error_line(
      $line, "index number expected for '$name:$index'\n");
  }
  if ($index<1 || $index>$group->{$name}->{nconnects}) {
    EMC::Message::error_line(
      $line, "index out of bounds for '$name:$index'\n");
  }
  return $group->{$name};
}


$EMC::Groups::select = {
  mode		=> EMC::List::hash(["and", "or", "xor"]),
  negate	=> EMC::List::hash(["false", "true"]),
  nconnects	=> "integer",
  elements	=> [],
  sites		=> [],
  groups	=> [],
  clusters	=> [],
  systems	=> []
};


sub select_apply {
  my $select = shift(@_);
  my $ptr = shift(@_);
  my $tmp = EMC::Groups::select($ptr->{string}, @_[1]);

  $tmp = {select => $tmp} if (ref($tmp) eq "ARRAY");
  $tmp->{negate} = $ptr->{negate} if (defined($ptr->{negate}));
  $tmp->{mode} = $ptr->{mode} if (defined($ptr->{mode}));
  $select = [] if (!$select);
  push(@{$select}, $tmp) if (defined($tmp));
  return $select;
}


sub select {
  my $select = undef;
  my $ptr = undef;
  my ($last, $mode);

  foreach (split("", @_[0])) {
    my $level = defined($ptr->{level}) ? $ptr->{level} : 0;
    if ($ptr->{apply}) {
      $select = EMC::Groups::select_apply($select, $ptr);
      $ptr = defined($mode) ? {mode => $mode} : undef;
      undef($mode);
    }
    if (defined($ptr) && $ptr->{level}) {
      if ($_ eq ")") {
	if (!$ptr->{level}) {
	  EMC::Message::error_line(@_[1], "parenthesis mismatch");
	}
	$ptr->{apply} = 1 if (!--$ptr->{level});
	next if ($ptr->{apply});
      } elsif ($_ eq "(") {
	++$ptr->{level}
      }
      $ptr->{string} .= $_;
    } elsif ($_ eq "(") {
      ++$ptr->{level};
    } elsif ($_ eq "!") {
      $ptr->{negate} ^= 1;
    } elsif ($_ eq "|") {
      next if ($_ eq $last);
      $ptr->{apply} = 1;
      $mode = "or";
    } elsif ($_ eq "&") {
      next if ($_ eq $last);
      $ptr->{apply} = 1;
      $mode = "and";
    } elsif ($_ eq "^") {
      if ($ptr->{apply}) {
	EMC::Message::error_line(@_[1], "unallowed logical operation");
      }
      $ptr->{apply} = 1;
      $mode = "xor";
    } elsif ($_ eq "=") {
      next if ($last eq "=");
      $ptr->{string} .= $_;
    } else {
      $ptr->{string} .= $_;
    }
    $last = $_;
  }
  if ($ptr->{apply}) {
    $ptr->{mode} = $mode if (defined($mode));
    $select = EMC::Groups::select_apply($select, $ptr);
  } elsif (defined($ptr->{string})) {
    my @a = split("=", $ptr->{string});

    if (!defined($EMC::Groups::select->{@a[0]})) {
      EMC::Message::error_line(@_[1], "unallowed select keyword '@a[0]'");
    }
    if (ref($EMC::Groups::select->{@a[0]}) eq "ARRAY") {
      my @list = split(":", @a[1]);
      @a[1] = [@list] if (scalar(@list)>1);
    } elsif ($EMC::Groups::select->{@a[0]} eq "integer") {
      @a[1] = eval(@a[1]);
    }
    
    my $tmp = {@a[0] => @a[1]};
    
    $tmp->{negate} = $ptr->{negate} if (defined($ptr->{negate}));
    $tmp->{mode} = $ptr->{mode} if (defined($ptr->{mode}));
    if (defined($select)) {
      push(@{$select}, $tmp);
    } else {
      $select = $tmp;
    }
  }
  return
    ref($select) eq "ARRAY" && scalar(@{$select})==1 ?
    $select->[0] : $select;
}


sub set_connectivity {				# <= check_group_connectivity
  my $groups = shift(@_);
  my $index = $groups->{index};
  my $group = $groups->{group};

  foreach (@{$index}) {				# cross-connectivity
    my $name = $_;
    my $line = $group->{$name}->{line};
    my $iconnect = 0;

    foreach (@{$group->{$name}->{connect}}) {
      ++$iconnect;
      foreach (@{$_}) {
	next if (defined($_->{select}));
	set_connect(
	  check_group($line, $group, $_->{name}, $_->{connect}),
	  $_->{name}, $_->{connect}, $name, $iconnect);
      }
    }
  }
  foreach (@{$index}) {				# check validity
    my $name = $_;
    my $line = $group->{$name}->{line};
    my $iconnect = 0;

    foreach (@{$group->{$name}->{connect}}) {
      ++$iconnect;
      if (!scalar(@{$_})) {
	EMC::Message::error_line(
	  $line, "missing connection for '$name:$iconnect'\n");
      }
    }
  }
}


sub set_connect {				# <= group_connection
  my $group = shift(@_);
  my $src = {name => shift(@_), connect => shift(@_)};
  my $dest = {name => shift(@_), connect => shift(@_)};
  my $connect = $group->{connect}->[$src->{connect}-1];

  foreach (@{$connect}) {
    return if ($_->{name} eq $dest->{name} && $_->{connect} eq $dest->{connect});
  }
  push(@{$connect}, $dest);
}


# set item

sub set_context {
  my $groups = shift(@_);
  my $context = EMC::Common::hash($groups, "context");
  my $group = EMC::Common::hash($groups, "group");

  $context->{ngrafts} = undef;
  $context->{nselects} = undef;
  $context->{nregulars} = undef;
  foreach (keys(%{$group})) {
    if ($group->{$_}->{flag}->{graft}) {
      ++$context->{ngrafts};
    } elsif ($group->{$_}->{flag}->{select}) {
      ++$context->{nselects};
    } else {
      ++$context->{nregulars};
    }
  }
}


sub add_group {
  my $root = shift(@_);
  my $name = shift(@_);
  my $line = shift(@_);
  my $fields = EMC::Common::element($root, "fields", "fields");

  return if (!(defined($fields) && defined($name)));

  my $result = EMC::Fields::find_group($root->{fields}, $name);

  if (scalar(@{$result})==1) {
    my $struct = {
      root => $root,
      parent => EMC::Common::element($root, "emc"),
      module => EMC::Common::element($root, "emc", "groups"),
      item => EMC::Item::read({data => EMC::IO::get("
ITEM	GROUP
$name	$result->[0]->{chemistry}
ITEM	END
")})->{group}
    };
    $struct->{item}->{lines}->[0] = $line;
    EMC::Groups::set_item_groups($struct);
    EMC::Message::info("added group '$name' from id '$result->[0]->{id}'\n");
    return 1;
  } elsif (scalar(@{$result})>1) {
    EMC::Message::error_line($line,
      "more than one group '$name' in force fields\n");
  }
  return 0;
}


sub set_item_groups {
  my $struct = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return $root if (EMC::Common::element($options, "comment"));
 
  my $option = EMC::Common::element($struct, "option");
  my $groups = EMC::Common::element($struct, "module");
  my $emc = EMC::Common::element($groups, "parent");
  
  my $flag = EMC::Common::element($root, "global", "flag");
  my $polymer = EMC::Common::element($emc, "polymers", "polymer");
  my $index = $groups->{index} = EMC::Common::array($groups, "index");
  
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $iline = 0;

  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$iline++];

    if (scalar(@arg)<2) {
      EMC::Message::error_line($line, "too few group entries (< 2)\n");
    }
    my $mass;
    my $charges;
    my $field = [];
    my $terminator = 0;
    my $id = EMC::Groups::set_group(
      $root, $line, shift(@arg), \$charges, $field, \$mass, \$terminator);
    my $name = EMC::Common::convert_name($id)->[0];
    my $chemistry = shift(@arg);
    my $fpoly = EMC::Polymers::is_polymer($chemistry);
    my $nconnects = ($chemistry =~ tr/\*\<\>//);
    my $group = $groups->{group} = EMC::Common::hash($groups, "group");

    if ($chemistry =~ m/\{/) {				# groups from force
      my $bracket = 0;					# fields
      my $flag = 0;	
      my $tmp;
      my $var;

      foreach (split("", $chemistry)) {
	if ($flag) {
	  if ($_ eq "}") {
	    my $result = EMC::Fields::find_group($root->{fields}, $var);
	    if (scalar(@{$result})==0) {
	      EMC::Message::error_line($line,
		"no group '$var' in force fields\n");
	    } elsif (scalar(@{$result})>1) {
	      EMC::Message::error_line($line,
		"more than one group '$var' in force fields\n");
	    }
	    EMC::Message::info("used template '$var' from id '$result->[0]->{id}'\n");
	    $tmp .= $result->[0]->{chemistry};
	    $flag = 0;
	  } else {
	    $var .= $_;
	  }
	} elsif ($_ eq "{") {
	  $flag = 1 if (!$bracket); 
	} else {
	  ++$bracket if ($_ eq "[");
	  --$bracket if ($_ eq "]");
	  $tmp .= $_;
	}
      }
      $chemistry = $tmp;
    }
    EMC::EMC::check_name($emc, $name, $line, 0);
    push(@{$index}, $name) if (!defined($group->{$name}));

    $group = $group->{$name} = {
      id => $id,
      polymer => $fpoly,
      charges => $charges,
      terminator => $terminator,
      type => $fpoly ? $chemistry : "group",
      flag => {regular => 1}
    };
    if ($fpoly) {
      $polymer->{$name}->{options}->{group} = 1;
      $polymer->{$name}->{options}->{type} = $fpoly;
      $polymer->{$name}->{options}->{polymer} = $chemistry;
      $polymer->{$name}->{connects} = scalar(@arg) ? [@arg] : undef;
      next;
    }
    $group = EMC::Common::attributes($group, {
	charges => $charges,
	chemistry => $chemistry,
	connect => [],
	field => $field,
	flag => {},
	line => $line,
	mass => $mass,
	nconnects => $nconnects,
	nextra => EMC::Chemistry::count_clusters($chemistry)
      }
    );
    
    $group->{connect} = [];
    for (my $i=0; $i<$nconnects; ++$i) { 
      $group->{connect}->[$i] = [];
    }
   
    #$group->{flag}->{graft} = 0;
    #$group->{flag}->{select} = 0;
    $group->{flag}->{regular} = 1 if (!scalar(@arg));
    while (scalar(@arg)) {
      my $connect = shift(@arg);
      my $list = $group->{connect}->[$connect-1];
      my @a = split("=", @arg[0]); 
      
      if (scalar(@a)>1) {
	my $allowed = {graft => 1};
	@a[0] = EMC::Common::trim(@a[0]);
	if (!defined($allowed->{@a[0]})) {
	  EMC::Message::error_line($line, "unallowed option '@a[0]'\n");
	}
	
	my $fselect = @a[0] eq "select" ? 1 : 0;
	my $fgraft = @a[0] eq "graft" ? 1 : 0;
	
	if ($fselect || $fgraft) {
	  shift(@a); shift(@arg);
	  my $select = EMC::Groups::select(join("=", @a), $line);
	  push(@{$list}, {select => $select});
	  $group->{flag}->{select} = 1 if ($fselect);
	  $group->{flag}->{graft} = 1 if ($fgraft);
	  $groups->{flag}->{grafts} = 1 if ($fgraft);
	} 
      } else {
	my @a = split(":", shift(@arg));
	my $gconnect = pop(@a);
	my $gname = join(":", @a);

	EMC::EMC::check_name($emc, $name, $line, 0);
	EMC::Groups::check_group($line, $groups->{group}, $name, $connect);
	push(@{$list}, {name => $gname, connect => $gconnect});
	$group->{flag}->{regular} = 1;
      }
    }
  }
  set_connectivity($groups);
  set_context($groups);
  return $root;
}


# functions

sub set_group {
  my $root = shift(@_);
  my $line = shift(@_);
  my $id = shift(@_);
  my $charges = shift(@_);
  my $field = shift(@_);
  my $mass = shift(@_);
  my $terminator = shift(@_);
  my @tmp = split(":", $id);
  my $name = shift(@tmp);
  my $fields = EMC::Common::element($root, "fields");
  my $flag = EMC::Common::element($root, "global", "flag");
  my $allowed = {
    c => "charges", charges => 1,
    f => "field", field => 1,
    m => "mass", mass => 1,
    t => "term", term => 1};
  my $charge_check = {
    a => "additive", additive => 1,
    f => "forcefield", forcefield => 1, field => 1,
    o => "override", override => 1};

  return $id if (!scalar(@tmp));
  
  if (!$flag->{expert}) {			# Check errors
    foreach (@tmp) {
      my @a = split("=");
      if (!defined($allowed->{@a[0]})) {
	EMC::Message::error_line($line,
	  "unrecognized group modifier '@a[0]'\n");
      }
    }
  }
  foreach (@tmp) {				# Filter options
    my @a = split("=");
    if (@a[0] eq "c" || @a[0] eq "charges") { 
      if (!defined($charge_check->{@a[1]})) {
	EMC::Message::error_line($line,
	  "unrecognized charges modifier '@a[1]'\n");
      }
      @a[1] = "field" if (@a[1] eq "forcefield");
      ${$charges} = length(@a[1])==1 ? $charge_check->{@a[1]} : @a[1];
    }
    elsif (@a[0] eq "f" || @a[0] eq "field") { @{$field} = split(",", @a[1]); }
    elsif (@a[0] eq "m" || @a[0] eq "mass") { ${$mass} = @a[1]; }
    elsif (@a[0] eq "t" || @a[0] eq "term") { ${$terminator} = 1; }
    else { $name .= ":@a[0]"; }
  }
  @{$field} = @{EMC::Fields::id($fields, $line, @{$field})};
  return $name;
}


sub types {
  my $root = shift(@_);
  my $groups = EMC::Common::element($root, "emc", "groups", "group");
  my $filter = {"*" => 1, "-" => 1, '+' => 1, ":" => "1", "=" => 1, "#" => 1};

  if ($groups) {
    my $hash = {};
    foreach (sort(keys(%{$groups}))) {
      my $group = $groups->{$_};
      next if (!defined($group->{chemistry}));
      my $list = EMC::List::smiles($group->{chemistry}, {filter => $filter});
      foreach (@{EMC::List::flatten($list)}) {
	$hash->{$_} = 1;
      }
    }
    return [sort(keys(%{$hash}))];
  }
  return undef;
}

