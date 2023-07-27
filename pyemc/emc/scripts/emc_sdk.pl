#!/usr/bin/env perl
#
#  program:	emc_sdk.pl
#  author:	Pieter J. in 't Veld
#  date:	December 8, 2012, February 12, August 31, 2014, October 16,
#		2019.
#  purpose:	Interpret SDK force field files and convert them into
#  		EMC textual force field formats; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20121208	- Creation date
#    20121216	- Tightened up mass selection
#    20140212	- Improved torsion assignments
#    		- Fixed equivalence table setup
#    20140831	- Added external mass input
#    20191016	- Set NEquivalences to 7
#

# settings

use File::Basename;

$script = basename($0);
$author = "Pieter J. in 't Veld";
$version = "v1.0";
$date = "August 31, 2014";
$EMCVersion = "9.3.7";

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
$Equivalences = {};
$NEquivalences = 7;
@References = ();
@Precedences = ();
$Increments = {};
$Templates = {};
$Rules = {};
$Extras = {};
$Count = {};

$Wildcard = "*";
$Anything = "?";
$Debug = 0;
$Message = 1;
$FFType = "COARSE";
$FFMode = "SDK";
$Version = "2011";

$Accuracy = 0.001;
$Energy = "KCAL/MOL";
$Density = "G/CC";
$Length = "ANGSTROM";
$Mix = "NONE";
$NBonded = 1;
$Inner = 0.9;
$Cutoff = 1.2;
$KConstraint = 20000;
@MassDefault = (-1, -1);

@SearchDirectory = ((split($script, $0))[0], "src/", "");

# functions

# initialization

sub header {
  message("SDK conversion $version, $date, (c) $author\n\n");
}

sub help {
  $Message = 1;
  header();
  message("Usage:\n  $script [-option[=value]] file[.dat] ...\n");
  message("\nOptions:\n");
  message("  -debug\tTurn debug messages on\n");
  message("  -define\tSet define name different from file\n");
  message("  -info\t\tTurn messages and info on\n");
  message("  -literature\tShow literature references\n");
  message("  -output\tSet alternate output file name\n");
  message("  -quiet\tTurn all output off\n");
  message("\nNotes:\n");
  message("  * Assumes existing input files: file.dat\n");
  message("  * Creates output: file.prm | [output.prm]\n");
  message("\n");
  exit;
}


sub init {
  my @names = ();

  $BondedName = "";
  $DefineName = "";
  $ParameterName = "";
  foreach (@_) {
    if (substr($_, 0, 1) eq "-") {
      my @arg = split("=");
      if ($arg[0] eq "-quiet") { $Message = $Debug = 0; }
      elsif ($arg[0] eq "-info") { $Message = 1; }
      elsif ($arg[0] eq "-debug") { $Debug = 1; }
      elsif ($arg[0] eq "-define") { $DefineName = $arg[1]; }
      elsif ($arg[0] eq "-output") { $CreatedParameterName = $arg[1]; }
      elsif ($arg[0] eq "-literature") { $Literature = 1; }
      else { help(); }
      next;
    }
    push(@names, $_);
  }
  help() if (scalar(@names)<1);
  foreach(@names) { $_ = sstrip($_, ".dat"); }
  header(); fspool(@names);
  $CreatedParameterName = $names[0] if ($CreatedParameterName eq "");
  $CreatedParameterName = sstrip($CreatedParameterName, ".dat");
  $CreatedParameterName = sstrip($CreatedParameterName, ".prm");
  $DefineName = sappend($CreatedParameterName, ".prm") if ($DefineName eq "");
  $CreatedParameterName = sappend($CreatedParameterName, ".prm");
}


# general

sub error {
  printf("Error: %s\n\n", join(" ", @_));
  exit(-1);
}


sub warning {
  printf("Warning: %s", join(" ", @_));
}


sub info {
  printf("Info: %s", join(" ", @_)) if ($Message);
}


sub debug {
  my $message = join(" ", @_); $message =~ s/\t/ /g;
  printf("Debug: %s", $message) if ($Debug);
}


sub message {
  printf("%s", join(" ", @_)) if ($Message);
}


sub sappend {
  my $name = shift(@_);
  my $ext = shift(@_);
  my $l = length($ext);

  return substr($name,-$l,$l) eq $ext ? $name : $name.$ext;
}


