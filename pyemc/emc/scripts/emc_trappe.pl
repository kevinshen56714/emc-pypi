#!/usr/bin/env perl
#
#  program:	emc_trappe.pl
#  author:	Pieter J. in 't Veld
#  date:	August 8, 2014, February 2, 2015, October 16, 2019,
#  		May 25, 2021.
#  purpose:	Interpret TraPPE force field definition file and convert it
#  		into EMC textual force field formats; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20140808	- Conception by copy from opls.pl v0.4beta
#    20150202	- Corrected sorting of rules
#    20191016	- Set NEquivalences to 7
#    20210525	- Added bond increments
#

# functions

$script = "trappe.pl";
$author = "Pieter J. in 't Veld";
$version = "v1.2";
$date = "May 25, 2021";
$EMCVersion = "9.4.4";
$TOPOL = 0;
$Type = {};
$Index = {};
$Masses = {};
$Nonbond = {};
$Bond = {};
$BondAuto = {};
$Angle = {};
$AngleAuto = {};
$Torsion = {};
$TorsionAuto = {};
$Improper = {};
$ImproperAuto = {};
$Equivalence = {};
$NEquivalences = 7;
@References = ();
@Precedences = ();
$Increment = {};
$Templates = {};
$Active = {};
$Rules = {};
$Extras = {};
$Version = "";
$Dummy = lc("DM");
$LonePair = lc("LP");
$Wildcard = "*";
$Anything = "?";
$NTorsions = 0;
$Warning = 1;
$Message = 1;
$Define = {
  ffmode => "TRAPPE", fftype => "UNITED", ffindex => "TYPES", ffdepth => 4,
  version => "Oct 2013", created => "", length => "ANGSTROM",
  energy => "KELVIN", density => "G/CC", mix => "BERTHELOT", cutoff => 14,
  nbonded => 3, pair14 => "EXCLUDE", angle => "ERROR", torsion => "ERROR"};
@OrderDefine = (
  "ffmode", "fftype", "ffdepth", "ffindex", "version", "created", "length",
  "energy", "density", "mix", "cutoff", "nbonded", "pair14", "angle",
  "torsion");

sub error {
  printf("Error: %s\n\n", join(" ", @_));
  exit(-1);
}


sub info {
  printf("Info: %s", join(" ", @_)) if ($Message);
}


sub warning {
  printf("Warning: %s", join(" ", @_)) if ($Warning);
}


sub message {
  printf("%s", join(" ", @_)) if ($Message);
}


sub ftest {
  my $name = shift(@_);
  my $result, $file;

  open($file, "<$name");
  $result = scalar($file) ? 1 : 0;
  close($file);
  return $result;
}


sub fopen {
  my $name = shift(@_);
  my $mode = shift(@_);
  my $file, $result;

  error("illegal mode") if (!($mode eq "r" || $mode eq "w"));
  info("opening \"$name\" for", ($mode eq "r" ? "read" : "writ")."ing\n");
  open($file, ($mode eq "r" ? "<" : ">").$name);
  error("cannot open file \"$name\"") if (!scalar($file));
  return $file;
}


sub fclose {
  my $file = shift(@_);

  close($file) if (scalar($file));
}


sub open_all {
  $TOPOL = fopen($DefineName, "r") if (!scalar($TOPOL));
  $OUT_PARMS = fopen($CreatedParameterName, "w") if (!scalar($OUT_PARMS));
  $OUT_TOPOL = fopen($CreatedTopologyName, "w") if (!scalar($OUT_TOPOL));
}


