#!/usr/bin/env perl
#
#  program:	EMC::Field.pm
#  author:	Pieter J. in 't Veld
#  date:	May 21, 2016, September 16, 2017, April 4, August 3, 
#		November 3, 16, 2018
#  purpose:	Interpret force field definition file and convert it into
#  		EMC textual force field formats; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20160521	Conception by copy from trappe.pl v1.0
#    20170916	Conversion into Perl package
#    20180404	Added colloidal force field
#    		Added nonbond charge
#    		Generalized writing of output
#    20180803	Fixed addition of rules
#    		Changed command item interpretation
#    		Added error handling
#    20181103	Adapted spacing in define paragraph
#    		Added nonbond brownian and lubricate
#    20181116	Added parameter evaluation and formatting
#

# module definitions

package EMCField;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.2";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

# functions

sub set_variables {
  $::EMCField::Script = "EMCField.pm";
  $::EMCField::Author = "Pieter J. in 't Veld";
  $::EMCField::Version = "1.2";
  $::EMCField::Date = "November 3, 2018";
  $::EMCField::EMCVersion = "9.4.4";
  $::EMCField::Format = "%15.10e";
  $::EMCField::Format = "%g";

  $::EMCField::Script = $::EMC::Script if ($::EMC::Script ne "");
  $::EMCField::Author = $::EMC::Author if ($::EMC::Author ne "");
  $::EMCField::Version = $::EMC::Version if ($::EMC::Version ne "");
  $::EMCField::Date = $::EMC::Date if ($::EMC::Date ne "");
  $::EMCField::EMCVersion = $::EMC::EMCVersion if ($::EMC::EMCVersion ne "");
  $::EMCField::Format = $::EMC::Field{format} if ($::EMC::Field{format} ne "");

  $::EMCField::Type = {};
  $::EMCField::Index = {};
  $::EMCField::Masses = {};
  $::EMCField::Nonbond = {};
  $::EMCField::Bond = {};
  $::EMCField::BondAuto = {};
  $::EMCField::Angle = {};
  $::EMCField::AngleAuto = {};
  $::EMCField::Torsion = {};
  $::EMCField::TorsionAuto = {};
  $::EMCField::Improper = {};
  $::EMCField::ImproperAuto = {};
  $::EMCField::Equivalence = {};
  @::EMCField::References = ();
  @::EMCField::Precedences = ();
  $::EMCField::Increments = {};
  $::EMCField::Templates = {};
  $::EMCField::Active = {};
  $::EMCField::Rules = {};
  $::EMCField::Extras = {};
  $::EMCField::Dummy = lc("DM");
  $::EMCField::LonePair = lc("LP");
  $::EMCField::Wildcard = "*";
  $::EMCField::Anything = "?";
  $::EMCField::NTorsions = 0;
  $::EMCField::Warning = 1;
  $::EMCField::Message = 1;
}