sub sstrip {
  my $name = shift(@_);
  my $ext = shift(@_);
  my $l = length($ext);

  return substr($name,-$l,$l) eq $ext ? substr($name,0,-$l) : $name;
}


sub ftest {
  my $name = shift(@_);
  return -f $name ? 1 : 0;
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
  $DEFINE = fopen($DefineName, "r") if (!scalar($PARMS));
  $IN_PARMS = fopen($ParameterName, "r") if (!scalar($PARMS));
  $OUT_PARMS = fopen($CreatedParameterName, "w") if (!scalar($OUT_PARMS));
  $OUT_TOPOL = $OUT_PARMS;
}


sub close_all {
  fclose($IN_PARMS);
  fclose($OUT_PARMS);
  unlink($ParameterName);
}


sub fspool() {
  $ParameterName = "sdk.$$.tmp";
  my $output = fopen($ParameterName, "w");
  foreach (@_) {
    my $input = fopen(sappend($_, ".dat"), "r");
    foreach (<$input>) { printf($output $_); }
    fclose($input);
  }
  fclose($ouput);
}


sub round {
  return int(@_[0]/@_[1]+0.5)*@_[1];
}


sub arrange {
  return @_ if (scalar(@_)<2);
  return @_ if (@_[0] lt @_[-1]);
  if (@_[0] eq @_[-1]) {
    return @_ if (scalar(@_)<4);
    return @_ if (@_[1] lt @_[2]);
    return @_[3,2,1,0];
  }
  return @_[1,0] if (scalar(@_) == 2);
  return @_[2,1,0] if (scalar(@_) == 3);
  return @_[3,2,1,0];
}


sub arrange_imp {
  return @_[0,2,3,1] if ((@_[2] le @_[3]) && (@_[2] lt @_[1]));
  return @_[0,3,1,2] if ((@_[3] le @_[1]) && (@_[3] lt @_[2]));
  return @_;
}


sub order {
  return @_ if (scalar(@_) < 2);
  return @_ if (@_[0] < @_[-1]);
  if (@_[0] == @_[-1]) {
    return @_ if (scalar(@_) < 4);
    return @_ if (@_[1] < @_[2]);
    return @_[3,2,1,0];
  }
  return @_[1,0] if (scalar(@_) == 2);
  return @_[2,1,0] if (scalar(@_) == 3);
  return @_[3,2,1,0];
}


sub check {
  my $types = shift(@_);
  my $line = shift(@_);
  foreach (@_) {
    error("unknown types in line $line of input\n") if ($$types[$_] eq "");
  }
}


sub scrub {
  my @a = ();
  foreach (@_) {
    return @a if (substr($_,0,1) eq ";"); 
    push(@a, $_);
  }
  return @a;
}


sub smooth {
  my @a;
  foreach (@_) {
    push(@a, sprintf("%.10g", $_));
  }
  return @a;
}


# input

# handling of define file