sub close_all {
  fclose($TOPOL);
  fclose($OUT_PARMS);
  fclose($OUT_TOPOL);
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


sub get_define {
  my $read = 0;
  my @message = ("", "defines", "masses", "precedences", "equivalences",
    "pairs", "bonds", "angles", "torsions", "impropers",
    "references", "rules", "templates");
  my @nargs = (
    1, 1, 6, 1, 3,
    4, 4, 5, 7, 6,
    4, 3, 2);
  my $index = 0;

  $Rules = {};
  $Masses = {};
  $Extras = {};
  $Active = {};
  $Element = {};
  $Nonbond = {};
  $Equivalence = {};
  $Nonbond{join("\t", $Anything, $Anything)} = join("\t", 0, 0);
  seek($TOPOL, 0, 0);
  foreach(<$TOPOL>) {
    chop();
    next if (substr($_, 0, 1) eq "#");
    my @arg = split("\t");
    if (!$read) {
      $read = 1 if (join(" ", @arg[0, 1]) eq "ITEM DEFINE");
      $read = 2 if (join(" ", @arg[0, 1]) eq "ITEM MASSES");
      $read = 3 if (join(" ", @arg[0, 1]) eq "ITEM PRECEDENCE");
      $read = 4 if (join(" ", @arg[0, 1]) eq "ITEM EQUIVALENCE");
      $read = 5 if (join(" ", @arg[0, 1]) eq "ITEM NONBOND");
      $read = 6 if (join(" ", @arg[0, 1]) eq "ITEM BOND");
      $read = 7 if (join(" ", @arg[0, 1]) eq "ITEM ANGLE");
      $read = 8 if (join(" ", @arg[0, 1]) eq "ITEM TORSION");
      $read = 9 if (join(" ", @arg[0, 1]) eq "ITEM IMPROPER");
      $read = 10 if (join(" ", @arg[0, 1]) eq "ITEM REFERENCES");
      $read = 11 if (join(" ", @arg[0, 1]) eq "ITEM RULES");
      $read = 12 if (join(" ", @arg[0, 1]) eq "ITEM TEMPLATES");
      $read = 13 if (join(" ", @arg[0, 1]) eq "ITEM INCREMENT");
      info("reading $message[$read]\n") if ($read);
      next;
    }
    $read = 0 if (join(" ", @arg[0, 1]) eq "ITEM END");
    next if (!$read);
    next if (scalar(@arg)<@nargs[$read]);
    if ($read==1) {						# define
      @arg = split(" ");
      $Define{lc($arg[0])} = $arg[1];
    } elsif ($read==2) {					# masses
      $arg[0] = type_case($arg[0]);
      $Masses{$arg[0]} = join("\t", @arg);
      $Element{$arg[0]} = @arg[2];
    } elsif ($read==3) {					# precedence
      next if ($_ eq "");
      push(@Precedences, type_case($_));
    } elsif ($read==4) {					# equivalence
      $Type{$arg[1]} = 1;
      while (scalar(@arg)<$NEquivalences) { push(@arg, @arg[-1]); }
      $Equivalence{$arg[0]} =
      $EquivalenceAuto{$arg[0]} = join("\t", @arg);
    } elsif ($read==10) {					# references
      push(@References, join("\t", @arg[0,3,1,2]));
    } elsif ($read==11) {					# rules
      $arg[0] = type_case($arg[0]);
      my $ext = 0; ++$index;
      foreach (split(" ", $arg[-1])) {
	$Rules{$index.".".$ext++} = join("\t", @arg[0,1], $_);
      }
    } elsif ($read==12) {					# templates
      $Templates{$arg[0]} = $arg[1];
    } elsif ($read==13) {					# increment
      foreach(@arg[0 .. 2]) { $_ = type_case($_); }
      my @a = splice(@arg,0,2);
      my $key = join("\t", arrange(@a));
      my $k = join("\t", $key ne join("\t", @a) ? reverse(@arg) : @arg);
      $Increment{$key} = $k if ($k ne "");
    } elsif ($read==5) {					# nonbond
      foreach(@arg[0 .. 2]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,2)));
      my $k = join("\t", @arg);
      $Nonbond{$key} = $k;
    } elsif ($read==6) {					# bond
      foreach(@arg[0 .. 2]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,2)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$BondAuto{$key} = $k;
      } else {
	$Bond{$key} = $k;
      }
    } elsif ($read==7) {					# angle
      foreach(@arg[0 .. 3]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,3)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$AngleAuto{$key} = $k;
      } else {
	$Angle{$key} = $k;
      }
    } elsif ($read==8) {					# torsion
      foreach(@arg[0 .. 4]) { $_ = type_case($_); }
      my $key = join("\t", arrange(splice(@arg,0,4)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$TorsionAuto{$key} = $k;
      } else {
	$Torsion{$key} = $k;
      }
    } elsif ($read==9) {					# improper
      foreach(@arg[0 .. 4]) { $_ = type_case($_); }
      my $key = join("\t", arrange_imp(splice(@arg,0,4)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$ImproperAuto{$key} = $k;
      } else {
	$Improper{$key} = $k;
      }
    }
  }
}


sub set_precedences {
  my @precedences;
  my $first = shift(@Precedences);
  my $last = pop(@Precedences);

  $first = "(?" if ($first eq "");
  $last = ")" if ($last eq "");
  foreach(sort(keys(%Masses))) {
    my $flag = 0, $type = $_;
    foreach (@Precedences) {
      my @arg = split(" ");
      foreach (@arg) {
	$_ =~ s/\(//g;
	$_ =~ s/\)//g;
	$flag = ($_ eq $type ? 1 : 0);
	last if ($flag); 
      }
      last if ($flag);
    }
    push(@precedences, "  ($_)") if (!$flag);
  }
  @precedences = sort({
      my $c = substr($a,0,4), $d = substr($b,0,4);
      $c lt $d ? -1 : $c gt $d ? 1 : 0 } @precedences);
  push(@Precedences, @precedences);
  unshift(@Precedences, $first);
  push(@Precedences, $last);
}