sub set_define {
  my $name = shift(@_);
  my @order = (
    "ffmode", "fftype", "ffdepth", "version", "created", "length", "energy",
    "density", "mix", "inner", "outer", "cutoff", "nbonded", "pair14", "angle",
    "torsion", "improp");
  my %init = (
    born => [
      "born", "atomistic", "4", "1.0", "", "angstrom", "kcal/mol",
      "g/cc", "berthelot", "", "", "10.5", "0", "exclude", "error",
      "error", ""
    ],
    charmm => [
      "charmm", "atomistic", "4", "1.0", "", "angstrom", "kcal/mol",
      "g/cc", "berthelot", "10.0", "", "12.0", "3", "include", "error",
      "error", ""
    ],
    colloid => [
      "colloid", "coarse", "1", "1.0", "", "1e-6", "1e-21",
      "1", "none", "1.00001", "1.25", "2.5", "1", "", "ignore",
      "", ""
    ],
    dpd => [
      "dpd", "coarse", "1", "1.0", "", "reduced", "reduced",
      "reduced", "none", "", "", "1.0", "0", "", "ignore",
      "ignore", "ignore"
    ],
    martini => [
      "martini", "coarse", "1", "1.0", "", "nanometer", "kj/mol",
      "g/cc", "none", "0.9", "", "1.2", "1", "off", "ignore",
      "ignore", "ignore"
    ],
    mie => [
      "mie", "coarse", "", "1.0", "", "angstrom", "kcal/mol",
      "g/cc", "none", "", "", "15.0", "1", "off", "warn",
      "ignore", ""
    ],
    opls => [
      "opls", "atomistic", "4", "1.0", "", "angstrom", "kcal/mol",
      "g/cc", "geometric", "", "", "12.0", "3", "include", "error",
      "error", ""
    ],
    sdk => [
      "sdk", "coarse", "", "1.0", "", "angstrom", "kcal/mol",
      "g/cc", "none", "", "", "15.0", "1", "off", "warn",
      "ignore", ""
    ],
    standard => [
      "standard", "coarse", "1", "1.0", "", "reduced", "reduced",
      "reduced", "berthelot", "", "", "1.0", "1", "", "ignore",
      "ignore", "ignore"
    ],
    trappe => [
      "trappe", "united", "4", "1.0", "", "angstrom", "kelvin",
      "g/cc", "berthelot", "", "", "14", "3", "exclude", "error",
      "error", ""
    ]
  );
  my @header = ("type1", "type2");

  if ($name eq "colloid") {
    my @h = @header;
    push(@header, "a_ham", "sigma", "d1", "d2", "cutoff");
    $::EMCField::Header{charge} = 
      "# ".join("\t", @h, "a_yuk", "kappa", "d1", "d2", "cutoff");
    $::EMCField::Header{brownian} = 
      "# ".join("\t", @h, "inner", "outer");
    $::EMCField::Header{lubricate} = 
      "# ".join("\t", @h, "inner", "outer");
  } elsif ($name eq "dpd") {
    push(@header, "a", "cutoff", "gamma");
  } else {
    push(@header, "sigma", "epsilon");
  }
  $::EMCField::Header{nonbond} = "# ".join("\t", @header);
  if (!defined($init{$name})) {
    error("unsupported force field name '$name'\n");
  }
  my $i; for ($i=0; $i<scalar(@order); ++$i) {
    $::EMCField::Define{$order[$i]} = @{$init{$name}}[$i];
  }
  $::EMCField::Define{created} = (split("\n", `date +"%Y-%m-%d"`))[0];
  $::EMCField::Nonbond{join("\t", $::EMCField::Anything, $::EMCField::Anything)} = join("\t", 0, 0) if ($::EMCField::Flag{rules});
  @::EMCField::OrderDefine = @order;
}


sub error {
  printf("Error: %s\n", join(" ", @_));
  exit(-1);
}


sub error_line {
  my $line = shift(@_);
  if ($line<0) { error(@_); }
  else { 
    my $format = shift(@_);
    $format =~ s/\n/ in line $line of input\n/g;
    if (scalar(@_)) { error($format, @_); }
    else { error($format); }
  }
}


sub info {
  printf("Info: %s", join(" ", @_)) if ($::EMCField::Message);
}


sub warning {
  printf("Warning: %s", join(" ", @_)) if ($::EMCField::Warning);
}


sub message {
  printf("%s", join(" ", @_)) if ($::EMCField::Message);
}


sub ftest {
  my $name = shift(@_);
  my $result;
  my $file;

  open($file, "<$name");
  $result = scalar($file) ? 1 : 0;
  close($file);
  return $result;
}


sub fopen {
  my $name = shift(@_);
  my $mode = shift(@_);
  my $result;
  my $file;

  error("illegal mode\n") if (!($mode eq "r" || $mode eq "w"));
  info("opening \"$name\" for", ($mode eq "r" ? "read" : "writ")."ing\n");
  open($file, ($mode eq "r" ? "<" : ">").$name);
  error("cannot open file \"$name\"\n") if (!scalar($file));
  return $file;
}


sub fclose {
  my $file = shift(@_);

  close($file) if (scalar($file));
}


sub open_input {
  if (!defined($::EMCField::Topology)) {
    my $line = 0;
    my $stream = fopen($::EMCField::DefineName, "r");
    foreach (<$stream>) { 
      chop;
      push(@{$::EMCField::Topology}, {verbatim => $_, line => ++$line});
    }
    fclose($stream);
  }
}

