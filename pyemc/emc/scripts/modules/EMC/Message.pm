#!/usr/bin/env perl
#
#  module:	EMC::Message.pm
#  author:	Pieter J. in 't Veld
#  date:	November 24, 2021, January 15, 2022.
#  purpose:	Message routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "message_" indicator in commands
#        commands	BOOLEAN	include commands in $emc->{options}
#
#  specific members:
#    context		HASH	optional settings
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
@EXPORT = qw(&format_output);

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
  my $message = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
 
  set_functions($message, $attr);
  set_defaults($message);
  set_commands($message);
  return $message;
}


# initialization

$EMC::Message::Flag = {
  debug		=> 0,
  expert	=> 0,
  exit		=> undef,
  info		=> 1,
  input		=> "",
  trace		=> 0,
  warn		=> 1
};

sub set_defaults {
  my $message = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $EMC::Message::Flag = $message->{flag} = EMC::Common::attributes(
    defined($message->{flag}) ? $message->{flag} : {},
    $EMC::Message::Flag
  );
  $message->{identity} = EMC::Common::attributes(
    EMC::Common::hash($message, "identity"),
    $EMC::Message::Identity
  );

  return $message;
}


sub set_commands {
  my $message = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($message, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;

  $indicator = $indicator ? "message_" : "";
  $message->{commands} = EMC::Common::attributes(
    EMC::Common::hash($message, "commands"),
    {
      $indicator."debug"	=> {
	comment		=> "output debugging information",
	set		=> \&EMC::Message::set_options,
	default		=> EMC::Math::boolean($message->{flag}->{debug})
      },
#      $indicator."expert"	=> {
#	comment		=> "set expert mode",
#	set		=> \&EMC::Message::set_options,
#	default		=> EMC::Math::boolean($message->{flag}->{expert})
#      },
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
      $indicator."trace"	=> {
	comment		=> "provide function trace upon error",
	set		=> \&EMC::Message::set_options,
	default		=> EMC::Math::boolean($message->{flag}->{trace})
      },
      $indicator."warn"	=> {
	comment		=> "output warnings",
	set		=> \&EMC::Message::set_options,
	default		=> EMC::Math::boolean($message->{flag}->{warn})
      }
    }
  );
  foreach (keys(%{$message->{commands}})) {
    my $ptr = $message->{commands}->{$_};
    $ptr->{set} = \&EMC::Message::set_options if (!defined($ptr->{set}));
  }
  return $message;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $message = EMC::Common::element($struct, "module");
  my $set = EMC::Common::element($message, "set");
  my $indicator = defined($set) ? $set->{flag}->{indicator} : 1;
 
  $indicator = $indicator ? "message_" : "";
  if ($option eq $indicator."debug") {
    return $message->{flag}->{debug} = EMC::Math::flag($args->[0]); 
#  } elsif ($option eq $indicator."expert") {
#    return $message->{flag}->{expert} = EMC::Math::flag($args->[0]);
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
  } elsif ($option eq $indicator."trace") {
    return $message->{flag}->{trace} = EMC::Math::flag($args->[0]);
  } elsif ($option eq $indicator."warn") {
    return $message->{flag}->{warn} = EMC::Math::flag($args->[0]);
  }
  return undef;
}


sub set_functions {
  my $message = EMC::Common::hash(shift(@_));
  my $attr = EMC::Common::attributes(@_);
  my $set = EMC::Common::hash($message, "set");
  my $flags = {commands => 1, indicator => 1, items => 1};

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

  EMC::Common::attributes($EMC::Message::Flag, $flag);
  return $EMC::Message::Flag;
}


sub get_flag {
  return defined(@_[0]) ? $EMC::Message::Flag->{@_[0]} : $EMC::Message::Flag;
}


sub set_input {
  $EMC::Message::Flag->{input} = shift(@_);
}


sub get_input {
  return $EMC::Message::Flag->{input};
}


# functions

sub debug {
  printf("Debug: ".shift(@_), @_) if ($EMC::Message::Flag->{debug});
}


sub dumper {
  my $fmt = ref(@_[0]) eq "" ? shift(@_) : "";

  local $Data::Dumper::Purity = 1;
  local $Data::Dumper::Terse = 1;
  local $Data::Dumper::Indent = 1;
  local $Data::Dumper::Useqq = 1;
  #local $Data::Dumper::Deparse = 1;
  local $Data::Dumper::Quotekeys = 0;
  local $Data::Dumper::Sortkeys = 1;
  local $Data::Dumper::Trailingcomma = 1;
  origin([caller], $fmt, Dumper(@_[0]));
}


sub error {
  trace() if ($EMC::Message::Flag->{trace});

  my $caller = ref(@_[0]) eq "ARRAY" ? shift(@_) : [caller];
  my @args = @_;

  @args[0] = ucfirst(@args[0]) if (scalar(@args));
  print("Error: ");
  origin($caller, "\n       ", @args);
  print("\n");
  $EMC::Message::Flag->{exit}->(-1) if ($EMC::Message::Flag->{exit});
  exit(-1);
}


sub error_line {
  error([caller], text_line(@_));
}


sub exit {
  my $code = shift(@_);
  my ($file, $line) = (caller)[1,2];
  
  $EMC::Message::Flag->{exit}->(-1) if ($EMC::Message::Flag->{exit});
  trace() if ($EMC::Message::Flag->{trace});
  print("$file:$line: [exit = $code]", @_);
  print(scalar(@_) ? "\n" : "\n\n");
  exit($code);
}


sub expert {
  my $caller = ref(@_[0]) eq "ARRAY" ? shift(@_) : [caller];
  if ($EMC::Message::Flag->{expert}) { warning(@_); }
  else { error($caller, @_); }
}


sub expert_line {
  expert([caller], text_line(@_));
}


sub info {
  printf("Info: ".shift(@_), @_) if ($EMC::Message::Flag->{info});
}


sub keys {
  my $fmt = ref(@_[0]) eq "" ? shift(@_) : "";

  if (scalar(@_)) {
    foreach (@_) {
      origin([caller], $fmt,
	ref($_) eq "HASH" ? 
	  "{".join(", ", map({defined($_) ? $_ : "undef"} sort(keys(%{$_})))).
	  "}" : "undef", "\n");
    }
  } else {
    origin([caller], $fmt, "undef", "\n");
  }
}


sub list {
  my $fmt = ref(@_[0]) eq "" ? shift(@_) : "";

  foreach (@_) {
    origin([caller], $fmt,
      ref($_) eq "ARRAY" ? 
	"{".join(", ", map({defined($_) ? $_ : "undef"} @{$_}))."}" : 
	"undef", "\n");
  }
}


sub message {
  printf(@_) if ($EMC::Message::Flag->{info});
}


sub origin {
  my ($file, $line) = ref(@_[0]) eq "ARRAY" ? @{shift(@_)}[1,2] : (caller)[1,2];
  
  #$file = scalar reverse(reverse($file) =~ m{^(.*?)[\\/]});
  print("$file:$line: ", @_);
}


sub spot {
  my $caller = ref(@_[0]) eq "ARRAY" ? shift(@_) : [caller];
  origin($caller, @_);
}


sub tdebug {
  print(join("\t", "Debug:", @_), "\n") if ($EMC::Message::Flag->{debug});
}


sub text_line {
  my ($input, $line);

  if (ref(@_[0]) eq "ARRAY") {
    ($input, $line) = shift(@_)->[0,1];
  } else {
    my @l = split(":", shift(@_));
    $input = scalar(@l)>1 ? shift(@l) : undef;
    $line = shift(@l);
  }
  $input = $EMC::Message::Flag->{input} if ($input eq "");
  $input = "input" if ($input eq "");
  if ($line<=0) { return (@_); }
  else { 
    my $format = shift(@_);
    $format =~ s/\n/ at line $line of $input\n/g;
    if (scalar(@_)) { return ($format, @_); }
    else { return ($format); }
  }
}


sub tprint {
  print(join("\t", @_), "\n");
}


sub trace {
  my $i = 0;
  my $divider = join("", ("-") x 79);

  printf("Back Trace:\n\n");
  printf("%-3.3s %-35.35s %s\n", "lvl", "call", "call location");
  print("$divider\n");
  while ((my @call = (caller($i++)))) {
    printf("%-3.3s ", "$i");
    printf("%-35.35s ", $call[3]);
    printf("%s:%s\n", EMC::IO::scrub_dir($call[1]), $call[2]);
  }
  print("$divider\n\n");
}


sub tspot {
  my $caller = ref(@_[0]) eq "ARRAY" ? shift(@_) : [caller];
  origin($caller, join("\t", @_), "\n");
}


sub warning {
  printf("Warning: ".shift(@_), @_) if ($EMC::Message::Flag->{warn});
}


sub warning_line {
  warning(text_line(@_));
}


# formatting

sub format_newline {
  my $output = shift(@_);
  my $col = shift(@_);
  my $offset = shift(@_);
  my $index = shift(@_);
  my $ntabs = int($offset/8);
  my $i;

  ${$output} .= "\n" if ($index);
  for ($i=0; $i<$ntabs; ++$i) { ${$output} .= "\t"; }
  for ($i=0; $i<$offset-8*$ntabs; ++$i) { ${$output} .= " "; } 
  ${$col} = $offset;
}


sub format_output {
  my $separator = shift(@_);
  my $string = shift(@_);
  return $separator ? "\n" : "" if ($string eq "");
  my $offset = shift(@_);
  my $tab = shift(@_);
  my @arg = ref($string) eq "ARRAY" ? @{$string} : split(" ", $string);
  my $first = shift(@arg);
  my $rest = join(" ", @arg);
  my $output = "";
  my $i;
  my $n;

  $n = int($offset/8);
  for ($i = 0; $i<$n; ++$i) {
    $output .= "\t";
  };
  $tab = 0 if (($tab -= $n)<0);
  $offset -= 8*$n;
  for ($i = 0; $i<$offset; ++$i) {
    $output .= " ";
  };
  return "$output$string\n" if (substr($string,0,2) eq "(*");
  $output .= $first;
  return "$output".($separator ? ",\n" : "") if ($rest eq "");
  if (($n = $tab-int(length($output)/8))>0) {
    for ($i = 0; $i<$n; ++$i) {
      $output .= "\t";
    };
  } else {
    $output .= " ";
  }
  return "$output-> $rest".($separator ? ",\n" : "");
}


sub format_output_new {
  my $separator = shift(@_);
  my $string = trim(shift(@_));
  return $separator ? "\n" : "" if ($string eq "");
  my $offset = shift(@_);
  my $tab = shift(@_);
  my @arg = split(" ", $string);
  my $output = "";
  my $newline = 1;
  my $index = 0;
  my $ivar = 0;
  my $col = 0;
  my $nvars;
  my $i;

  format_newline(\$output, \$col, $offset, 0);
  return $output .= $string if (substr($string,0,2) eq "(*");

  $string = shift(@arg);
  $string .= " -> ".join(" ", @arg) if (scalar(@arg));
  $string =~ s/ //g;
  $nvars = scalar(@arg = split("->", $string));
  foreach (@arg) {
    my @arg = split(",");
    my $last = $index+scalar(@arg);
    my $var = ++$ivar<$nvars ? pop(@arg) : "";
   
    foreach (@arg) {
      my $v = $index+1<$last ? "$_, " : $_;
      my $l = length($_);
      my $n = () = $_ =~ m/\{/g; 
      $offset += 2*$n;
      format_newline(\$output, \$col, $offset, $index ? 1 : 0) if ($col+$l>78);
      $n -= () = $_ =~ m/\}/g;
      $offset += 2*$n;
      $output .= $v;
      $col += $l;
      ++$index;
    }
    if ($ivar<$nvars) {
      my $l = length($var);
      if ($col+$l+4>78) {
	format_newline(\$output, \$col, $offset, $index ? 1 : 0);
	$newline = 1;
      }
      if ($newline) {
	my $v = $var;
	my $n = $tab-int(($col+$l)/8);
	if ($n>0) {
	  for ($i = 0; $i<$n; ++$i) {
	    $v .= "\t"; $col += 8;
	  };
	} else {
	  $v .= " "; $col += 1;
	}
	$output .= $v."-> ";
	$col += $l+3;
      } else {
	$output .= $var." -> ";
	$col += $l+4;
      }
      $newline = 0;
    }
  }
  return $output.($separator ? ",\n" : "");
}