sub set_equivalences {
  my $index, $type, $typen, $element;

  foreach (keys(%Index)) {
    my @arg = split("\t", $Index{$_});
    ($index, $element, $type, $typen) = @arg[0,1,2,3];
    if (!defined($Equivalence{$typen})) {
      my @equi = ($typen);
      for (my $i=1; $i<$NEquivalences; ++$i) { push(@equi, $type); }
      $Equivalence{$typen} = $EquivalenceAuto{$typen} = join("\t", @equi);
    }
  }
}


sub put_header {
  my $file = shift(@_);
  my $text = shift(@_);
  my $definition = shift(@_);
  my $using = "$DefineName";
#  my $using = "$ParameterName, $BondedName, and $DefineName";

  printf($file "#
#  TraPPE $text using $using
#  converted by $script $version, $date by $author
#  to be used in conjuction with EMC v$EMCVersion or higher
#\n");

  return if (!$definition);
  printf($file "\n# Force field definition\n\n");
  printf($file "ITEM\tDEFINE\n\n");
  foreach (@OrderDefine) {
    printf($file "%s\t%s\n", uc($_), $Define{$_});
  }
  printf($file "\nITEM\tEND\n");
}


sub print_headers {
  info("writing headers\n");
  put_header($OUT_TOPOL, "topology", 0);
  put_header($OUT_PARMS, "interaction parameters", 1);
}


sub print_masses {
  return if (!scalar(keys(%Masses)));

  info("writing masses\n");
  printf($OUT_PARMS "\n# Masses\n\n");
  printf($OUT_PARMS "ITEM\tMASS\n\n");
  printf($OUT_PARMS "# type\tmass\telement\tncons\tcharge\tcomment\n\n");
  foreach(sort values(%Masses)) {
    my @arg = split("\t");
    my $type = shift(@arg);
    my $mass = shift(@arg);
    my $element = shift(@arg);
    next if ($Element{$type} eq "");
    printf($OUT_PARMS "%s\n", join("\t", $type, $mass, $Element{$type}, @arg));
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
}


sub print_equivalences {
  return if (!scalar(keys(%Equivalence)));

  info("writing equivalences\n");
  printf($OUT_PARMS "\n# Typing equivalences\n\n");
  printf($OUT_PARMS "ITEM\tEQUIVALENCE_AUTO\n\n");
  printf($OUT_PARMS "# type\tpair\tincr\tbond\tangle\ttorsion\timproper\n\n");
  foreach(sort keys(%EquivalenceAuto)) {
    printf($OUT_PARMS "%s\n", $EquivalenceAuto{$_});
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
  printf($OUT_PARMS "\n# Typing equivalences\n\n");
  printf($OUT_PARMS "ITEM\tEQUIVALENCE\n\n");
  printf($OUT_PARMS "# type\tpair\tincr\tbond\tangle\ttorsion\timproper\n\n");
  foreach(sort keys(%Equivalence)) {
    printf($OUT_PARMS "%s\n", $Equivalence{$_});
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
}


sub print_nonbonded {
  return if (!scalar(keys(%Nonbond)));

  info("writing nonbonded\n");
  printf($OUT_PARMS "\n# Nonbonded parameters\n\n");
  printf($OUT_PARMS "ITEM\tNONBOND\n\n");
  printf($OUT_PARMS "# type1\ttype2\tsigma\tepsilon\n\n");
  foreach (sort keys(%Nonbond)) {
    printf($OUT_PARMS "$_\t%s\n", $Nonbond{$_});
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
}


sub print_increment {
  return if (!scalar(keys(%Increment)));

  info("writing nonbonded\n");
  printf($OUT_PARMS "\n# Increment parameters\n\n");
  printf($OUT_PARMS "ITEM\tNONBOND\n\n");
  printf($OUT_PARMS "# type1\ttype2\tdelta12\tdelta21\n\n");
  foreach (sort keys(%Increment)) {
    printf($OUT_PARMS "$_\t%s\n", $Increment{$_});
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
}


sub print_bonded {
  info("writing bonded\n");
  
  if (scalar(keys(%BondAuto))) {
    printf($OUT_PARMS "\n# Bond wildcard parameters\n\n");
    printf($OUT_PARMS "ITEM\tBOND_AUTO\n\n");
    printf($OUT_PARMS "# type1\ttype2\tk\tl0\n\n");
    foreach (sort keys(%BondAuto)) {
      printf($OUT_PARMS "$_\t%s\n", $BondAuto{$_});
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%Bond))) {
    printf($OUT_PARMS "\n# Bond parameters\n\n");
    printf($OUT_PARMS "ITEM\tBOND\n\n");
    printf($OUT_PARMS "# type1\ttype2\tk\tl0\n\n");
    foreach (sort keys(%Bond)) {
      printf($OUT_PARMS "$_\t%s\n", $Bond{$_});
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%AngleAuto))) {
    printf($OUT_PARMS "\n# Angle wildcard parameters\n\n");
    printf($OUT_PARMS "ITEM\tANGLE_AUTO\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\tk\ttheta0\n\n");
    foreach (sort keys(%AngleAuto)) {
      printf($OUT_PARMS "$_\t%s\n", $AngleAuto{$_});
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%Angle))) {
    printf($OUT_PARMS "\n# Angle parameters\n\n");
    printf($OUT_PARMS "ITEM\tANGLE\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\tk\ttheta0\n\n");
    foreach (sort keys(%Angle)) {
      printf($OUT_PARMS "$_\t%s\n", $Angle{$_});
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%TorsionAuto))) {
    printf($OUT_PARMS "\n# Torsion wildcard parameters\n\n");
    printf($OUT_PARMS "ITEM\tTORSION_AUTO\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\ttype4\tk\tn\tdelta\t[...]\t[index]\n\n");
    foreach (sort keys(%TorsionAuto)) {
      printf($OUT_PARMS "$_\t%s\n", $TorsionAuto{$_});
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%Torsion))) {
    printf($OUT_PARMS "\n# Torsion parameters\n\n");
    printf($OUT_PARMS "ITEM\tTORSION\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\ttype4\tk\tn\tdelta\t[...]\t[index]\n\n");
    foreach (sort keys(%Torsion)) {
      printf($OUT_PARMS "$_\t%s\n", $Torsion{$_});
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
  
  if (scalar(keys(%ImproperAuto))) {
    printf($OUT_PARMS "\n# Improper wildcard parameters\n\n");
    printf($OUT_PARMS "ITEM\tIMPROPER_AUTO\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\ttype4\tk\tpsi0\n\n");
    foreach (sort keys(%ImproperAuto)) {
      printf($OUT_PARMS "$_\t%s\n", $ImproperAuto{$_});
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }

  if (scalar(keys(%Improper))) {
    printf($OUT_PARMS "\n# Improper parameters\n\n");
    printf($OUT_PARMS "ITEM\tIMPROPER\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\ttype4\tk\tpsi0\n\n");
    foreach (sort keys(%Improper)) {
      printf($OUT_PARMS "$_\t%s\n", $Improper{$_});
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
}


sub print_bond_increments {
  return if (!scalar(keys(%Increment)));

  info("writing bond increments\n");
  printf($OUT_PARMS "\n# Increment parameters\n\n");
  printf($OUT_PARMS "ITEM\tINCREMENT\n\n");
  printf($OUT_PARMS "# type1\ttype2\tdelta12\tdelta21\n\n");
  foreach (sort keys(%Increment)) {
    printf($OUT_PARMS "$_\t%s\n", $Increment{$_});
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
}


sub print_precedences {
  return if (!scalar(@Precedences));
  info("writing precedences\n");
  printf($OUT_TOPOL "\n# Rule precedences\n\n");
  printf($OUT_TOPOL "ITEM\tPRECEDENCE\n\n");
  foreach(@Precedences) {
    printf($OUT_TOPOL "%s\n", $_);
  }
  printf($OUT_TOPOL "\nITEM\tEND\n");
}


sub print_references {
  return if (!scalar(@References));
  info("writing references\n");
  printf($OUT_PARMS "\n# Literature references\n\n");
  printf($OUT_PARMS "ITEM\tREFERENCES\n\n");
  printf($OUT_PARMS "# year\tvolume\tpage\tjournal\n\n");
  foreach(sort(@References)) {
    my @arg = split("\t");
    printf($OUT_PARMS "%s\n", join("\t", @arg[0,2,3,1]));
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
}


sub print_rules {
  return if (!scalar(keys(%Rules)));

  my @rules = ();
  my $dummy = "";
  my $id = 0;

  @Cross = ();
  info("writing rules\n");
  foreach(sort {$a lt $b ? -1 : $a eq $b ? 0 : 1} keys(%Rules)) {
    my @arg = split("\t", $Rules{$_});
    my $type = shift(@arg);
    my $charge = shift(@arg);
    my $rule = shift(@arg);
    my $index = sprintf("%05d", 100*$_);	# needed for sort on index
    next if ($rule eq "");			# within type
    if ($type eq "?") {
      $dummy = join("\t", $type, $Element{$type}, $index/100, $charge, $rule);
      unshift(@Cross, $index);
    } else {
      $rule = join("\t", $type, $Element{$type}, $index, $charge, $rule);
      push(@Cross, $index);
      push(@rules, $rule);
    }
  }
  printf($OUT_TOPOL "\n# Rules\n\n");
  printf($OUT_TOPOL "ITEM\tRULES\n\n");
  printf($OUT_TOPOL "# id\ttype\telement\tindex\tcharge\trule\n\n");
  printf($OUT_TOPOL "%d\t%s\n", $id++, $dummy) if ($dummy ne "");
  foreach(sort(@rules)) {			# sort on type, element, index
    my @arg = split("\t", $_);
    $arg[2] = sprintf("%g", $arg[2]/100);
    printf($OUT_TOPOL "%d\t%s\n", $id++, join("\t", @arg));
  }
  printf($OUT_TOPOL "\nITEM\tEND\n");
}


sub print_comments {
  return if (!scalar(keys(%Index)));

  my @Comments = ();

  info("writing comments\n");
  printf($OUT_TOPOL "\n# Comments\n\n");
  printf($OUT_TOPOL "ITEM\tCOMMENTS\n\n");
  printf($OUT_TOPOL "# id\tindex\telement\tcomment\n\n");
  my $last = "";
  foreach(sort {$a <=> $b} keys(%Index)) {
    #next if ($Rules{$_} eq "");
    my @arg = split("\t", $Index{$_});
    my @word = split(" ", $arg[7]);
    my @ref = ();
    my $f = 0;
    if ($Literature) {
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
  foreach (@Cross) {
    printf($OUT_TOPOL "%s\n", join("\t", $id++, $_, $Comments[$_]));
  }
  printf($OUT_TOPOL "\nITEM\tEND\n");
}


sub print_templates {
  return if (!scalar(keys(%Templates)));
  
  info("writing templates\n");
  printf($OUT_TOPOL "\n# Templates\n\n");
  printf($OUT_TOPOL "ITEM\tTEMPLATES\n\n");
  foreach (sort keys(%Templates)) {
    printf($OUT_TOPOL "%s\t%s\n", $_, $Templates{$_});
  }
  printf($OUT_TOPOL "\nITEM\tEND\n");
}


sub header {
  message("TraPPE conversion $version, $date, (c) $author\n\n");
}

sub help {
  $Message = 1;
  header();
  message("Usage:\n  $script [-option[=value]] project\n");
  message("\nOptions:\n");
  message("  -info\t\tTurn messages and info on\n");
  message("  -literature\tShow literature references\n");
  message("  -define\tProvide alternate project.define name\n");
  message("  -quiet\tTurn all output off\n");
  message("\nNotes:\n");
  message("  * Assumes existing input file: project.define\n");
  message("  * Creates output: project.prm, project.top\n");
  message("\n");
  exit;
}


sub init {
  my @names = ();

  $DefineName = "";
  $BondedName = "";
  $ParameterName = "";
  foreach (@_) {
    if (substr($_, 0, 1) eq "-") {
      my @arg = split("=");
      if ($arg[0] eq "-define") { $DefineName = @arg[1]; }
      elsif ($arg[0] eq "-info") { $Message = 1; }
      elsif ($arg[0] eq "-literature") { $Literature = 1; }
      elsif ($arg[0] eq "-quiet") { $Message = 0; }
      else { help(); }
      next;
    }
    push(@names, $_);
  }
  help() if (scalar(@names)!=1);
  $DefineName = $names[0].".define" if ($DefineName eq "");
  $CreatedParameterName = $names[0].".prm";
  $CreatedTopologyName = $names[0].".top";
  $Define{created} = (split("\n", `date +"%b %Y"`))[0];
}


# main

  init(@ARGV);

  header();
  open_all();
  get_define();

  set_equivalences();
  set_precedences();

  print_headers();
  print_references();
  print_masses();
  print_equivalences();
  print_bond_increments();
  print_nonbonded();
  print_bonded();
  print_precedences();
  print_rules();
  print_comments();
  print_templates();

  close_all();
  message("\n");