sub open_output {
  $::EMCField::OUT_PARMS = fopen($::EMCField::CreatedParameterName, "w") if (!scalar($::EMCField::OUT_PARMS));
  $::EMCField::OUT_TOPOL = fopen($::EMCField::CreatedTopologyName, "w") if (!scalar($::EMCField::OUT_TOPOL) && $::EMCField::Flag{rules});
}


sub close_all {
  fclose($::EMCField::OUT_PARMS);
  fclose($::EMCField::OUT_TOPOL) if ($::EMCField::Flag{rules});
}


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


sub type_case {
  return lc(@_[0]);
}


sub element {
  my $f0 = substr(@_[0], 0, 1);
  my $f1 = substr(@_[0], 1, 1);

  return $f0 if ($f1 ne lc($f1));
  return $f0 if (lc($f1) lt "a" || lc($f1) gt "z");
  return @_[0];
}


sub split_data {
  my @result;
  my @arg = split(",", @_[0]);

  foreach(@arg) { foreach (split("\t")) { push(@result, $_); } }
  @result = split(" ", @_[0]) if (scalar(@result)==1);
  foreach (@result) { $_ =~ s/^\s+//g; $_ =~ s/\s+$//g; }
  push (@result, ",") if (substr(@_[0],-1,1) eq ",");
  @arg = (); 
  foreach (@result) {
    last if (substr($_,0,1) eq "#");
    push(@arg, $_) if ($_ ne "");
  }
  return @arg;
}


sub get_define {
  my $command = 0;
  my @message = ("", "defines", "masses", "precedences", "equivalences",
    "pairs", "bonds", "angles", "torsions", "impropers",
    "references", "rules", "templates");
  my @commands = (
    ["define", 1], ["mass", 2], ["precedence", 3], ["equivalence", 4],
    ["nonbond", 5], ["bond", 6], ["angle", 7], ["torsion", 8],
    ["improper", 9], ["references", 10], ["rules", 11],
    ["templates", 12], ["charge", 13], ["brownian", 14], ["lubricate", 15]);
  my @index = ("nonbond", "bond", "angle", "torsion", "improper");
  my @nargs = (
    1, 1, 6, 1, 3,
    4, 4, 5, 7, 6,
    4, 3, 2);
  my $index = 0;
  my $ffname;

  $::EMCField::Rules = {};
  $::EMCField::Masses = {};
  $::EMCField::Extras = {};
  $::EMCField::Active = {};
  $::EMCField::Header = {};
  $::EMCField::Element = {};
  $::EMCField::Nonbond = {};
  $::EMCField::Equivalence = {};
  foreach(@{$::EMCField::Topology}) {
    my $line = $_->{line};
    my @arg = split_data($_->{verbatim});
    next if (substr($_, 0, 1) eq "#");
    if (!$command) {
      if (join(" ", @arg[0,1]) eq "ITEM DEFINE") {
	$command = 1;
      } elsif (join(" ", @arg[0,1]) eq "ITEM RULES") {
	$::EMCField::Flag{rules} = 1;
      }
      next;
    }
    if (join(" ", @arg[0, 1]) eq "ITEM END") {
      $command = 0; next;
    }
    foreach (@arg) { $_ = lc($_); }
    next if (@arg[0] ne "ffname" && @arg[0] ne "ffmode");
    $ffname = @arg[1];
  }
  set_define($ffname);
  $command = 0;
  foreach(@{$::EMCField::Topology}) {
    my $line = $_->{line};
    my @arg = split_data($_->{verbatim});
    if (!$command) {
      next if (substr(@arg[0], 0, 1) eq "#");
      if (@arg[0] eq "ITEM") {
	foreach (@commands) {
	  last if (($command = lc(@arg[1]) eq @{$_}[0] ? @{$_}[1] : 0));
	}
	if (!$command) {
	  error_line($line, "non-existent field item '@arg[1]'\n");
	}
      }
      info("commanding $message[$command]\n") if ($command);
      next;
    }
    $command = 0 if (join(" ", @arg[0, 1]) eq "ITEM END");
    next if (!$command);
    if (substr(@arg[0], 0, 1) eq "#") {
      if ($command>=5 && $command<=9) {
	@arg = split(" ");
	if (join(" ", @arg[1,2]) eq "type1 type2") {
	  $::EMCField::Header{@index[$command-5]} = @{$_}[0];
	}
      }
      next;
    }
    next if (scalar(@arg)<@nargs[$command]);
    if ($command==1) {						# define
      @arg[0] = "ffmode" if (lc(@arg[0]) eq "ffname");
      $::EMCField::Define{lc($arg[0])} = $arg[1];
    } elsif ($command==2) {					# masses
      $arg[0] = type_case($arg[0]);
      $::EMCField::Element{$arg[0]} = @arg[2];
      $::EMCField::Masses{$arg[0]} = 
	join("\t", @arg[0..4], join(" ", splice(@arg, 5)));
    } elsif ($command==3) {					# precedence
      next if (!scalar(@arg));
      push(@::EMCField::Precedences, type_case(join(" ", @arg)));
    } elsif ($command==4) {					# equivalence
      $::EMCField::Type{$arg[1]} = 1;
      while (scalar(@arg)<6) { push(@arg, @arg[-1]); }
      $::EMCField::Equivalence{$arg[0]} =
      $::EMCField::EquivalenceAuto{$arg[0]} = join("\t", @arg);
    } elsif ($command==10) {					# references
      push(@::EMCField::References, join("\t", @arg[0,3,1,2]));
    } elsif ($command==11) {					# rules
      $arg[0] = type_case($arg[0]);
      my $ext = 0; ++$index;
      foreach (split(" ", $arg[-1])) {
	$::EMCField::Rules{$index.".".$ext++} = join("\t", @arg[0,1], $_);
      }
    } elsif ($command==12) {					# templates
      $::EMCField::Templates{$arg[0]} = $arg[1];
    } elsif ($command==5) {					# nonbond
      foreach(@arg[0 .. 2]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,2)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$::EMCField::NonbondAuto{$key} = $k;
      } else {
	$::EMCField::Nonbond{$key} = $k;
      }
    } elsif ($command==13) {					# charge
      foreach(@arg[0 .. 2]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,2)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$::EMCField::ChargeAuto{$key} = $k;
      } else {
	$::EMCField::Charge{$key} = $k;
      }
    } elsif ($command==14) {					# brownian 
      foreach(@arg[0 .. 2]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,2)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$::EMCField::BrownianAuto{$key} = $k;
      } else {
	$::EMCField::Brownian{$key} = $k;
      }
    } elsif ($command==15) {					# lubricate
      foreach(@arg[0 .. 2]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,2)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$::EMCField::LubricateAuto{$key} = $k;
      } else {
	$::EMCField::Lubricate{$key} = $k;
      }
    } elsif ($command==6) {					# bond
      foreach(@arg[0 .. 2]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,2)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$::EMCField::BondAuto{$key} = $k;
      } else {
	$::EMCField::Bond{$key} = $k;
      }
    } elsif ($command==7) {					# angle
      foreach(@arg[0 .. 3]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,3)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$::EMCField::AngleAuto{$key} = $k;
      } else {
	$::EMCField::Angle{$key} = $k;
      }
    } elsif ($command==8) {					# torsion
      foreach(@arg[0 .. 4]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,4)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$::EMCField::TorsionAuto{$key} = $k;
      } else {
	$::EMCField::Torsion{$key} = $k;
      }
    } elsif ($command==9) {					# improper
      foreach(@arg[0 .. 4]) { $_ = type_case($_); }
      my $key = join("\t", arrange_imp(splice(@arg,0,4)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$::EMCField::ImproperAuto{$key} = $k;
      } else {
	$::EMCField::Improper{$key} = $k;
      }
    }
  }
}


