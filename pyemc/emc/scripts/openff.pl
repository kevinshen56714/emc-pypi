#!/usr/bin/env perl
#
#  script:	openff.pl
#  author:	Pieter J. in 't Veld
#  date:	January 9, 2019
#  purpose:	Convert SMIRNOFF/OpenFF type force fields
#
#  notes:
#    20190109	Inception
#

# Perl modules

use Cwd;
use Data::Dumper; # use as print(Dumper($var)) where $var can be a pointer to complex variables
use File::Basename;
use File::Path;

use strict;

# Globals

%::OpenFF::General = (
  script	=> basename($0),
  copyright	=> "2019",
  date		=> "January 9, 2019",
  year		=> "2019",
  version	=> "0.0",
  columns	=> 80
);

%::OpenFF::File = (
  input		=> {
    name	=> "default",
    stream	=> 0
  },
  output	=> {
    name	=> "",
    stream	=> 0
  }
);

%::OpenFF::Message = (
  debug		=> 0,
  info		=> 1,
  message	=> 1,
  warning	=> 1
);

%::OpenFF::Project = (
  name		=> ""
);


# Initialization

sub set_options() {
%::OpenFF::Options = (
  debug		=> {
    comment	=> "Toggle debugging output",
    default	=> boolean($::OpenFF::Message{debug})
  },
  help		=> {
    comment	=> "This message",
    default	=> ""
  },
  info		=> {
    comment	=> "Toggle informational output",
    default	=> boolean($::OpenFF::Message{info})
  },
  input		=> {
    comment	=> "Set force field source file name",
    default	=> $::OpenFF::File{input}->{name}
  },
  output	=> {
    comment	=> "Set force field target file name",
    default	=> $::OpenFF::File{output}->{name}
  },
  warning	=> {
    comment	=> "Toggle warning output",
    default	=> boolean($::OpenFF::Message{warning})
  }
);

@::OpenFF::Notes = (
);
}


sub options {
  my @value;
  my $line = shift(@_);
  my $warning = shift(@_);
  my @arg = @_;
  @arg = split("=", @arg[0]) if (scalar(@arg)<2);
  @arg[0] = substr(@arg[0],1) if (substr(@arg[0],0,1) eq "-");
  @arg[0] = lc(@arg[0]);
  my @string = @arg; shift(@string);
  @string = split(",", @string[0]) if (scalar(@string)<2);
  @string = split(":", @string[0]) if (scalar(@string)<2);
  my $n = scalar(@string);

  foreach (@string) { 
    push(@value,
      $_ eq "-" ? 0 :
      substr($_,0,1) eq "/" ? 0 : 
      substr($_,0,1) eq "~" ? 0 :
      my_eval($_));
  }
  if (!defined($::OpenFF::Options{@arg[0]})) { return 1; }
  elsif (@arg[0] eq "help") { help(); }
  elsif (@arg[0] eq "debug") { $::OpenFF::Message{debug} = flag(@string[0]); }
  elsif (@arg[0] eq "info") { $::OpenFF::Message{info} = flag(@string[0]); }
  elsif (@arg[0] eq "input") { $::OpenFF::File{input}->{name} = @string[0]; }
  elsif (@arg[0] eq "output") { $::OpenFF::File{output}->{name} = @string[0]; }
  elsif (@arg[0] eq "warning") { $::OpenFF::Message{warning} = flag(@string[0]); }
  else { return 1; }
  return 0;
}


sub initialize {
  my @warning = ();

  set_options();
  set_origin($0);
  help() if (!scalar(@_));

  foreach (@_) {
    if (substr($_,0,1) eq "-") { 
      help() if (options(-1, \@warning, $_));
    }
    elsif ($::OpenFF::Project{name} eq "") {
      $::OpenFF::File{output}->{name} = $_;
    }
  }

  help() if ($::OpenFF::File{output}->{name} eq ""); 
  header() if ($::OpenFF::Message{info});

  foreach (@warning) { warning("$_\n"); }
}


sub header {
  print("OpenFF Setup v$::OpenFF::General{version} ($::OpenFF::General{date}), ");
  print("(c) $::OpenFF::General{copyright} Pieter J. in 't Veld\n\n");
}


