#!/usr/bin/env perl
#
#  module:	EMC::Message.pm
#  author:	Pieter J. in 't Veld
#  date:	November 24, 2021, January 15, 2022.
#  purpose:	Message routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "message_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    flag		HASH
#      debug		BOOLEAN	allow for debugging messages
#      expert		BOOLEAN	allow for expert messages
#      info		BOOLEAN	allow for informational messages
#      input		STRING	input source
#      warn		BOOLEAN	allow for warnings 
#
#  notes:
#    20211124	Inception of v1.0
#    20220115	Inclusion of commands, defaults, and functions
#

package EMC::Message;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use Data::Dumper;
use EMC::Common;


# defaults 

$EMC::Message::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "January 15, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $message = EMC::Common::obtain_hash(shift(@_));
  my $attr = EMC::Common::attributes(@_);
 
  set_functions($message, $attr);
  set_defaults($message);
  set_commands($message);
  return $message;
}


# initialization

sub set_defaults {
  my $message = EMC::Common::obtain_hash(shift(@_));

  $EMC::Message::Flag = $message->{flag} = EMC::Common::attributes(
    defined($message->{flag}) ? $message->{flag} : {},
    {
      debug	=> 0,
      expert	=> 0,
      info	=> 1,
      input	=> "",
      warn	=> 1
    }
  );
  $message->{identity} = EMC::Common::attributes(
    EMC::Common::obtain_hash($message, "identity"),
    $EMC::Field::Identity
  );
  return $message;
}


sub set_commands {
  my $message = EMC::Common::obtain_hash(shift(@_));
  my $set = EMC::Common::element($message, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "message_" : "";
  $message->{commands} = EMC::Common::attributes(
    EMC::Common::obtain_hash($message, "commands"),
    {
      $indicator."debug"	=> {
	comment		=> "output debugging information",
	set		=> \&EMC::Message::set_options,
	default		=> EMC::Math::boolean($message->{flag}->{debug})
      },
      $indicator."expert"	=> {
	comment		=> "set expert mode",
	set		=> \&EMC::Message::set_options,
	default		=> EMC::Math::boolean($message->{flag}->{expert})
      },
      $indicator."info"	=> {
	comment		=> "output standard information",
	set		=> \&EMC::Message::set_options,
	default		=> EMC::Math::boolean($message->{flag}->{info})
      },
      $indicator."quiet"	=> {
	comment		=> "quiet output",
	set		=> \&EMC::Message::set_options,
	default		=> EMC::Math::boolean(0)
      },
      $indicator."warn"	=> {
	comment		=> "output warnings",
	set		=> \&EMC::Message::set_options,
	default		=> EMC::Math::boolean($message->{flag}->{warn})
      }
    }
  );
  return $message;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $emc = EMC::Common::element($struct, "emc");
  my $message = EMC::Common::element($emc, "message");
  my $set = EMC::Common::element($message, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
 
  $indicator = $indicator ? "message_" : "";
  if ($option eq $indicator."debug") {
    return $message->{flag}->{debug} = EMC::Math::flag($args->[0]); 
  } elsif ($option eq $indicator."expert") {
    return $message->{flag}->{expert} = EMC::Math::flag($args->[0]);
  } elsif ($option eq $indicator."info") {
    return $message->{flag}->{info} = EMC::Math::flag($args->[0]); 
  } elsif ($option eq $indicator."quiet") {
    if (EMC::Math::flag($args->[0])) {
      $message->{flag}->{debug} = 0;
      $message->{flag}->{info} = 0;
      $message->{flag}->{warn} = 0;
    } else {
      set_defaults($message);
    }
    return 0;
  } elsif ($option eq $indicator."warn") {
    return $message->{flag}->{warn} = EMC::Math::flag($args->[0]);
  }
  return undef;
}


sub set_functions {
  my $message = EMC::Common::obtain_hash(shift(@_));
  my $attr = EMC::Common::attributes(@_);
  my $set = EMC::Common::obtain_hash($message, "set");
  my $flags = {"commands" => 1, "indicator" => 1};

  $set->{commands} = \&EMC::Message::set_commands;
  $set->{defaults} = \&EMC::Message::set_defaults;
  $set->{options} = \&EMC::Message::set_options;
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $message;
}


sub set_flag {
  my $flag = shift(@_);
  my $settings = shift(@_);;

  return if (ref($flag) ne "HASH");
  foreach (keys(%{$settings})) {
    $flag->{$_} = $settings->{$_} if (defined($flag->{$_}));
  }
  $EMC::Message::Flag = $flag;
}


sub set_input {
  $EMC::Message::Flag->{input} = shift(@_);
}


sub get_input {
  return $EMC::Message::Flag->{input};
}


# functions

sub origin {
  my ($dummy, $file, $line) = (shift(@_), shift(@_), shift(@_));
  $file = scalar reverse(reverse($file) =~ m{^(.*?)[\\/]});
  print("$file:$line: ", @_);
}


sub info {
  print("Info: ", @_) if ($EMC::Message::Flag->{info});
}


sub debug {
  print("Debug: ", @_) if ($EMC::Message::Flag->{debug});
}


sub tdebug {
  print(join("\t", "Debug:", @_), "\n") if ($EMC::Message::Flag->{debug});
}


sub warning {
  print("Warning: ", @_) if ($EMC::Message::Flag->{warn});
}


sub message {
  print(@_) if ($EMC::Message::Flag->{info});
}


sub error {
  print("Error: ");
  origin(caller, "\n       ", @_);
  print("\n");
  exit(-1);
}


sub dumper {
  my ($file, $line) = (caller)[1,2];
  print("$file:$line: ", Dumper(@_[0]));
}


sub expert {
  if ($EMC::Flag{expert}) { warning(@_); }
  else { error(@_); }
}


sub text_line {
  my $input = ref(@_[0]) eq "ARRAY" ? @_[0]->[0] : "input";
  my $line = ref(@_[0]) eq "ARRAY" ? shift(@_)->[1] : shift(@_);

  $input = $EMC::Message::Flag->{input} if ($input eq "");
  $input = "input" if ($input eq "");
  if ($line<=0) { return (@_); }
  else { 
    my $format = shift(@_);
    $format =~ s/\n/ in line $line of $input\n/g;
    if (scalar(@_)) { return ($format, @_); }
    else { return ($format); }
  }
}


sub error_line {
  error(text_line(@_));
}


sub expert_line {
  expert(text_line(@_));
}


sub tprint {
  print(join("\t", @_), "\n");
}


sub spot {
  origin(caller, @_);
}


sub my_strip {
  my $sep = $^O eq "MSWin32" ? "\\" : "/";
  return dirname(@_).$sep.basename(@_);
}