sub set_precedences {
  my @precedences;
  my $first = shift(@::EMCField::Precedences);
  my $last = pop(@::EMCField::Precedences);

  $first = "(" if ($first eq "");
  $last = ")" if ($last eq "");
  foreach(sort(keys(%::EMCField::Masses))) {
    my $flag = 0;
    my $type = $_;
    foreach (@::EMCField::Precedences) {
      my @arg = split(" ");
      foreach (@arg) {
	$_ =~ s/\(//g;
	$_ =~ s/\)//g;
	$flag = ($_ eq $type ? 1 : 0);
	last if ($flag); 
      }
      last if ($flag);
    }
    push(@precedences, "($_)") if (!$flag);
  }
  @precedences = sort({
      my $c = substr($a,0,4);
      my $d = substr($b,0,4);
      $c lt $d ? -1 : $c gt $d ? 1 : 0 } @precedences);
  push(@::EMCField::Precedences, @precedences);
  unshift(@::EMCField::Precedences, $first);
  push(@::EMCField::Precedences, $last);
}


sub set_equivalences {
  my $index;
  my $type;
  my $typen;
  my $element;

  foreach (keys(%::EMCField::Index)) {
    my @arg = split("\t", $::EMCField::Index{$_});
    ($index, $element, $type, $typen) = @arg[0,1,2,3];
    if ($::EMCField::Equivalence{$typen} eq "") {
      $::EMCField::Equivalence{$typen} = 
	join( "\t", $typen, $typen, $type, $type, $type, $type);
      $::EMCField::EquivalenceAuto{$typen} = 
	join( "\t", $typen, $type, $type, $type, $type, $type);
    }
  }
}