sub get_define {
  my $read = 0;
  my @message = ("", "defines", "masses", "precedences", "equivalences",
    "extra types", "extra bonds", "extra angles", "extra torsions",
    "extra impropers", "references", "rules", "redefinitions", "repairs",
    "rule replacements", "residue patches", "residue wildcard",
    "excluded residues", "rule deletions", "ring types");
  my @nargs = (1, 1, 5, 1, 3, 
    3, 4, 5, 7, 
    6, 4, 3, 2, 3,
    5, 1, 1,
    1, 0);

  return if (!scalar($DEFINE));
  seek($DEFINE, 0, 0);
  while (<$DEFINE>) {
    chop();
    next if (substr($_, 0, 1) eq "#");
    my @arg = split("\t");
    if (!$read) {
      $read = 1 if (join(" ", @arg[0, 1]) eq "ITEM DEFINE");
      $read = 2 if (join(" ", @arg[0, 1]) eq "ITEM MASSES");
      $read = 3 if (join(" ", @arg[0, 1]) eq "ITEM PRECEDENCE");
      $read = 4 if (join(" ", @arg[0, 1]) eq "ITEM EQUIVALENCE");
      $read = 5 if (join(" ", @arg[0, 1]) eq "ITEM EXTRA");
      $read = 6 if (join(" ", @arg[0, 1]) eq "ITEM BOND");
      $read = 7 if (join(" ", @arg[0, 1]) eq "ITEM ANGLE");
      $read = 8 if (join(" ", @arg[0, 1]) eq "ITEM TORSION");
      $read = 9 if (join(" ", @arg[0, 1]) eq "ITEM IMPROPER");
      $read = 10 if (join(" ", @arg[0, 1]) eq "ITEM REFERENCES");
      $read = 11 if (join(" ", @arg[0, 1]) eq "ITEM RULES");
      $read = 12 if (join(" ", @arg[0, 1]) eq "ITEM REDEFINE");
      $read = 13 if (join(" ", @arg[0, 1]) eq "ITEM REPAIR");
      $read = 14 if (join(" ", @arg[0, 1]) eq "ITEM REPLACE");
      $read = 15 if (join(" ", @arg[0, 1]) eq "ITEM PATCH");
      $read = 16 if (join(" ", @arg[0, 1]) eq "ITEM WILDCARD");
      $read = 17 if (join(" ", @arg[0, 1]) eq "ITEM EXCLUDE");
      $read = 18 if (join(" ", @arg[0, 1]) eq "ITEM DELETE");
      $read = 19 if (join(" ", @arg[0, 1]) eq "ITEM RING");
      info("reading $message[$read]\n") if ($read);
      next;
    }
    $read = 0 if (join(" ", @arg[0, 1]) eq "ITEM END");
    next if (!$read);
    next if (!scalar(@arg));
    next if ((@nargs[$read]>0)&&(scalar(@arg)<@nargs[$read]));
    if ($read==1) {						# define
      $FFMode = $arg[1] if ($arg[0] eq "FFMODE");
      $FFDepth = $arg[1] if ($arg[0] eq "FFDEPTH");
      $Cutoff = $arg[1] if ($arg[0] eq "CUTOFF");
      $Inner = $arg[1] if ($arg[0] eq "INNER");
      $Version = $arg[1] if ($arg[0] eq "VERSION");
    } elsif ($read==2) {					# masses
      $Masses{$arg[0]} = join("\t", @arg); my $t = $arg[0];
      my @equi = (); for (my $i=0; $i<$NEquivalences; ++$i) { push(@equi, $t); }
      $Equivalences{$t} = join("\t", @equi);
      $Element{$t} = $t;
    } elsif ($read==3) {					# precedence
      next if ($_ eq "");
      push(@Precedences, $_);
    } elsif ($read==4) {					# equivalence
      $Type{$arg[1]} = 1;
      while (scalar(@arg)<$NEquivalences) { push(@arg, @arg[-1]); }
      $Equivalence{$arg[0]} =
      $EquivalenceAuto{$arg[0]} = join("\t", @arg);
    } elsif ($read==10) {					# references
      push(@References, join("\t", @arg[0,3,1,2]));
    } elsif ($read==11) {					# rules
      #@arg[1] = sprintf("%.10g", @arg[1]);
      $arg[-1] =~ s/\^//g;
      my $index = join("\t", @arg[1,2]);
      $Rules{$index} = join("\t", @arg[0], "-", "-");
    } elsif ($read==14) {					# replace
      #@arg[3] = sprintf("%.10g", @arg[3]);
      $arg[-1] =~ s/\^//g;
      my $index = join("\t", @arg[0,1,2]);
      $Replace{$index} = join("\t", @arg[3,4]);
    } elsif ($read==12) {					# redefine
	$Redefine{$arg[0]} = $arg[1];
    } elsif ($read==13) {					# repair
	$Repair{@arg[0]} = join("\t", @arg[1,2]);
    } elsif ($read==15) {					# patch
      my $residue = shift(@arg);
      $ResidueDelete{$residue} = pop(@arg);
      $ResiduePatch{$residue} = join("\t", @arg);
    } elsif ($read==16) {					# wildcard
      $ResidueWildcard = shift(@arg);
      while (scalar(@arg)>1) {
	my @atom = splice(@arg,0,2);
	$ResidueWildcards{@atom[0]} = @atom[1];
      }
    } elsif ($read==17) {					# exclude
      $ResidueExclude{@arg[0]} = 1;
    } elsif ($read==18) {					# delete
      $RuleDelete{join("\t", @arg[0,1])} = 1;
    } elsif ($read==19) {					# ring
      foreach (@arg) { $RingType{$_} = 1; }
    } elsif ($read==5) {					# extra
      $Extras{$arg[0]} = join("\t", @arg);
    } elsif ($read==6) {					# bond
      my $key = join("\t", arrange(splice(@arg,0,2)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$BondAuto{$key} = $k;
      } else {
	$Bond{$key} = $k;
      }
    } elsif ($read==7) {					# angle
      my $key = join("\t", arrange(splice(@arg,0,3)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$AngleAuto{$key} = $k;
      } else {
	$Angle{$key} = $k;
      }
    } elsif ($read==8) {					# torsion
      my $key = join("\t", arrange(splice(@arg,0,4)));
      my $k = join("\t", @arg);
      if ($key =~ m/\*/) {
	$TorsionAuto{$key} = $k;
      } else {
	$Torsion{$key} = $k;
      }
    } elsif ($read==9) {					# improper
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


sub get_version {
}


sub get_masses {
}


sub assign_mass {
  my $type = shift(@_);
  my $mass = shift(@_);
  my $charge = shift(@_);
  my $set = shift(@_);
  my @equi = split("\t", $Equivalences{$type});
  my $flag = scalar(@equi)<1 ? 1 : 0;

  debug("equivalence [@equi]");
  $mass = @MassDefault[(substr($type,0,1) eq "S" ? 1 : 0)] if ($mass eq "");
  $charge = 0 if ($charge eq "");
  my $t = @equi[1]; $t = $type if ($t eq "");
  $Element{$type = $t.++$Count{$t}} = $t;
  @equi[0] = $type;
  my $i; for ($i=1; $i<$NEquivalences; ++$i) { 
    @equi[$i] = $i<$set ? (@equi[$i] eq "" ? $t : @equi[$i]) : $type; }
  print(" -> [@equi]\n") if ($Debug);
  $Masses{$type} = join("\t", $type, $mass, 2, $charge);
  $Equivalences{$type} = join("\t", @equi);
  info("assigning new mass $type for molecule $MoleculeName\n");
  return $type;
}


sub compare {
}


sub assign_parms {
  my $bonded = shift(@_);
  my $nconnects = shift(@_);
  my $index = shift(@_);
  my $types = shift(@_);
  my $orig = shift(@_);
  my $atoms = shift(@_);
  my $parms = shift(@_);
  my $mode = shift(@_);
  my $torsion = $mode==6;
  my $improper = $mode==7;
  my $dim = scalar(@$index);
  my @arg = @$types[@$index], @tmp = @arg;
  my $key = join("\t", $improper ? arrange_imp(@arg) : arrange(@arg));
  my $current = $$bonded{$key};
  my $type;

  if ($current ne "" && $current ne $parms) {
    debug("current = [$current], parms = [$parms]\n");
    @arg = split("\t", $key);
    my $k = "";
    my $t, $i = 0, @x, @n = @$nconnects, @idx = @$index;
    
    foreach (@idx) { @x[$i] = $i; $i++; }
    @x = sort({@n[@idx[$a]] > @n[@idx[$b]] ? -1 :
       	@n[@idx[$a]] < @n[@idx[$b]] ? 1 : @idx[$a] < @idx[$b] ? -1 : 1} @x);
    $i = 0; foreach (@x) { 
      last if (@$orig[@idx[$_]] eq @$types[@idx[$_]]); ++$i; }
    if ($i<scalar(@x)) { 
      my $id = @idx[@x[$i]];				# assign new mass
      my $mass = (split("\t", $Masses{@arg[@x[$i]]}))[1];
      my $charge = (split("\t", $Masses{@arg[@x[$i]]}))[-1];
      my @a = split("\t", @$atoms[$id]); shift(@a);
      @arg = @$types[@$index];
      $type = assign_mass(@arg[@x[$i]], $mass, $charge, $dim);
      @$atoms[$id] = join("\t", $type, @a);		# reassign atom type
      @$types[$id] = $type;
      debug("reassigning [".@arg[@x[$i]]."] -> [$type]\n");
      @arg[@x[$i]] = $type;
      $key = join("\t", $improper ? arrange_imp(@arg) : arrange(@arg));
    } 
  }
  $key = assign_equivalence($key, $mode);
  if ($torsion) {
    my @stored = torsion_array($$bonded{$key});
    my @assign = torsion_array($parms);
    my @result = ();
    my $i = 0; for (@assign) {
      @stored[$i] = $_ if ($_ ne ""); $i++;
    }
    foreach (@stored) { 
      push(@result, $_) if ($_ ne ""); 
    }
    $$bonded{$key} = join("\t", @result);
  } else {
    $$bonded{$key} = $parms;
  }
}


sub torsion_array {
  my $parms = shift(@_);
  my @arg = split("\t", $parms);
  my @result = ();

  while (scalar(@arg)>0) {
    my @set = splice(@arg, 0, 3);
    @result[@set[1]-1] = join("\t", @set) if (@set[1]>0);
  }
  return @result;
}

sub assign_equivalence {
  my @key = split("\t", shift(@_));
  my $id = (0,0,1,2,2,3,4,5)[shift(@_)];

  foreach (@key) {
    my $equi = (split("\t", $Equivalences{$_}))[$id];
    $_ = $equi if ($equi ne "");
  }
  return join("\t", @key);
}


sub assign_connect {
  my $connects = shift(@_);
  my $nconnects = shift(@_);
  my @arg = @_;
  my $current = \@$connects[@arg[0]];

  foreach (@arg) {
    ++$$nconnects[$_] if ($nconnects);
    if ($$current eq "") {				# assign first
      $$current = $_; next;
    }
    my $add = $_;
    foreach (split("\t", $$current)) {			# check existing bond
      $add = "" if ($add eq $_);
    }
    next if ($add eq "");				# skip existing
    $$current = "$$current\t$add";			# assign connection
  }
}


sub smiles_entry {					# create single entry
  my $atoms = shift(@_);
  my $entry = shift(@_);

  my @arg = split("\t", @$atoms[$entry]);
  my $charge = @arg[-1];
  my $type = @arg[0]; 
  if ($charge) {
    $charge = "+$charge" if ($charge>0);
    $entry = "[$type$charge]";
  } elsif (length($type)!=1) {
    $entry = "[$type]";
  } else {
    $entry = $type;
  }
  return $entry;
}


sub smiles_rec {					# recursive build
  my $current = shift(@_);
  my $connects = shift(@_);
  my $entry = shift(@_);
  my $link = shift(@_);
  my $visit = shift(@_);
  my @id = split("\t", @$connects[$current]);
  my $first = shift(@id);
  my $smiles = @$entry[$first];
  my $last = ""; $nlast = 0;
  my $nlink = @$link[$first];

  @$visit[$first] = 1;
  $smiles .= $nlink>9 ? "%$nlink" : $nlink if ($nlink);
  foreach (@id) {
    if (@$visit[$_]) {
      next;
    } elsif ($last eq "") {
      $last = smiles_rec($_, $connects, $entry, $link, $visit);
      $nlast = $last =~ tr/\[//;
    } else {
      my $s = smiles_rec($_, $connects, $entry, $link, $visit);
      my $n = $s =~ tr/\[//;
      if ($n>$nlast) {
	$smiles .= "(".$last.")"; $last = $s; $nlast = $n;
      } else {
	$smiles .= "(".$s.")";
      }
    }
  }
  return $smiles.$last;
}


sub set_links {
  my $first = shift(@_);
  my $connect = shift(@_);
  my $visited = shift(@_);
  my $link = shift(@_);
  my $nlink = shift(@_);
  my $level = shift(@_);
  my @connects = split("\t", @$connect[$first]); shift(@connects);

  @$link[$first] = 0;
  @$visited[$first] = $level;
  foreach (@connects) {
    if (@$visited[$_]) {
      @$link[$first] = @$link[$_] = $$nlink++;
      next;
    } else {
      set_links($_, $connect, $visited, $link, $nlink, $level+1);
    }
  }
  return;
}


sub smiles {						# create smiles
  my $first = shift(@_);
  my $connects = shift(@_);
  my $atoms = shift(@_);
  my $count = 1, $i, $k = 0, $nlink = 1;
  my $n = scalar(@$atoms);
  my @entry = (""), @visit = (0), @bonds = (), @link = (0);
  my @cross = ();

  for ($i=1; $i<$n; ++$i) {				# create entries
    push(@entry, smiles_entry($atoms, $i));
    push(@visit, 0); push(@link, 0);
  }
  foreach (@$connects) {
    next if ($_ eq "");
    $_ = "$k" if ($_ eq "");
    my @id = split("\t");
    my $i = shift(@id);
    foreach (@id) {
      assign_connect(\@cross, 0, $i, $_);
      assign_connect(\@cross, 0, $_, $i);
    }
  }
  $cross[1] = $first if (scalar(@cross)==0);
  set_links($first, \@connects, \@visit, \@link, \$nlink, 1);
  foreach (@link) { $_ = $nlink-$_ if ($_); }
  foreach (@visit) { $_ = 0; }				# reset
  return smiles_rec($first, \@cross, \@entry, \@link, \@visit);
}


sub assign_template {					# create template
  my $name = shift(@_);
  my $connects = shift(@_);
  my $atoms = shift(@_);

  assign_connect($connects, 0, 1);
  assign_connect($connects, 0, scalar(@$atoms)-1);
  if ($Templates{$name} eq "") {
    $Templates{$name} = smiles(1, $connects, $atoms);
  } else {
    warning("skipping template [$name] redefinition\n");
  }
  @$connects = ();
  return 0;
}


sub rounds {
  my $r = shift(@_);
  foreach(@_) { $_ = sprintf("%g", round($_, $r)); }
  return @_;
}


sub get_params {
  my $auto, $key;
  my $round = 1e-4;
  my %ids = (
    "mass" => 1, "pair" => 2,
    "bond" => 3, "angle" => 4, "torsion" => 5, "improper" => 6);
  my %nkeys = (
    "mass" => 1, "pair" => 2,
    "bond" => 2, "angle" => 3, "torsion" => 4, "improper" => 4);
  undef %Nonbond, %Bond, %BondAuto, %Angle, %AngleAuto, %Torsion, %TorsionAuto,
	%Improper, %ImproperAuto, %Extras, %Rules, %Equivalence, %Masses;

  seek($IN_PARMS, 0, 0);
  foreach(<$IN_PARMS>) {
    next if (substr($_, 0, 1) eq "#");
    my @arg = split(" ");
    my $id = $ids{$arg[0]};
    next if (!$id);
    $key = join("\t", arrange(@arg[1 .. $nkeys{$arg[0]}]));
    $auto = $key =~ m/\*/ ? 1 : 0;
    if ($id == 1) {
      $arg[2] = round($arg[2], $round);
      $Masses{$arg[1]} = join("\t", @arg[1,2,3,4,5,6]); my $t = $arg[1];
      my @equi = (); for (my $i=0; $i<$NEquivalences; ++$i) { push(@equi, $t); }
      $Equivalences{$t} = join("\t", @equi);
      $Element{$t} = $t;
    }
    elsif ($id == 2) {
      @arg[1,2] = arrange(@arg[1,2]); $arg[3] =~ s/lj//g;
      if ($arg[3] eq "9_6") {
	$Nonbond{$tmp = join("\t", @arg[1,2,5,4], 9, 6)} = 1;
	debug("nonbond [$arg[1] $arg[2]]\n");
      } elsif ($arg[3] eq "12_4") {
	$Nonbond{$tmp = join("\t", @arg[1,2,5,4], 12, 4)} = 1;
	debug("nonbond [$arg[1] $arg[2]]\n");
      }
    }
    elsif ($id == 3) {
      if ($auto) {
	$BondAuto{$key} = join("\t", @arg[3,4]);
      }
      else {
	$Bond{$key} = join("\t", @arg[3,4]);
      }
    }
    elsif ($id == 4) {
      if ($auto) {
	$AngleAuto{$key} = join("\t", @arg[4,5]);
      }
      else {
	$Angle{$key} = join("\t", @arg[4,5]);
      }
    }
    elsif ($id == 5) {
      if ($auto) {
	$TorsionAuto{$key} = join("\t", @arg[5,6,7]);
      }
      else {
	$Torsion{$key} = join("\t", @arg[5,6,7]);
      }
    }
    elsif ($id == 6) {
      if ($auto) {
	$ImproperAuto{$key} = join("\t", @arg[5,6]);
      }
      else {
	$Improper{$key} = join("\t", @arg[5,6]);
      }
    }
  }
}


# output

sub put_header {
  my $file = shift(@_);
  my $text = shift(@_);
  my $definition = shift(@_);

  printf($file "#
#  SDK $text using $ParameterName
#  converted by $script $version, $date by $author
#  to be used in conjuction with EMC v$EMCVersion or higher
#\n");

  return if (!$definition);
  printf($file "\n# Force field definition\n\n");
  printf($file "ITEM\tDEFINE\n\n");
  printf($file "FFMODE\t$FFMode\n");
  printf($file "FFTYPE\t$FFType\n");
  printf($file "VERSION\t$Version\n");
  printf($file "CREATED\t".`date +"%b %Y"`);
  printf($file "LENGTH\t$Length\n");
  printf($file "ENERGY\t$Energy\n");
  printf($file "DENSITY\t$Density\n");
  printf($file "MIX\t$Mix\n");
  printf($file "NBONDED\t$NBonded\n");
  printf($file "INNER\t$Inner\n");
  printf($file "CUTOFF\t$Cutoff\n");
  printf($file "PAIR14\tOFF\n");
  printf($file "ANGLE\tWARN\n");
  printf($file "TORSION\tIGNORE\n");
  printf($file "\nITEM\tEND\n");
}


sub print_headers {
  info("writing headers\n");
  #put_header($OUT_TOPOL, "topology", 0);
  put_header($OUT_PARMS, "interaction parameters", $Version ne "");
}


sub print_masses {
  return if (!scalar(keys(%Masses)));

  info("writing masses\n");
  printf($OUT_PARMS "\n# Masses\n\n");
  printf($OUT_PARMS "ITEM\tMASS\n\n");
  printf($OUT_PARMS "# type\tmass\tncons\tcharge\tcite\tcomment\n\n");
  foreach(sort values(%Masses)) {
    my @arg = split("\t");
    my $type = shift(@arg);
    my $mass = shift(@arg);
    printf($OUT_PARMS "%s\n", join("\t", $type, $mass, @arg));
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
}


sub print_equivalences {
  return if (!scalar(keys(%Equivalences)));

  info("writing equivalences\n");
  printf($OUT_PARMS "\n# Typing equivalences\n\n");
  printf($OUT_PARMS "ITEM\tEQUIVALENCE\n\n");
  printf($OUT_PARMS "# type\tpair\tincr\tbond\tangle\ttorsion\timproper\n\n");
  foreach(sort keys(%Equivalences)) {
    printf($OUT_PARMS "%s\n", $Equivalences{$_});
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
}


sub print_nonbonded {
  return if (!scalar(keys(%Nonbond)));

  info("writing nonbonded\n");
  printf($OUT_PARMS "\n# Nonbonded parameters\n\n");
  printf($OUT_PARMS "ITEM\tNONBOND\n\n");
  printf($OUT_PARMS "# type1\ttype2\tsigma\tepsilon\tm\tn\n\n");
  foreach (sort keys(%Nonbond)) {
    printf($OUT_PARMS "%s\t%s\t%g\t%g\t%g\t%g\n", split("\t"));
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
  #$BondAuto{join("\t", "*", "*")} = join("\t", 12.5, 4.7);
  #$AngleAuto{join("\t", "*", "*", "*")} = join("\t", 25, 180);
}


sub print_bonded {
  info("writing bonded\n");
  
  if (scalar(keys(%BondAuto))) {
    printf($OUT_PARMS "\n# Bond wildcard parameters\n\n");
    printf($OUT_PARMS "ITEM\tBOND_AUTO\n\n");
    printf($OUT_PARMS "# type1\ttype2\tk\tl0\n\n");
    foreach (sort keys(%BondAuto)) {
      printf($OUT_PARMS "$_\t%g\t%g\n", split("\t", $BondAuto{$_}));
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%Bond))) {
    printf($OUT_PARMS "\n# Bond parameters\n\n");
    printf($OUT_PARMS "ITEM\tBOND\n\n");
    printf($OUT_PARMS "# type1\ttype2\tk\tl0\n\n");
    foreach (sort keys(%Bond)) {
      printf($OUT_PARMS "$_\t%g\t%g\n", split("\t", $Bond{$_}));
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%AngleAuto))) {
    printf($OUT_PARMS "\n# Angle wildcard parameters\n\n");
    printf($OUT_PARMS "ITEM\tANGLE_AUTO\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\tk\ttheta0\n\n");
    foreach (sort keys(%AngleAuto)) {
      printf($OUT_PARMS "$_\t%g\t%g\n", split("\t", $AngleAuto{$_}));
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%Angle))) {
    printf($OUT_PARMS "\n# Angle parameters\n\n");
    printf($OUT_PARMS "ITEM\tANGLE\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\tk\ttheta0\n\n");
    foreach (sort keys(%Angle)) {
      printf($OUT_PARMS "$_\t%g\t%g\n", split("\t", $Angle{$_}));
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%TorsionAuto))) {
    printf($OUT_PARMS "\n# Torsion wildcard parameters\n\n");
    printf($OUT_PARMS "ITEM\tTORSION_AUTO\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\ttype4\tk\tn\tdelta\t...\n\n");
    foreach (sort keys(%TorsionAuto)) {
      printf($OUT_PARMS "$_\t%g\t%g\t%g\n", split("\t", $TorsionAuto{$_}));
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%Torsion))) {
    printf($OUT_PARMS "\n# Torsion parameters\n\n");
    printf($OUT_PARMS "ITEM\tTORSION\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\ttype4\tk\tn\tdelta\t...\n\n");
    foreach (sort keys(%Torsion)) {
      printf($OUT_PARMS "$_\t%g\t%g\t%g\n", split("\t", $Torsion{$_}));
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
  
  if (scalar(keys(%Improper))) {
    printf($OUT_PARMS "\n# Improper parameters\n\n");
    printf($OUT_PARMS "ITEM\tIMPROPER\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\ttype4\tk\tpsi0\n\n");
    foreach (sort keys(%Improper)) {
      printf($OUT_PARMS "$_\t%g\t%g\%g\n", split("\t", $Improper{$_}));
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
}


sub print_bond_increments {
  return if (!scalar(keys(%Increments)));

  info("writing bond increments\n");
  printf($OUT_PARMS "\n# Bond increments\n\n");
  printf($OUT_PARMS "ITEM\tBOND_INCREMENTS\n\n");
  printf($OUT_PARMS "# type1\ttype2\td12\td21\n\n");
  printf($OUT_PARMS "\nITEM\tEND\n\n");
}


sub print_precedences {
  return if (!scalar(@Precedences));
  info("writing precedences\n");
  printf($OUT_TOPOL "\n# Rule precedences\n\n");
  printf($OUT_TOPOL "ITEM\tPRECEDENCES\n\n");
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
  foreach(sort {lc($a) lt lc($b) ? -1 : lc($a) eq lc($b) ? ($a lt $b ? -1 : $a eq $b ? 0 : 1) : 1} values(%Rules)) {
    my @arg = split("\t", $_);
    my $type = shift(@arg);
    my $rule = shift(@arg);
    my $index = $arg[2];
    next if ($rule eq "");
    $rule = join("\t", @arg, $rule);
    if ($type eq "?") {
      $dummy = $rule;
      unshift(@Cross, $index);
    } else {
      push(@Cross, $index);
      push(@rules, $rule);
    }
  }
  printf($OUT_TOPOL "\n# Rules\n\n");
  printf($OUT_TOPOL "ITEM\tRULES\n\n");
  printf($OUT_TOPOL "# id\ttype\telement\tindex\tcharge\trule\n\n");
  printf($OUT_TOPOL "%d\t%s\n", $id++, $dummy) if ($dummy ne "");
  foreach(@rules) {
    printf($OUT_TOPOL "%d\t%s\n", $id++, $_);
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
    #printf($OUT_TOPOL "%s\n", join("\t", @arg[0, 1], $comment));
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
  printf($OUT_TOPOL "# name\tsmiles\n\n");
  foreach (sort keys(%Templates)) {
    printf($OUT_PARMS "$_\t%s\n", $Templates{$_});
  }
  printf($OUT_TOPOL "\nITEM\tEND\n");
}


# main

  init(@ARGV);

  open_all();

  get_version();
  get_masses();
  get_params();
  get_define();

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

