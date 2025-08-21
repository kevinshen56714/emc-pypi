#!/usr/bin/env perl
#
#  module:	EMC::Options.pm
#  author:	Pieter J. in 't Veld
#  date:	January 2, 2022.
#  purpose:	Options structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  members:
#    columns	INTEGER	number of columns in terminal
#
#    offset	INTEGER	offset between command and description
#    
#    commands	HASH	hash of commands, for members see element below
#
#    warnings	ARRAY	warnings generated during option interpretation
#
#  commands: 
#    comment	STRING	help explanation
#    
#    default	ANY	default value depending on settings => turn into func?
#
#    [gui]	ARRAY	information to be ported to VMD EMC GUI
#      type	STRING	input type
#      tab	STRING	main menu tab
#      subtab	STRING	sub menu tab
#      section	STRING	either 'standard' or 'advanced' as subtab section
#      optional	STRING	optional defaults
#
#    module	PTR	pointer to original module
#
#    set	FUNC	called function for setting option
#
#  notes:
#    20220102	Inception of v1.0
#    		Options are set in subsequent EMC modules
#

package EMC::Options;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use B qw(svref_2object);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Common;
use EMC::Hash;
use EMC::Message;


# construct

sub construct {
  my $options = EMC::Common::hash(EMC::Common::element(shift(@_)));

  $options->{warnings} = [];
  return $options;
}


# functions

sub identity {
  my $options = shift(@_);
  my $identity = defined($options->{identity}) ? $options->{identity} : {};
  
  foreach ("script", "version", "date", "author", "command_line") {
    last if (!scalar(@_));
    $identity->{$_} = shift(@_);
  }
  $identity->{copyright} = "2004-".EMC::Common::date_year();
  $options->{identity} = $identity;
  return $options;
}


sub version {
  my $options = shift(@_);
  my $identity = $options->{identity};

  EMC::Message::message(
    "EMC $identity->{name} v$identity->{version}, $identity->{date}\n");
  EMC::Message::message(
    "Copyright (c) $identity->{copyright} $identity->{author}\n");
  exit();
}

sub header {
  my $options = shift(@_);
  my $identity = $options->{identity};
  
  EMC::Message::message(
    "$identity->{main} $identity->{name} v$identity->{version} ($identity->{date}), ");
  EMC::Message::message(
    "(c) $identity->{copyright} $identity->{author}\n\n");
}