sub put_header {
  my $file = shift(@_);

  return if (!scalar($file));

  my $text = shift(@_);
  my $definition = shift(@_);
  my $name = uc($::EMCField::Define{ffmode});
  my $define = $::EMCField::DefineName;

  $define = " using $define" if ($define ne "");

  printf($file "#
#  $name $text $define
#  converted by $::EMCField::Script v$::EMCField::Version, $::EMCField::Date by $::EMCField::Author
#  to be used in conjuction with EMC v$::EMCField::EMCVersion or higher
#\n");

  return if (!$definition);
  printf($file "\n# Force field definition\n\n");
  printf($file "ITEM\tDEFINE\n\n");
  foreach (@::EMCField::OrderDefine) {
    next if ($::EMCField::Define{$_} eq "");
    my $space = 2-int(length($_)/8);
    my $space = (" ", "\t", "\t\t")[$space<0 ? 0 : $space];
    printf($file "%s%s%s\n", uc($_), $space, uc($::EMCField::Define{$_}));
  }
  printf($file "\nITEM\tEND\n");
}


sub print_headers {
  info("writing headers\n");
  put_header($::EMCField::OUT_TOPOL, "topology", 0);
  put_header($::EMCField::OUT_PARMS, "interaction parameters", 1);
}


sub print_masses {
  return if (!scalar(keys(%::EMCField::Masses)));

  info("writing masses\n");
  printf($::EMCField::OUT_PARMS "\n# Masses\n\n");
  printf($::EMCField::OUT_PARMS "ITEM\tMASS\n\n");
  printf($::EMCField::OUT_PARMS "# type\tmass\telement\tncons\tcharge\tcomment\n\n");
  foreach(sort values(%::EMCField::Masses)) {
    my @arg = split("\t");
    my $type = shift(@arg);
    my $mass = eval(shift(@arg));
    my $element = shift(@arg);
    next if ($::EMCField::Element{$type} eq "");
    printf($::EMCField::OUT_PARMS "%s\t$::EMCField::Format\t%s\n", $type, $mass, join("\t", $::EMCField::Element{$type}, @arg));
  }
  printf($::EMCField::OUT_PARMS "\nITEM\tEND\n");
}


sub print_equivalences {
  return if (!scalar(keys(%::EMCField::Equivalence)));

  info("writing equivalences\n");
  printf($::EMCField::OUT_PARMS "\n# Typing equivalences\n\n");
  printf($::EMCField::OUT_PARMS "ITEM\tEQUIVALENCE_AUTO\n\n");
  printf($::EMCField::OUT_PARMS "# type\tpair\tbond\tangle\ttorsion\timproper\n\n");
  foreach(sort keys(%::EMCField::EquivalenceAuto)) {
    printf($::EMCField::OUT_PARMS "%s\n", $::EMCField::EquivalenceAuto{$_});
  }
  printf($::EMCField::OUT_PARMS "\nITEM\tEND\n");
  printf($::EMCField::OUT_PARMS "\n# Typing equivalences\n\n");
  printf($::EMCField::OUT_PARMS "ITEM\tEQUIVALENCE\n\n");
  printf($::EMCField::OUT_PARMS "# type\tpair\tbond\tangle\ttorsion\timproper\n\n");
  foreach(sort keys(%::EMCField::Equivalence)) {
    printf($::EMCField::OUT_PARMS "%s\n", $::EMCField::Equivalence{$_});
  }
  printf($::EMCField::OUT_PARMS "\nITEM\tEND\n");
}


sub print_header {
  if (defined($::EMCField::Header{@_[0]})) {
    printf($::EMCField::OUT_PARMS "$::EMCField::Header{@_[0]}\n\n");
  } else {
    printf($::EMCField::OUT_PARMS @_[1]);
  }
}


sub print_paragraph {
  my $data = shift(@_);
  my $type = shift(@_);
  my $auto = shift(@_);
  my %default = (
    nonbond	=> ["type1", "type2", "sigma", "epsilon"],
    charge	=> ["type1", "type2", "a", "d1", "d2"],
    brownian	=> ["type1", "type2", "inner", "outer"],
    lubricate	=> ["type1", "type2", "inner", "outer"],
    bond	=> ["type1", "type2", "k", "l0"],
    angle	=> ["type1", "type2", "type3", "k", "theta0"],
    torsion	=> ["type1", "type2", "type3", "type4", "k", "n", "delta","[...]"],
    improper	=> ["type1", "type2", "type3", "type4", "k", "psi0"],
    increment	=> ["type1", "type2", "d12", "d21"]
  );

  if (scalar(keys(%{$data}))) {
    my $text = ucfirst($type);
    $text .= " wildcard" if ($auto);
    printf($::EMCField::OUT_PARMS "\n# $text parameters\n\n");
    $text = uc($type);
    $text .= "_AUTO" if ($auto);
    printf($::EMCField::OUT_PARMS "ITEM\t$text\n\n");
    print_header($type, "# ".join("\t", @{$default{$type}})."\n\n");
    foreach (sort keys(%{$data})) {
      printf($::EMCField::OUT_PARMS "$_");
      foreach (split(" ", ${$data}{$_})) { 
	printf($::EMCField::OUT_PARMS "\t$::EMCField::Format", eval($_));
      }
      printf($::EMCField::OUT_PARMS "\n");
    }
    printf($::EMCField::OUT_PARMS "\nITEM\tEND\n");
  }
}


sub print_nonbonded {
  info("writing nonbonded\n");
  print_paragraph(\%::EMCField::NonbondAuto, "nonbond", 1);
  print_paragraph(\%::EMCField::Nonbond, "nonbond", 0);
  print_paragraph(\%::EMCField::ChargeAuto, "charge", 1);
  print_paragraph(\%::EMCField::Charge, "charge", 0);
  print_paragraph(\%::EMCField::BrownianAuto, "brownian", 1);
  print_paragraph(\%::EMCField::Brownian, "brownian", 0);
  print_paragraph(\%::EMCField::LubricateAuto, "lubricate", 1);
  print_paragraph(\%::EMCField::Lubricate, "lubricate", 0);
}


sub print_bonded {
  info("writing bonded\n");
  print_paragraph(\%::EMCField::BondAuto, "bond", 1);
  print_paragraph(\%::EMCField::Bond, "bond", 0);
  print_paragraph(\%::EMCField::AngleAuto, "angle", 1);
  print_paragraph(\%::EMCField::Angle, "angle", 0);
  print_paragraph(\%::EMCField::TorsionAuto, "torsion", 1);
  print_paragraph(\%::EMCField::Torsion, "torsion", 0);
  print_paragraph(\%::EMCField::ImproperAuto, "improper", 1);
  print_paragraph(\%::EMCField::Improper, "improper", 0);
}


sub print_bond_increments {
  return if (!scalar(keys(%::EMCField::Increments)));
  info("writing bond increments\n");
  print_paragraph(\%::EMCField::Increments, "increment", 0);
}


sub print_precedences {
  return if (!scalar(@::EMCField::Precedences));
  info("writing precedences\n");
  printf($::EMCField::OUT_TOPOL "\n# Precedences\n\n");
  printf($::EMCField::OUT_TOPOL "ITEM\tPRECEDENCE\n\n");
  my $current = 0;
  foreach(@::EMCField::Precedences) {
    my $last = $current;
    $current += $_ =~ tr/\(//;
    $current -= $_ =~ tr/\)//;
    my $level = $current<$last ? $current : $last;
    $level = 0 if ($level<0);
    printf($::EMCField::OUT_TOPOL "%s%s\n", ("  " x $level), $_);
  }
  printf($::EMCField::OUT_TOPOL "\nITEM\tEND\n");
}


sub print_references {
  return if (!scalar(@::EMCField::References));
  info("writing references\n");
  printf($::EMCField::OUT_PARMS "\n# Literature references\n\n");
  printf($::EMCField::OUT_PARMS "ITEM\tREFERENCES\n\n");
  printf($::EMCField::OUT_PARMS "# year\tvolume\tpage\tjournal\n\n");
  foreach(sort(@::EMCField::References)) {
    my @arg = split("\t");
    printf($::EMCField::OUT_PARMS "%s\n", join("\t", @arg[0,2,3,1]));
  }
  printf($::EMCField::OUT_PARMS "\nITEM\tEND\n");
}


sub print_rules {
  return if (!scalar(keys(%::EMCField::Rules)));

  my @rules = ();
  my $dummy = "";
  my $id = 0;

  @::EMCField::Cross = ();
  info("writing rules\n");
  foreach(sort {$a lt $b ? -1 : $a eq $b ? 0 : 1} keys(%::EMCField::Rules)) {
    my @arg = split("\t", $::EMCField::Rules{$_});
    my $type = shift(@arg);
    my $charge = shift(@arg);
    my $rule = shift(@arg);
    my $index = sprintf("%05d", 100*$_);	# needed for sort on index
    next if ($rule eq "");			# within type
    if ($type eq "?") {
      $dummy = join("\t", $type, $::EMCField::Element{$type}, $index/100, $charge, $rule);
      unshift(@::EMCField::Cross, $index);
    } else {
      $rule = join("\t", $type, $::EMCField::Element{$type}, $index, $charge, $rule);
      push(@::EMCField::Cross, $index);
      push(@rules, $rule);
    }
  }
  printf($::EMCField::OUT_TOPOL "\n# Rules\n\n");
  printf($::EMCField::OUT_TOPOL "ITEM\tRULES\n\n");
  printf($::EMCField::OUT_TOPOL "# id\ttype\telement\tindex\tcharge\trule\n\n");
  printf($::EMCField::OUT_TOPOL "%d\t%s\n", $id++, $dummy) if ($dummy ne "");
  foreach(sort(@rules)) {			# sort on type, element, index
    my @arg = split("\t", $_);
    $arg[2] = sprintf("%g", $arg[2]/100);
    printf($::EMCField::OUT_TOPOL "%d\t%s\n", $id++, join("\t", @arg));
  }
  printf($::EMCField::OUT_TOPOL "\nITEM\tEND\n");
}


sub print_comments {
  return if (!scalar(keys(%::EMCField::Index)));

  my @Comments = ();

  info("writing comments\n");
  printf($::EMCField::OUT_TOPOL "\n# Comments\n\n");
  printf($::EMCField::OUT_TOPOL "ITEM\tCOMMENTS\n\n");
  printf($::EMCField::OUT_TOPOL "# id\tindex\telement\tcomment\n\n");
  my $last = "";
  foreach(sort {$a <=> $b} keys(%::EMCField::Index)) {
    #next if ($::EMCField::Rules{$_} eq "");
    my @arg = split("\t", $::EMCField::Index{$_});
    my @word = split(" ", $arg[7]);
    my @ref = ();
    my $f = 0;
    if ($::EMCField::Literature) {
      my $flag = 0;
      foreach(@word) {
	my $l = length($_);
	$flag = 1 if (
	  (substr($_,0,1) eq "(")&&(substr($_,-1,1) eq ")")&&
	  (substr($_,-5,4) eq int(substr($_,-5,4))));
      }
      info("literature: ".join(" ", @word)."\n") if ($flag);
    }
    foreach (@word) { $f = 1 if ($_ =~ m/,/); push(@ref, $_) if ($f); }
    if (@word[-1] eq "\"") {
      @word[-1] = $last;
    } else {
      $last = join(" ", @ref);
    }
    my $comment = join(" ", @word);
    $comment =~ s/\"//g;
    my $l = length(@word[-1]);
    $Comments[$arg[0]] = join("\t", @arg[1], $comment);
  }
  my $id = 0;
  foreach (@::EMCField::Cross) {
    printf($::EMCField::OUT_TOPOL "%s\n", join("\t", $id++, $_, $Comments[$_]));
  }
  printf($::EMCField::OUT_TOPOL "\nITEM\tEND\n");
}


sub print_templates {
  return if (!scalar(keys(%::EMCField::Templates)));
  
  info("writing templates\n");
  printf($::EMCField::OUT_TOPOL "\n# ::EMCField::Templates\n\n");
  printf($::EMCField::OUT_TOPOL "ITEM\tTEMPLATES\n\n");
  foreach (sort keys(%::EMCField::Templates)) {
    printf($::EMCField::OUT_TOPOL "%s\t%s\n", $_, $::EMCField::Templates{$_});
  }
  printf($::EMCField::OUT_TOPOL "\nITEM\tEND\n");
}


sub header {
  message("Force field conversion $::EMCField::Version, $::EMCField::Date, (c) $::EMCField::Author\n\n");
}


sub help {
  $::EMCField::Message = 1;
  header();
  message("Usage:\n  $::EMCField::Script [-option[=value]] project\n");
  message("\nOptions:\n");
  message("  -define\tProvide alternate project.define name\n");
  message("  -info\t\tTurn messages and info on\n");
  message("  -literature\tShow literature references\n");
  message("  -quiet\tTurn all output off\n");
  message("  -work\tSet work directory\n");
  message("\nNotes:\n");
  message("  * Assumes existing input file: project.define\n");
  message("  * Creates output: project.prm, project.top\n");
  message("\n");
  exit;
}


sub init {
  my @names = ();
  my $i = 0;

  set_variables();
  $::EMCField::DefineName = "";
  $::EMCField::BondedName = "";
  $::EMCField::ParameterName = "";
  for ($i=0; $i<scalar(@_); ++$i) {
    if (substr(@_[$i], 0, 1) eq "-") {
      my @arg = split("=", @_[$i]);
      if (@arg[0] eq "-define") { $::EMCField::DefineName = @arg[1]; }
      elsif (@arg[0] eq "-info") { $::EMCField::Message = 1; }
      elsif (@arg[0] eq "-literature") { $::EMCField::Literature = 1; }
      elsif (@arg[0] eq "-quiet") { $::EMCField::Message = 0; }
      elsif (@arg[0] eq "-work") { $::EMCField::WorkDir = @arg[1]; }
      elsif (@arg[0] eq "-input") { $::EMCField::Topology = @_[++$i]; }
      else { help(); }
      next;
    }
    push(@names, @_[$i]);
  }
  help() if (scalar(@names)!=1);
  $::EMCField::DefineName = $names[0].".define" if ($::EMCField::DefineName eq "" && !defined($::EMCField::Topology));
  $::EMCField::CreatedParameterName = $names[0].".prm";
  $::EMCField::CreatedTopologyName = $names[0].".top";
}


# main

sub main {
  init(@_);
 
  header();
  open_input();
  get_define();

  set_equivalences();
  set_precedences();

  open_output();
  print_headers();
  print_references();
  print_masses();
  print_equivalences();
  print_bond_increments();
  print_nonbonded();
  print_bonded();

  if ($::EMCField::Flag{rules}) {
    print_precedences();
    print_rules();
    print_comments();
    print_templates();
  }

  close_all();
  message("\n");
  return scalar(keys(%::EMCField::Rules)) ? 1 : 0;
}