sub set_origin {
  my @arg = split("/", @_[0]);
  @arg = (split("/", $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  $::OpenFF::General{script} = @arg[-1];
  if (defined($ENV{EMC_ROOT})) {
    $::OpenFF::General{root} = $ENV{EMC_ROOT};
    $::OpenFF::General{root} =~ s/~/$ENV{HOME}/g;
  } else {
    pop(@arg); pop(@arg);
    pop(@arg) if (@arg[-1] eq "");
    $::OpenFF::General{root} = join("/", @arg);
  }
}


sub help {
  my $n;
  my $key;
  my $format;
  my $columns;
  my $offset = 3;

  header();
  set_options();
  $columns = $::OpenFF::General{columns}-3;
  foreach (keys %::OpenFF::Options) {
    $n = length($_) if (length($_)>$n); }
  ++$n;
  $format = "%-$n.".$n."s";
  $offset += $n;

  print("Usage:\n  $::OpenFF::General{script} ");
  print("[-command[=#[,..]]] project\n\n");
  print("Options:\n");
  foreach $key (sort(keys %::OpenFF::Options)) {
    printf("  -$format", $key);
    $n = $offset;
    foreach (split(" ", $::OpenFF::Options{$key}->{comment})) {
      if (($n += length($_)+1)>$columns) {
	printf("\n   $format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    if (${$::OpenFF::Options{$key}}{default} ne "") {
      foreach (split(" ", "[$::OpenFF::Options{$key}->{default}]")) {
	if (($n += length($_)+1)>$columns) {
	  printf("\n   $format", ""); $n = $offset+length($_)+1; }
	print(" $_");
      }
    }
    print("\n");
  }

  if (scalar(@::OpenFF::Notes)) {
    printf("\nNotes:\n");
    $offset = $n = 3;
    $format = "%$n.".$n."s";
    foreach (@::OpenFF::Notes) { 
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
  printf("\n");
  exit(-1);
}


# General functions

sub my_eval {
  my $string;
  my $first = 1;
  my $error = 0;

  foreach (split(//, @_[0])) {
    next if ($first && $_ eq "0");
    $string .= $_;
    $first = 0;
  }
  $string = "0" if ($string eq "");
  {
    local $@;
    no warnings;
    unless (eval($string)) { $error = 1; }
  }
  return $error ? $string : eval($string);
}


sub flag {
  return @_[0] eq ""	? 1 : 
    @_[0] eq "auto"	? -1 : 
    @_[0] eq "true"	? 1 : 
    @_[0] eq "false"	? 0 : eval(@_[0]);
}


sub boolean {
  return @_[0] if (@_[0] eq "true");
  return @_[0] if (@_[0] eq "false");
  return @_[0] ? @_[0]<0 ? "auto" : "true" : "false";
}


# i/o routines

sub error {
  printf("Error: ".shift(@_)."%s\n", join(" ", @_));
  exit(-1);
}


sub debug {
  printf("Debug: ".shift(@_)."%s", join(" ", @_)) if ($::OpenFF::Message{debug});
}


sub info {
  printf("Info: ".shift(@_)."%s", join(" ", @_)) if ($::OpenFF::Message{info});
}


sub warning {
  printf("Warning: ".shift(@_)."%s", join(" ", @_)) if ($::OpenFF::Message{warning});
}


sub message {
  printf(shift(@_)."%s", join(" ", @_)) if ($::OpenFF::Message{message});
}


sub fexpand {
  return @_[0] if (substr(@_[0],0,1) ne "~");
  return $ENV{HOME}.substr(@_[0],1) if (substr(@_[0],1,1) eq "/");
  return $ENV{HOME}."/../".substr(@_[0],1);
}


sub fexist {
  my $name = fexpand(shift(@_));
  my $suffix = shift(@_);

  return 1 if (-e $name);
  my @arg = split(" ", `ls *$suffix 2>&1`);
  return 1 if (-e $arg[0]);
  return 0;
}


sub fopen {
  my $name = fexpand(shift(@_));
  my $mode = shift(@_);
  my $suffix = shift(@_);
  my $stream;
  
  if ($mode eq "r") {
    open($stream, "<$name");
    if (length($suffix) && !scalar(stat($stream))) {
      my @arg = split(" ", `ls *$suffix 2>&1`);
      open($stream, "<".($name = $arg[0])) if ($arg[0] ne "ls:");
    }
  } elsif ($mode eq "w") {
    open($stream, ">$name");
  } else {
    error("unsupported mode \"$mode\"\n");
  }
  if (!scalar(stat($stream))) {
    error("cannot open \"$name\"\n");
  }
  return length($suffix) ? ($stream, $name) : $stream;
}


sub check_exist {
  my $type = shift(@_);
  my $name = fexpand(shift(@_));

  if (!$::EMC::Replace{flag} && -e $name) {
    warning("\"$name\" exists; use -replace flag to overwrite\n");
  } elsif (!defined($::EMC::CheckExist{$type})) {
    ${$::EMC::CheckExist{$type}}{$name} = 1; return 0;
  } elsif (!defined(${$::EMC::CheckExist{$type}}{$name})) {
    ${$::EMC::CheckExist{$type}}{$name} = 1; return 0;
  }
  return 1;
}


# Read OpenFF force field

sub split_label {
  my @labels = ();
  my @connects = ();
  my $label = "";
  my $connect = "";
  my $level = 0;
  my $paren = 0;
  my $side = "";

  foreach (split("", @_[0])) {
    if ($_ eq "[") {
      if (!$level++ && $connect ne "") { push(@connects, $connect); }
    }
    elsif ($_ eq "]") { 
      if (!--$level) { push(@labels, $label); $label = ""; }
    }
    elsif ($_ eq "(") {
    }
    elsif ($_ eq ")") {
    }
    else {
      if ($level) { $label .= $_; }
      else { $connect .= $_; }
    }
  }
  return (labels => [@labels], connects => [@connects]);
}


sub read_field {
  info("reading \'$::OpenFF::File{input}->{name}\'\n");

  my $stream = $::OpenFF::File{input}->{stream} = fopen(
    $::OpenFF::File{input}->{name}, "r", ""
  );
  my %identifiers = (
    DATE => 1, AUTHOR => 2, 
    NONBON => 3, BOND => 4, ANGL => 5, DIHE => 6, IMPR => 7
  );
  my $line = 0;
  my $mode = 0;
  my $comment;

  foreach(<$stream>) {
    my @arg = split(" ");
    
    $::OpenFF::Field{name} = @arg[1] if (!$line++);
    next if (!scalar(@arg));
    if (@arg[0] eq "#") {
      shift(@arg);
      $comment = join(" ", @arg);
      next;
    }
    if (defined($identifiers{@arg[0]})) {
      debug("identifier \'@arg[0]\' starts in line $line\n");
      $mode = $identifiers{@arg[0]};
      $comment = "";
      next;
    }
    if ($mode==1) {

      # DATE

      shift(@arg);
      $::OpenFF::Field{date} = join(" ", @arg);
    }
    elsif ($mode==2) {

      # AUTHOR

      $::OpenFF::Field{author} = join(" ", @arg);
    }
    elsif ($mode==3) {

      # NONBON

      my $id = shift(@arg);
      my $sigma = shift(@arg);
      my $epsilon = shift(@arg);
      my $class = $comment eq "" ? "generic" : $comment;
      my $remark = join(" ", @arg);
      $::OpenFF::Field{nonbond}{$class}{$id} = [$sigma, $epsilon, $remark];
    }
    elsif ($mode==4) {

      # BOND
      
      my $id = shift(@arg);
      my $k = shift(@arg);
      my $l = shift(@arg);
      my %result = split_label($id);
      my $connects = $result{connects};
      my $labels = $result{labels};

      print(__LINE__, ": $line, id: @{$labels}, connect: @{$connects}\n");
    }
    elsif ($mode==5) {


      # ANGL

    }
    elsif ($mode==6) {


      # DIHE

    }
    elsif ($mode==7) {


      # IMPR

    }
  }
  
  close($stream);

  print("nonbond\n");
  foreach (sort(keys(%{$::OpenFF::Field{nonbond}}))) {
    my $class = $_;
    my $ptr = $::OpenFF::Field{nonbond}{$class};
    print("  class: $class ($ptr)\n");
    foreach (sort(keys(%{$ptr}))) {
      print("    type: $_\n");
    }
  }
}


# Write EMC force field

sub write_field {
}


# Main

{
  initialize(@ARGV);

  read_field();
  write_field();

  print("\n") if ($::OpenFF::Message{info});
}