sub help {
  my $options = shift(@_);
  my $noexit = shift(@_) ? 1 : 0;
  my $commands = defined($options->{commands}) ? $options->{commands} : undef;
  my $columns = defined($options->{columns}) ? $options->{columns} : 80;
  my $offset = defined($options->{offset}) ? $options->{offset} : 3;
  my $n;
  my $key;
  my $format;

  header($options);
  return if (!defined($commands));
  
  $options->{set_commands}->() if (defined($options->{set_commands}));
  $options->{set_defaults}->($options) if (defined($options->{set_defaults}));

  $columns -= 3;
  foreach (keys(%{$commands})) {
    $n = length($_) if (length($_)>$n); }
  $format = "%-$n.".$n."s ";
  $offset += $n+1;

  print("Usage:\n  $options->{identity}->{script}");
  if (defined($options->{identity}->{command_line})) {
    print(" $options->{identity}->{command_line}\n");
  }
  print("\nCommands:\n");
  foreach $key (sort(keys(%{$commands}))) {
    my $ptr = $commands->{$key};
    my $mod = (split(":", sub_name($ptr->{set})))[2];
    my $original =
      defined($ptr->{original}) ?  " (depricated, use $ptr->{original})" : "";
    my $data = $ptr->{comment}.$original;
    my $n = $offset;

    printf("  -$format", $key);
    $ptr->{default} = $ptr->{get}->() if (defined($ptr->{get}));
    $data .= " [$ptr->{default}]" if ($ptr->{default} ne "");
    $data .= " [$mod]" if ($options->{module});
    foreach (split(" ", $data)) {
      if (($n += length($_)+1)>$columns) {
	printf("\n   $format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    print("\n");
  }

  if (defined($options->{notes})) {
    printf("\nNotes:\n");
    $offset = $n = 3;
    $format = "%$n.".$n."s";
    foreach (@{$options->{notes}}) { 
      $n = $offset;
      printf($format, "*");
      foreach (split(" ")) {
	if (($n += length($_)+1)>$columns) {
	  printf("\n$format", ""); $n = $offset+length($_)+1; }
	print(" $_");
      }
      print("\n");
    }
  }

  print("\n");
  exit(-1) if (!$noexit);
}


sub set_help {
  my $struct = shift(@_);
  my $flag = shift(@_);
  my $root = EMC::Common::element($struct, "root");
  my $args = EMC::Common::element($struct, "args");
  my $option = EMC::Common::element($struct, "option");

  return if (!defined($root));

  set_context($root);
  set_commands($root);
  my $options = transcribe($root)->{options};
  $options->{module} = 1 if ($args->[0] eq "module");
  help($options, 1);
  if ($flag && defined($option) && $option ne "help") {
    print("Non-existent option '$option'.\n\n");
  }
  $struct->{exit}->() if (defined($struct->{exit}));
  exit(-1);
}


sub transcribe_single {
  my $type = shift(@_);
  my $options = shift(@_);
  my $parent = shift(@_);
  my $child = shift(@_);
  my $module = shift(@_);

  return if (!defined($child->{set}));
  return if (!defined(EMC::Common::element($child, "set", "flag", $type)));
  return if (!$child->{set}->{flag}->{$type});

  if (defined($child->{$type})) {
    my $hash = $options->{$type} =
      EMC::Common::attributes(
	EMC::Common::hash($options, $type), $child->{$type});
    my $list = EMC::Hash::list($child->{$type});
    my $ptr = \$parent->{$module};		# crossreference as pointer
						# to avoid recursive traps
    foreach (keys(%{$child->{$type}})) {
      next if (ref($hash->{$_}) ne "HASH");
      $hash->{$_}->{module} = $ptr;
    }
    $options->{list}->{$type} = [] if (!defined($options->{list}->{$type}));
    push(@{$options->{list}->{$type}}, @{$list});
  }
  return if ($type ne "commands");
  return if (!defined($child->{notes}));
  return if (ref($child->{notes}) ne "ARRAY");
  $options->{notes} = [] if (!defined($options->{notes}));
  push(@{$options->{notes}}, @{$child->{notes}});
 
}


sub transcribe {				# combine all commands and 
  my $parent = shift(@_);			# notes into $root->{options}
  my $flag = defined(@_[0]) ? 1 : 0;
  my $root = $flag ? shift(@_) : $parent;
  my $level = defined(@_[0]) ? shift(@_) : 0;

  if (defined($parent)) {
    if (!$flag) {
      $root = $parent;
      $root->{options} = {};
      if (defined($root->{global}) && defined($root->{global}->{identity})) {
	$root->{options}->{identity} = $root->{global}->{identity};
      }
    }
    my $options = $root->{options};

    foreach (sort(keys(%{$parent}))) {
      next if ($_ eq "commands" || $_ eq "items" || $_ eq "options");
      next if (ref($parent->{$_}) ne "HASH");
      my $child = $parent->{$_};

      #EMC::Message::spot("pre   [$level]", (("----") x $level), "--> $_\n");
      
      transcribe($child, $root, $level+1);	# populating recursively
      
      transcribe_single("commands", $options, $parent, $child, $_);
      transcribe_single("items", $options, $parent, $child, $_);
    }
  }
  return $parent;
}


$EMC::Options::level = 0;

sub single {
  my $root = shift(@_);
  my $parent = shift(@_);
  my $name = shift(@_);
  my $function = shift(@_);
  my $type = shift(@_);

  ++$EMC::Options::level;
  goto single_return if ($name eq "");
  goto single_return if (!defined($parent->{$name}));
  my $child = $parent->{$name};
  goto single_return if (ref($child) ne "HASH");
  #EMC::Message::message((" " x (2*$EMC::Options::level)).$type."->".$name."\n") if ($function eq "write");
  recursive($child, $root, $function, $type);

  goto single_return if (!defined($child->{$function}));
  goto single_return if (ref($child->{$function}) ne "HASH");
  goto single_return if (!defined($child->{$function}->{$type}));
  $child->{$function}->{$type}->($child, $root);
  
single_return: 
  --$EMC::Options::level;
  return;
}


sub recursive {
  my $parent = shift(@_);
  my $root = shift(@_);
  my $function = shift(@_);
  my $type = shift(@_);

  if (defined($parent)) {
    single($root, $parent, "global", $function, $type) if ($root == $parent);
    foreach (sort(keys(%{$parent}))) {
      next if ($_ eq "global");
      single($root, $parent, $_, $function, $type);
    }
  }
  return $parent;
}


sub set_commands {
  my $parent = shift(@_);
  my $root = defined(@_[0]) ? shift(@_) : $parent; 

  recursive($parent, $root, "set", "commands");
}


sub set_context {
  my $parent = shift(@_);
  my $root = defined(@_[0]) ? shift(@_) : $parent; 
 
  recursive($parent, $root, "set", "context");
}


sub set_defaults {
  my $parent = shift(@_);
  my $root = defined(@_[0]) ? shift(@_) : $parent; 
 
  recursive($parent, $root, "set", "defaults");
}


sub write {
  my $stream = shift(@_);
  my $parent = shift(@_);
  my $type = shift(@_);
  my $root = defined(@_[0]) ? shift(@_) : $parent;
  my $store = EMC::Common::element($root, "io", "stream");

  $root->{io}->{stream} = $stream;
  recursive($parent, $root, "write", $type);
  $root->{io}->{stream} = $store;
}


sub set_command {
  my $hash = shift(@_);
  my $command = shift(@_);

  foreach (keys(%{$hash})) {
    my $ptr = $hash->{$_};
    next if (ref($ptr) ne "HASH");
    foreach (keys(%{$command})) {
      next if (defined($ptr->{$_}));
      $ptr->{$_} = EMC::Element::deep_copy($command->{$_});
    }
  }
}


#
# Interpretation of options; returns undef if unsuccessful
#
# members of struct:
#   option	STRING	option keyword
#   args	ARRAY	array of string values
#   file	STRING	file name
#   line	INTEGER	line of file; ignored when < 0
#   root	PTR	pointer to hash containing all shared information
#   module	PTR	pointer to originating module
#   options	PTR	pointer to originating options structure
#   command	PTR	pointer to selected command structure
#   [data]	PTR	pointer to data structure, if needed
#

sub set_options {				# <= options
  my $options = shift(@_);
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $command = EMC::Common::element($options, "commands", $option);

  return undef if (!defined($command));
  
  if (!defined($command->{set})) {
    EMC::Message::error(
      "undefined set function for command '$option'\n");
  }
  if (!defined($command->{module})) {
    EMC::Message::error(
      "undefined module for command '$option'\n");
  }
  if (defined($options)) {
    $options->{warnings} = [] if (!defined($options->{warnings}));
  }
  $struct->{command} = $command;
  $struct->{options} = $options;
  $struct->{module} = $command->{module};
  return $command->{set}->($struct);
}


sub set_items {
  my $options = shift(@_);
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $item = EMC::Common::element($options, "items", $option);

  return undef if (!defined($item));
  
  if (!defined($item->{set})) {
    EMC::Message::error("undefined set function for item '$option'\n");
  }
  if (!defined($item->{module})) {
    EMC::Message::error("undefined module for item '$option'\n");
  }
  $struct->{item} = $item;
  $struct->{options} = $options;
  $struct->{module} = $item->{module};
  $struct->{extension} = EMC::Common::element(
    $struct, "root", "global", "script", "extension") if (!defined($struct->{extension}));
  return $item->{set}->($struct);
}


# functions

sub export {					# <= options_export
  my $options = shift(@_);
  my $language = shift(@_);
  my $commands = EMC::Common::element($options, "commands");

  return if (!$options->{flag}->{$language});
  set_variables();
  set_commands();
  if ($options->{flag}->{perl}) {
    my $comma = 0;

    print("(\n");
    foreach(sort(keys(%{$commands}))) {
      next if (substr($_, 0, 7) eq "options");
      print(",\n") if ($comma);
      my $ptr = $commands->{$_};
      my @arg = (${$ptr}{comment}, ${$ptr}{default}, @{${$ptr}{gui}});
      foreach (@arg) { $_ =~ s/\"/\\\"/g; $_ =~ s/\$/\\\$/g; $_ = "\"$_\""; }
      print("  $_ => [", join(", ", @arg), "]");
      $comma = 1;
    }
    print("\n)\n");
    exit(0);
  } elsif ($options->{flag}->{tcl}) {
    print("{\n");
    foreach(sort(keys(%{$commands}))) {
      next if (substr($_, 0, 7) eq "options");
      my $ptr = $commands->{$_};
      my @arg = (${$ptr}{comment}, ${$ptr}{default}, @{${$ptr}{gui}});
      foreach (@arg) { $_ =~ s/\"/\\\"/g; $_ =~ s/\$/\\\$/g; $_ = "\"$_\""; }
      print("  $_ {", join(" ", @arg), "}\n");
    }
    print("}\n");
    exit(0);
  }
  print("Export of options to $language is currently not supported\n\n");
  exit(-1);
}


sub set_allowed {
  my $line = shift(@_);
  my $option = shift(@_);
  my %allowed;

  foreach (@_) { $allowed{$_} = 1; }
  if (!defined($allowed{$option})) {
    EMC::Message::error_line($line, "unallowed option '$option'\n");
  }
  return $option;
}


sub set_choice {				# <= set_options
  my $line = shift(@_);
  my $options = shift(@_);
  my $items = shift(@_);
  my $attr = EMC::Common::attributes({ignore => 0, string => 0}, @_);
  my $ignore = EMC::Math::flag($attr->{ignore});
  my $string = EMC::Math::flag($attr->{string});
  my %allowed;
  my %answer;
  my @xref;
  my $n = 0;

  foreach (@{$options}) {
    $xref[$allowed{@{$_}[0]} = $n++] = @{$_}[0];
    $answer{@{$_}[0]} = @{$_}[1];
  }
  if (!defined($allowed{comment})) {
    $xref[$allowed{comment} = $n++] = "comment";
    $answer{comment} = 0;
  }
  my $index = 0; foreach(@{$items}) {
    $_ =~ s/ //g;
    my @arg = split("=");
    my $option = @arg[0];
    my $value;
    my $i = $index++;

    if (scalar(@arg)>1) {
      if (!defined($allowed{@arg[0]})) {
	EMC::Message::error_line(
	  $line, "unallowed option '@arg[0]'\n") if (!$ignore);
	--$index;
	next;
      }
      $i = $allowed{@arg[0]}; shift(@arg);
    } else {
      next if ($i>=$n);
    }
    $answer{$xref[$i]} = @arg[0] eq "last" ? -1 : 
			 @arg[0] eq "true" ? 1 : 
			 @arg[0] eq "false" ? 0 : 
			 $string ? @arg[0] : eval(@arg[0]);
  }
  return %answer;
}


sub sub_name {
    return unless ref( my $r = shift );
    return unless my $cv = svref_2object( $r );
    return unless $cv->isa( 'B::CV' )
              and my $gv = $cv->GV
              ;
    my $name = '';
    if ( my $st = $gv->STASH ) { 
        $name = $st->NAME . '::';
    }
    my $n = $gv->NAME;
    if ( $n ) { 
        $name .= $n;
        if ( $n eq '__ANON__' ) { 
            $name .= ' defined at ' . $gv->FILE . ':' . $gv->LINE;
        }
    }
    return $name;
}


sub write_warnings {
  my $options = shift(@_);

  foreach (@{$options->{warnings}}) {
    EMC::Message::warning("$_\n");
  }
}


1;
