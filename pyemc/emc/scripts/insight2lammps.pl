#!/usr/bin/env perl
#
#  program:	insight2lammps.pl
#  author:	Pieter J. in 't Veld
#  date:	March 5, April 27, September 29, 2008, October 25, 2010,
#  		July 6, 2011, August 14, 2012, April 30, August 27, 2013, 
#  		August 19, 2014, August 15, 2018.
#  purpose:	translation of Accelrys InsightII .mdf and .arc formats
#  		to lammps input files; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20080305	Inception
#    20080427	Change in force field table cross term interpretation
#    20080506	Addition of class1 (cvff) and class2 (cff) force field types
#    20080825	Addition of basf force field (compass copy)
#    20080929	Addition of base as output target
#    20101025	Addition of force field id sort (torsion_1 proved unsorted)
#    20110706	Fixed create_forcefield_table() for $ncoeffs==3
#    20120814	Narrowed triclinic switch in read_car_header()
#    20130430	Fixed bonds between boundary-crossing atoms
#    		Calculate minimal triclinic cell
#    20130827	Fixed bounds for non-periodic boxes
#    		Added position mapping in case of periodic boxes
#		Adapted angle-angle to correct for angle order
#		Changed ordering of torsions to reflect equivalences
#    20140819	Adapted read_car_next() to include progressing molecule id
#    20180815	Added -type and updated -class to allow for explicit force
#    		field files
#    20180820	Improved triclinic recognition
#

%Selection = (
  "cvff" => "cvff", "cff" => "cff91", "cff91" => "cff91", "pcff" => "cff91", 
  "compass" => "cff91", "basf" => "cff91", "pcff_ore" => "cff91");
%Class = ("cvff" => "class1", "cff91" => "class2");
%Dir = ("x" => 0, "y" => 1, "z" => 2);

# global constants

$script = "insight2lammps";
$version = "2.12.1";
$year = "2008-2018";
$date = "August 20, 2018";
$forcefield = "compass";
$selection = $Selection{$forcefield};
$class = $Class{$selection};
$warning = 1;
$comment = 1;
$debug = 0;
$info = 1;
$base = "";
$archive = 0;
$dir_format = "%03d";
$ZERO = 1e-12;
$PI = 3.14159265358979323846264338327950288;
$dir = 0;

# commands

%Commands = (
  "help"	=> "this message",
  "debug"	=> "turn on debugging information",
  "info"	=> "turn on runtime information",
  "quiet"	=> "turn off all information",
  "comment"	=> "add type comments to data file [true]",
  "nocomment"	=> "omit type comments from data file [false]",
  "archive"	=> "force archive format as input",
  "base"	=> "change project output base [\"$base\"]",
  "format"	=> "set directory format [\"$dir_format\"]",
  "forcefield"	=> "set force field [$forcefield]",
  "selection"	=> "set force field selection [$selection]",
  "class"	=> "set force field class [$class]",
  "join"	=> "set insight file to join [\"$join\"]",
  "dir"		=> "set join direction; either x, y, or z [x]",
  "type"	=> "set force field type [$type]"
);

@Notes = (
  "* This script comes with no warrenty of any kind.  It is distributed under",
  "  the same terms as LAMMPS, which are described in the LICENSE file that is",
  "  included in the LAMMPS distribution.",
  "* Force field files are expected to be in either the working directory, or",
  "  the directory which holds this script, or ~/forcefields, or",
  "  /users/applications/forcefields",
  "* This script uses InsightII project.car and project.mdf input in",
  "  combination with a forcefield.frc force field file, both of which inputs",
  "  are generated or supplied by the standard distribution of Materials Studio",
  "  by Accelrys.",
  "* This script produces a {project|base}.data (set of) output file(s)",
);

# force field mapping

%Class1 = (
  "nonbond" => "nonbond(12-6)",
  "bond" => "morse_bond", "angle" => "quadratic_angle",
  "torsion" => "torsion_1", "oop" => "out_of_plane",
  "bond-bond" => "bond-bond", "bond-angle" => "bond-angle",
  "angle-angle-torsion" => "angle-angle-torsion_1",
#  "oop-oop" => "out_of_plane-out_of_plane",
  "angle-angle" => "angle-angle");
%Class2 = (
  "nonbond" => "nonbond(9-6)",
  "bond" => "quartic_bond", "angle" => "quartic_angle",
  "torsion" => "torsion_3", "oop" => "wilson_out_of_plane",
  "bond-bond" => "bond-bond", "bond-bond_1_3" => "bond-bond_1_3",
  "bond-angle" => "bond-angle", "angle-angle" => "angle-angle",
  "end_bond-torsion" => "end_bond-torsion_3",
  "middle_bond-torsion" => "middle_bond-torsion_3",
  "angle-torsion" => "angle-torsion_3",
  "angle-angle-torsion" => "angle-angle-torsion_1",
  "torsion-torsion" => "torsion-torsion_1");
%NCoeffs1 = (
  "nonbond" => 2, "bond" => 3, "angle" => 2, "torsion" => 3, "oop" => 3,
  "bond-bond" => 3, "bond-angle" => 4, "angle-angle-torsion" => 8,
  "oop-oop" => 1, "angle-angle" => 6);
%NCoeffs2 = (
  "nonbond" => 2, "bond" => 4, "angle" => 4, "torsion" => 6, "oop" => 2,
  "bond-bond" => 3, "bond-bond_1_3" => 3, "bond-angle" => 4, "angle-angle" => 6,
  "end_bond-torsion" => 8, "middle_bond-torsion" => 4, "angle-torsion" => 8,
  "angle-angle-torsion" => 3, "torsion-torsion" => 1);
%AutoClass1 = (
  "bond" => "morse_bond",
  "angle" => "quadratic_angle",
  "torsion" => "torsion_1",
  "oop" => "out_of_plane");
%AutoClass2 = (
  "bond" => "quadratic_bond",
  "angle" => "quadratic_angle",
  "torsion" => "torsion_1",
  "oop" => "wilson_out_of_plane");
%NAtoms = (
  "nonb" => 1, "bond" => 2, "angle" => 3, "torsion" => 4, "oop" => 4);
%Header = (
  "nonbond" => "Pair", "bond" => "Bond", "angle" => "Angle",
  "torsion" => "Dihedral", "oop" => "Improper",
  "bond-bond" => "BondBond", "bond-bond_1_3" => "BondBond13",
  "bond-angle" => "BondAngle", "angle-angle" => "AngleAngle",
  "end_bond-torsion" => "EndBondTorsion",
  "middle_bond-torsion" => "MiddleBondTorsion",
  "angle-torsion" => "AngleTorsion",
  "angle-angle-torsion" => "AngleAngleTorsion",
  "torsion-torsion" => "TorsionTorsion",
  "oop-oop" => "OutOfPlaneOutOfPlane");

# functions

# initialization

sub initialize {
  $class = "";
  $selection = "";
  @FileName = ();
  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @arg	= split("=");
      if ($Commands{substr($arg[0],1)} eq "") { help(); }
      elsif ($arg[0] eq "-help") { help(); }
      elsif ($arg[0] eq "-debug") { $debug = 1; }
      elsif ($arg[0] eq "-info") { $info = 1; }
      elsif ($arg[0] eq "-quiet") { $debug = 0; $info = 0; }
      elsif ($arg[0] eq "-comment") { $comment = 1; }
      elsif ($arg[0] eq "-nocomment") { $comment = 0; }
      elsif ($arg[0] eq "-archive") { $archive = 1; }
      elsif ($arg[0] eq "-base") { $base = $arg[1]; }
      elsif ($arg[0] eq "-format") { $format = $arg[1]; }
      elsif ($arg[0] eq "-forcefield") { $forcefield = $arg[1]; }
      elsif ($arg[0] eq "-selection") { $selection = $arg[1]; }
      elsif ($arg[0] eq "-class") { $class = $arg[1]; }
      elsif ($arg[0] eq "-join") { $Join = $arg[1]; }
      elsif ($arg[0] eq "-dir") { $dir = $Dir{$arg[1]}; }
      elsif ($arg[0] eq "-type") { $type = $arg[1]; }
    }
    else { push(@FileName, $_); }
  }
  $Project = $FileName[0];
  $Join = $FileName[1];
  help() if ($Project eq "");
  program_header() if ($info);
  if ($type ne "") {
    if (!defined($Class{$type})) {
      print("Error: '$type' is not a valid force field type\n"); exit;
    }
    $selection = $type;
    $class = $Class{$selection} if ($class eq "");
  } else {
    if ($class eq "") {
      $selection = $Selection{$forcefield} if ($selection eq "");
      if ($selection eq "") {
	print("Error: '$forcefield' is not a valid force field\n"); exit;
      }
      $class = $Class{$selection} if ($class eq "");
    } else {
      my %allowed;
      foreach (keys(%Class)) { $allowed{$Class{$_}} = $_; }
      if (!defined($allowed{$class})) {
	print("Error: '$class' is not a valid force field class\n"); exit;
      }
      $selection = $allowed{$class};
    }
  }
  if ($class eq "class1") {
    %Class = %Class1; %AutoClass = %AutoClass1; %NCoeffs = %NCoeffs1; }
  elsif ($class eq "class2") {
    %Class = %Class2; %AutoClass = %AutoClass2; %NCoeffs = %NCoeffs2; }
  else {
    print("Error: $class is not a valid force field class\n"); exit; }
  my @arg = split("/", `which $script.pl`); pop(@arg);
  @forcefield_source = (
    "", ".", $ENV{HOME}."/forcefields/$forcefield",
    $ENV{EMC_ROOT}."/field/$forcefield",
    "/users/applications/forcefields/$forcefield",
    "/gpfs/app/software/forcefields/$forcefield",
    join("/", @arg)
  );
  $base = $Project if ($base eq "");
  return if ($archive);
  my $file; open($file, "<$Project.car");
  $archive = 1 if (!scalar(stat($file)));
  close($file);
}


sub program_header {
  print("$script v$version ($date) (c) $year Pieter J. in 't Veld\n\n");
}


sub help {
  program_header();
  print("Usage:\n  $script.pl [-command[=#]] project [...]\n\n");
  print("Commands:\n");
  foreach $key (sort(keys %Commands)) {
    printf("  -%-12.12s %s\n", $key, $Commands{$key});
  }
  printf("\nNotes:\n");
  foreach (@Notes) { printf("  %s\n", $_); }
  printf("\n");
  exit(-1);
}


sub summary {
  return if (!$info);
  if ($nautos{"total"}) {
    my @autos = ();
    foreach ("bond", "angle", "torsion", "oop") {
      push(@autos, "$nautos{$_} $_".($nautos{$_}!=1 ? "s" : "")); }
    printf(
      "Info: %s automatic parameter%s: %s\n\n",
      $nautos{"total"}, $nautos{"total"}!=1 ? "s" : "", join(", ", @autos));
  }
  else {
    printf("Info: 0 automatic parameters\n\n");
  }
}


sub open_file {
  my $name = shift(@_);
  my $file;

  open($file, $name);
  if (!scalar(stat($file))) {
    printf("Error: cannot open $name\n"); exit; }
  return $file;
}


# force field interpretation

sub open_forcefield {
  print("Info: setting up force field\n") if ($info);
  foreach (@forcefield_source) {
    open($ForceField, "<".($_ eq "" ? "" : "$_/")."$forcefield.frc");
    last if (scalar(stat($ForceField)));
  }
  if (!scalar(stat($ForceField))) {
    print("Error: cannot find $forcefield force field\n"); exit; }
  $ForceFieldNonbond = "";
  $ForceFieldNonbondType = "";
  $ForceFieldNonbondMixing = "";
  %ForceFieldBondTable = ();
  %ForceFieldAngleTable = ();
  define_forcefield_selection($ForceField);
  create_forcefield_index($ForceField);
  create_forcefield_equivalence($ForceField);
  create_forcefield_auto_equivalence($ForceField);
}


sub close_forcefield {
  close($ForceField);
}


sub create_forcefield_index {
  my $file = shift(@_);

  %ForceFieldIndex = ();
  seek($file, 0, SEEK_SET);
  while (<$file>) {
    next if (substr($_,0,1) ne "#");
    my @arg = split(" ", (split("#"))[1]);
    my $select = $ForceFieldSelection{$arg[0]};
    next if ($select eq "");
    my $flag = 0;
    foreach (split(",", (split(":", $select))[-1])) {
      next if ($_ ne $arg[1]);
      $flag = 1; last;
    }
    next if (!$flag);
    my $name = $arg[0];
    my $nonbond = $name eq $Class{"nonbond"} ? 1 : 0;
    my $seek = tell($file);
    while (<$file>) {
      chop;
      my $c = substr($_,0,1);
      $seek = -1 if ($c eq "#");
      if ($nonbond) {
	my @arg = split(" ");
	$ForceFieldNonbondType = $arg[1] if ($arg[0] eq "\@type");
	$ForceFieldNonbondMixing = $arg[1] if ($arg[0] eq "\@combination");
      }
      last if (!(($c eq "")||($c eq ">")||($c eq "@")||($c eq "!")));
      $seek = tell($file);
    }
    $ForceFieldIndex{$name} = $ForceFieldIndex{$name} eq "" ?
      $seek : join(",", ($ForceFieldIndex{$name}, $seek));
  }
  return if (!$debug);
  foreach $key (sort (keys %ForceFieldIndex)) {
    print("$key @ $ForceFieldIndex{$key}\n");
  }
}


sub define_forcefield_selection {
  my $file = shift(@_);
  my $read = 0;
  my $skip;

  %ForceFieldSelection = ();
  seek($file, 0, SEEK_SET);
  while (<$file>) {
    chop;
    my @arg = split(" ");
    next if (!scalar(@arg));
    if (!$read) {
      next if ($arg[0] ne "#define");
      next if ($arg[1] ne $selection);
      $read = $skip = 1; next;
    }
    my $c = substr($_,0,1);
    next if (($c eq "")||($c eq ">")||($c eq "!")||($c eq "@"));
    last if ($c eq "#");
    $ForceFieldNonbond = $arg[2] if ($arg[2] eq $Class{"nonbond"});
    my $select = $ForceFieldSelection{$arg[2]} = 
      join(":", @arg[0,1], join(",", @arg[3 .. $#arg]));
    print("selecting $arg[2] as $select\n") if ($debug);
  }
  print("Error: force field selection not found\n\n") if (!$read);
}


%EquivalenceIndex = (
  "nonb" => 0, "bond" => 1, "angle" => 2, "torsion" => 3, "oop" => 4);

sub create_forcefield_equivalence {
  my $file = shift(@_);

  return if ($ForceFieldIndex{"equivalence"} eq "");
  %ForceFieldEquivalence = ("x" => "x,x,x,x,x");
  seek($file, $ForceFieldIndex{"equivalence"}, SEEK_SET);
  while (<$file>) {
    chop;
    my $c = substr($_,0,1);
    last if ($c eq "#");
    next if (($c eq "")||($c eq "!"));
    my @arg = split(" ");
    $ForceFieldEquivalence{$arg[2]} = join(",", @arg[3 .. $#arg]);
  }
}


sub get_equivalence {
  return (split(",", $ForceFieldEquivalence{@_[1]}))[$EquivalenceIndex{@_[0]}];
}


%AutoEquivalenceIndex = (
  "nonb" => 0,
  "bond_inct" => 1, "bond" => 2,
  "angle_end" => 3, "angle_apex" => 4,
  "torsion_end" => 5, "torsion_center" => 6,
  "oop_end" => 7, "oop_center" => 8
);

sub create_forcefield_auto_equivalence {
  my $file = shift(@_);

  %ForceFieldAutoEquivalence = ("x" => "x,x,x,x,x,x,x,x,x");
  return if ($ForceFieldIndex{"auto_equivalence"} eq "");
  seek($file, $ForceFieldIndex{"auto_equivalence"}, SEEK_SET);
  while (<$file>) {
    chop;
    my $c = substr($_,0,1);
    last if ($c eq "#");
    next if (($c eq "")||($c eq "!"));
    my @arg = split(" ");
    $ForceFieldAutoEquivalence{$arg[2]} = join(",", @arg[3 .. $#arg]);
  }
}


sub create_forcefield_table {
  my $ncoeffs = shift(@_);
  my $name = shift(@_);
  my $auto = shift(@_);
  my $oop = shift(@_);
  my $file = $ForceField;
  my %table = ("set" => 1);

  return if ($name eq "");
  seek($file, (split(",", $ForceFieldIndex{$name}))[$auto ? -1 : 0], SEEK_SET);
  print("force field table for $name:\n") if ($debug);
  while (<$file>) {
    chop;
    my $c = substr($_,0,1);
    last if ($c eq "#");
    next if (($c eq "")||($c eq "!")||($c eq ">")||($c eq "@"));
    my @arg = split(" ");
    next if (!scalar(@arg));
    foreach (@arg) { $_ = "*" if (substr($_,0,1) eq "*"); }
    if ($ncoeffs<4) {
      if ($arg[2] gt $arg[$ncoeffs+1]) { 
	my $tmp = $arg[2]; $arg[2] = $arg[$ncoeffs+1]; $arg[$ncoeffs+1] = $tmp;
      }
    } elsif ($oop) {
      my @tmp = @arg[2,4,5]; sort(@tmp); @arg[2,4,5] = @tmp;
    } elsif (($arg[3] gt $arg[4])||($arg[3] eq $arg[4] && $arg[2] gt $arg[5])) {
      @arg[2,3,4,5] = reverse(@arg[2,3,4,5]);
      @arg[6 .. $#arg] = @arg[9,10,11,6,7,8] if ($name eq "angle-torsion_3");
      @arg[6 .. $#arg] = @arg[9,10,11,6,7,8] if ($name eq "end_bond-torsion_3");
    }
    my $id = join(",", @arg[2 .. $ncoeffs+1]);
    next if ($table{$id} ne "");
    if ($name eq "nonbond(12-6)") {
      my $a = $arg[-1];
      my $b = $arg[-2];
      $arg[-2] = $a>0 ? ($b/$a)**(1/6) : 1;
      $arg[-1] = 0.25*$a*$a/$b;
    }
    my $coeff = join(",", @arg[$ncoeffs+2 .. $#arg]);
    printf("  coeff($id) = %s\n", $coeff) if ($debug);
    $table{$id} = $coeff;
  }
  return %table;
}


sub find_forcefield_coeffs {
  my @wild = (0, -1, -2);
  my $table = shift(@_);
  my @id = @_;
  my $type = join(",", @id);
  my @coeff = split(",", $table->{$type});
  
  return @coeff if (scalar(@coeff));
  foreach (@wild) {
    $id[$_] = "*" if (scalar(@id)>=-$_);
    my $card = join(",", @id);
    return @coeff if (scalar(@coeff = split(",", $table->{$card})));
  }
  return ();
}


# structure interpretation

sub read_structure {
  my $i;

  @NJoins = ();
  for ($i=0; $i<scalar(@FileName); ++$i) {
    read_mdf($FileName[$i]);
    push(@NJoins, $NAtoms);
  }
  $NJoin = @NJoins[0];
  create_connectivity();
  create_types();
}


sub read_mdf {
  my $name = shift(@_);
  my $file = open_file("<".$name.".mdf");

  @AtomType = ("") if (!scalar(@AtomType));
  @AtomConnect = ("") if (!scalar(@AtomConnect));
  while (!eof($file)) {
    my $seek = tell($file);
    read_mdf_molecule($file);
    seek($file, $seek, SEEK_SET);
    read_mdf_connectivity($file);
  }
  $NAtoms = scalar(@AtomType)-1;
  close($file);
}


sub read_mdf_molecule {
  my $file = shift(@_);
  my $n = scalar(@AtomType);
  my $read = 0;
  my $skip = 0;
  my $molid;
  my $groupid;
  my @tmp;

  @AtomID = ("");
  while (<$file>) {
    if (!$read) {
      next if (substr($_,0,9) ne "\@molecule");
      $molid = (split(" "))[1];
      $read = $skip = 1; next;
    }
    if ($skip) { --$skip; next; }
    my @arg = split(" ");
    last if (!scalar(@arg));
    $groupid = (split(":", $arg[0]))[0];
    $AtomHash{"$molid:$arg[0]"} = $n++;
    $TypeAtom{$arg[2]} = $arg[1];
    push(@AtomID, "$molid:$arg[0]");
    push(@AtomType, $arg[2]);
  }
  ++$NMolecules if ($molid ne "");
}


sub read_mdf_connectivity {
  my $file = shift(@_);
  my $read = 0;
  my $skip = 0;
  my $molid;
  my $groupid;
  my @connect;

  #@AtomCharge = ();
  while (<$file>) {
    chop;
    if (!$read) {
      next if (substr($_,0,9) ne "\@molecule");
      $molid = (split(" "))[1];
      $read = $skip = 1; next;
    }
    if ($skip) { --$skip; next; }
    my @arg = split(" ");
    last if (!scalar(@arg));
    push(@AtomCharge, $arg[6]);
    $groupid = (split(":", $arg[0]))[0];
    @connect = ();
    foreach (@arg[12 .. $#arg]) {
      my @arg = split(":");
      my $atom = (split("/", @arg[-1]))[0];
      my $group = scalar(@arg)>1 ? $arg[-2] : $groupid;
      my $mol = scalar(@arg)>2 ? $arg[-3] : $molid;
      $atom = (split("\%", $atom))[0];
      push(@connect, $AtomHash{"$mol:$group:$atom"});
    }
    push(@AtomConnect, join(",", @connect));
  }
}


# structure derivatives

# create connectivity lists

sub create_connectivity {
  my $key;

  print("Info: creating connectivity\n") if ($info);
  @BondList = ();
  @AngleList = ();
  @DihedralList = ();
  @ImproperList = ();
  for (my $i=1; $i<=$NAtoms; ++$i) { create_bond($i); }
  $NBonds = scalar(@BondList);
  $NAngles = scalar(@AngleList);
  $NDihedrals = scalar(@DihedralList);
  $NImpropers = scalar(@ImproperList);
}


sub create_bond {
  my @i = @_;
  my @connect = split(",", $AtomConnect[@i[-1]]);

  create_improper(@i);
  foreach (@connect) {
    create_angle(@i, $_);
    next if ($_ <= @i[0]);
    push(@BondList, join(",", (@i, $_)));
  }
}


sub create_angle {
  my @i = @_;
  my @connect = split(",", $AtomConnect[@i[-1]]);

  foreach (@connect) {
    create_dihedral(@i, $_) if ($_ != $i[0]);
    next if ($_ <= $i[0]);
    push(@AngleList, join(",", (@i, $_)));
  }
}


sub create_dihedral {
  my @i = @_;
  my @connect = split(",", $AtomConnect[@i[-1]]);

  foreach (@connect) {
    next if ($_ <= $i[0]);
    next if ($_ == $i[1]);
    push(@DihedralList, join(",", (@i, $_)));
  }
}


sub create_improper {
  my @id = (@_[-1], split(",", $AtomConnect[@_[-1]]));
  my $n = scalar(@id);

  return if ($n<4);
  for (my $i=1; $i<$n-2; ++$i) {
    for (my $j=$i+1; $j<$n-1; ++$j) {
      for (my $k=$j+1; $k<$n; ++$k) {
	push(@ImproperList, join(",", @id[$i,0,$j,$k], $n>4 ? 0 : 1));
      }
    }
  }
}


# create type lists

sub create_types {
  printf("Info: creating types\n") if ($info);
  create_types_pair();
  create_types_bond();
  create_types_angle();
  create_types_dihedral();
  create_types_improper();
}


sub create_types_pair {
  my @type = ();
  my $n = 0;
  my $key;

  foreach $key (sort(keys %TypeAtom)) {
    $TypeAtomHash{$TypeAtomID[++$n] = $key} = $n;
    printf(
      "$key\[$TypeAtomHash{$key}\] = $TypeAtom{$key}\n") if ($debug);
  }
  $NAtomTypes = scalar(keys %TypeAtom);
  foreach (@AtomType) { $_ = $TypeAtomHash{$_}; }
}


sub create_types_bond {
  my @id = ();
  my $n = 0;
  my $key;

  @BondType = ();
  foreach (@BondList) {
    @id = ();
    foreach (split(",")) { push(@id, $TypeAtomID[$AtomType[$_]]); }
    $key = ($id[1] lt $id[0]) ? "$id[1],$id[0]" : "$id[0],$id[1]";
    push(@BondType, $key);
    $TypeBond{$key} = "1";
  }
  foreach $key (sort(keys %TypeBond)) {
    $TypeBondHash{$TypeBondID[++$n] = $key} = $n; }
  $NBondTypes = scalar(keys %TypeBond);
  foreach (@BondType) { $_ = $TypeBondHash{$_}; };
}


sub create_types_angle {
  my $n = 0;
  my $key;

  @AngleType = ();
  foreach (@AngleList) {
    my @id = (), @ed = ();
    my @new = split(",");				# create key
    foreach (@new) { 
      push(@id, $TypeAtomID[$AtomType[$_]]);
      push(@ed, get_equivalence("torsion", $id[-1]));
    }
    if ($ed[2] lt $ed[0]) {
      @id = reverse(@id); @new = reverse(@new); }
    $_ = join(",", @new);				# store new index
    $key = join(",", @id);
    push(@AngleType, $key);
    $TypeAngle{$key} = "1";
  }
  foreach $key (sort(keys %TypeAngle)) {
    $TypeAngleHash{$TypeAngleID[++$n] = $key} = $n; }
  $NAngleTypes = scalar(keys %TypeAngle);
  foreach (@AngleType) { $_ = $TypeAngleHash{$_}; };
}


sub create_types_dihedral {
  my $n = 0;
  my $key;

  @DihedralType = ();
  foreach (@DihedralList) {				# use dihedral list
    my @id = (), @ed = ();
    my @new = split(",");				# create key
    foreach (@new) { 
      push(@id, $TypeAtomID[$AtomType[$_]]);
      push(@ed, get_equivalence("torsion", $id[-1]));
    }
    if (($ed[1] gt $ed[2])||(($ed[1] eq $ed[2])&&($ed[0] gt $ed[3]))) {
      @id = reverse(@id); @new = reverse(@new); }
    $_ = join(",", @new);				# store new index
    $key = join(",", @id);
    push(@DihedralType, $key);
    $TypeDihedral{$key} = "1";
  }
  foreach $key (sort(keys %TypeDihedral)) {		# populate types
    $TypeDihedralHash{$TypeDihedralID[++$n] = $key} = $n; }
  $NDihedralTypes = scalar(keys %TypeDihedral);
  foreach (@DihedralType) { $_ = $TypeDihedralHash{$_}; };
}


sub create_types_improper {
  my $n = 0;
  my $key;

  @ImproperType = ();
  foreach (@ImproperList) {				# use improper list
    my @arg = split(",");
    my @id = ($TypeAtomID[$AtomType[@arg[1]]]);
    my %hash = ();
    foreach (@arg[0,2,3]) { 
      my $i = $TypeAtomID[$AtomType[$_]];
      $hash{$i} = ($hash{$i} eq "") ? $_ : "$hash{$i},$_";
      push(@id, $i); }
    @id = (@id[0], sort(@id[1,2,3]));
    @id = @id[1,0,2,3];
    my @new = (@arg[1]);				# order index in same
    foreach (@id[0,2,3]) {				# order as id
      my @arg = split(",", $hash{$_});
      push(@new, shift(@arg));
      $hash{$_} = join(",", @arg);
    }
    $_ = join(",", @new[1,0,2,3]);			# store new index
    $key = join(",", @id);
    push(@ImproperType, $key);
    $TypeImproper{$key} = $arg[-1] ? "1" : "";
  }
  foreach $key (sort(keys %TypeImproper)) {		# populate types
    $TypeImproperHash{$TypeImproperID[++$n] = $key} = $n; }
  $NImproperTypes = scalar(keys %TypeImproper);
  foreach (@ImproperType) { $_ = $TypeImproperHash{$_}; };
}


# coordinate interpretation

sub v_max { return (
    @_[0]>@_[3]?@_[0]:@_[3], @_[1]>@_[4]?@_[1]:@_[4], @_[2]>@_[5]?@_[2]:@_[5]);}
sub v_add { return (
    @_[0]+@_[3], @_[1]+@_[4], @_[2]+@_[5]); }
sub v_subtr { return (
    @_[0]-@_[3], @_[1]-@_[4], @_[2]-@_[5]); }
sub v_map { return (
    @_[0]-floor(@_[0]), @_[1]-floor(@_[1]), @_[2]-floor(@_[2])); }
sub v_zero { return (
    zero(@_[0]), zero(@_[1]), zero(@_[2])); }
sub vs_add { return (
    @_[0]+@_[3], @_[1]+@_[3], @_[2]+@_[3]); }
sub vs_mult { return (
    @_[0]*@_[3], @_[1]*@_[3], @_[2]*@_[3]); }
sub m_inverse { return (
    1/@_[0], 1/@_[1], 1/@_[2], -@_[3]/@_[1]/@_[2],
    (@_[5]*@_[3]-@_[1]*@_[4])/@_[0]/@_[1]/@_[2], -@_[5]/@_[0]/@_[1]); }
sub mv_dot { return (
    @_[6]*@_[0]+@_[7]*@_[5]+@_[8]*@_[4], @_[7]*@_[1]+@_[8]*@_[3], @_[8]*@_[2]);}
sub v_print {
  printf("%s{%s}\n", @_[0], join(",", @_[1 .. scalar(@_)-1])); }
sub zero {
  return abs(@_[0])<$ZERO ? 0 : @_[0];
}
sub floor {
  return int(@_[0])+(int(@_[0])>@_[0] ? -1 : 0);
}
sub round {
  return @_[0]<0 ? int(@_[0]-0.5) : int(@_[0]+0.5);
}
sub v_pbc {
  return $PBCFlag ? 
    v_add(mv_dot(@H, 
	v_map(mv_dot(@HInv, v_subtr(@_[0,1,2], @Offset))))) : @_[0,1,2];
}


sub read_car_header {
  my $file = shift(@_);
  my $seek = tell($file);
  my %flag =
    ("Materials" => 1, "Configurations" => 1,
      "PBC=OFF" => 1, "PBC=ON" => 1, "PBC" => 1);
  my $small = 5e-9;

  seek($file, $seek, SEEK_SET);
  while (<$file>) {
    chop;
    my @arg = split(" ");
    next if ($arg[0] eq "end");
    last if (!($flag{$arg[0]}||(substr($_,0,1) eq "!")));
    $seek = tell($file);
    if ($arg[0] eq "PBC=OFF") { $PBCFlag = 0; @PBC = (0, 0, 0, 90, 90, 90) if (!$PBC[0]); }
    if ($arg[0] eq "PBC") { $PBCFlag = 1; @PBC = @arg[1 .. 7]; }
    if ($arg[0] eq "Configurations") {
      $NConfigurations = $arg[2]; $ConfigurationID = $arg[-1]; }
  }
  if ($PBC[0]>0) {
    my @c = (cos($PBC[3]*$PI/180), cos($PBC[4]*$PI/180), cos($PBC[5]*$PI/180));
    my $k = 1-$c[2]*$c[2];
    my @l = @PBC[0,1,2];
    my @h = (
      $l[0],
      $l[1]*sqrt($k),
      $l[2]*sqrt(($k-$c[0]*$c[0]-$c[1]*$c[1]+2*$c[0]*$c[1]*$c[2])/$k),
      $l[2]*($c[0]-$c[1]*$c[2])/sqrt($k),
      $l[2]*$c[1],
      $l[1]*$c[2]);
    my @d = (
      round(@h[3]/@h[1]), 0, round(@h[5]/@h[0]));
    @h[5] -= @h[0]*@d[2];
    @h[4] -= @h[5]*@d[0];
    @h[3] -= @h[1]*@d[0];
    @h[4] -= @h[0]*round(@h[4]/@h[0]);
    @Box = (
      vs_mult(@h[0,1,2], 0.0), v_zero(vs_mult(@h[0,1,2], 1.0)),
      v_zero(@h[5,4,3]));
    $Triclinic =
      (abs($h[3])>=$ZERO)||(abs($h[4])>=$ZERO)||(abs($h[5])>=$ZERO) ? 1 : 0;
  }
  else {
    my @min = (0,0,0);
    my @max = (0,0,0);
    my $first = 1;
    seek($file, $seek, SEEK_SET);
    while (!eof($file)) {
      my @arg = read_car_next($file);
      last if (!scalar(@arg));
      if ($first) {
	@min = @max = @arg[1,2,3];
	$first = 0; next;
      }
      @min[0] = @arg[1] if (@min[0]>@arg[1]);
      @min[1] = @arg[2] if (@min[1]>@arg[2]);
      @min[2] = @arg[3] if (@min[2]>@arg[3]);
      @max[0] = @arg[1] if (@max[0]<@arg[1]);
      @max[1] = @arg[2] if (@max[1]<@arg[2]);
      @max[2] = @arg[3] if (@max[2]<@arg[3]);
    }
    @Box[0 .. 6] = (vs_add(@min, -$small), vs_add(@max, $small));
    seek($file, $seek, SEEK_SET) if (!$first);
  }
  @H = (v_subtr(@Box[3,4,5], @Offset = @Box[0,1,2]), @Box[8,7,6]);
  @HInv = m_inverse(@H);
  seek($file, $seek, SEEK_SET) if (!eof($file));
}


sub read_car_next {
  my $file = shift(@_);
  my $last = shift(@_);
  my $line;

  while (<$file>) {
    chop;
    if (substr($_,0,3) eq "end") { $last = 0; next; }
    return split(" ", $_), $last; 
  }
}


# write lammps data file

sub write_lammps_header {
  my $file = shift(@_);

  printf($LAMMPS "Created by $script v$version on %s\n", `date`);
  printf($LAMMPS "%12d  atoms\n", $NAtoms);
  printf($LAMMPS "%12d  bonds\n", $NBonds) if ($NBonds);
  printf($LAMMPS "%12d  angles\n", $NAngles) if ($NAngles);
  printf($LAMMPS "%12d  dihedrals\n", $NDihedrals) if ($NDihedrals);
  printf($LAMMPS "%12d  impropers\n", $NImpropers) if ($NImpropers);
  printf($LAMMPS "\n");
  printf($LAMMPS "%12d  atom types\n", $NAtomTypes);
  printf($LAMMPS "%12d  bond types\n", $NBondTypes) if ($NBondTypes);
  printf($LAMMPS "%12d  angle types\n", $NAngleTypes) if ($NAngleTypes);
  printf($LAMMPS "%12d  dihedral types\n", $NDihedralTypes) if ($NDihedralTypes);
  printf($LAMMPS "%12d  improper types\n", $NImproperTypes) if ($NImproperTypes);
  printf($LAMMPS "\n");

  # note: use pbcbox.tcl for VMD to calculate xy xz and yz when needed

  printf($LAMMPS "%12.8g %12.8g xlo xhi\n", $Box[0], $Box[3]);
  printf($LAMMPS "%12.8g %12.8g ylo yhi\n", $Box[1], $Box[4]);
  printf($LAMMPS "%12.8g %12.8g zlo zhi\n", $Box[2], $Box[5]);
  printf($LAMMPS "%12.8g %12.8g %12.8g xy xz yz \n", @Box[6,7,8])
    if ($Triclinic);
  printf($LAMMPS "\n");
}


sub write_lammps_masses {
  my $file = $ForceField;
  my %table = ();

  seek($file, $ForceFieldIndex{"atom_types"}, SEEK_SET);
  while (<$file>) {
    chop;
    my $c = substr($_,0,1);
    last if ($c eq "#");
    next if (($c eq "")||($c eq "!")||($c eq ">"));
    my @arg = split(" ");
    next if (!scalar(@arg));
    print("mass($arg[2]) = $arg[3]\n") if ($debug);
    $table{$arg[2]} = $arg[3];
  }
  printf($LAMMPS "Masses\n\n");
  foreach $key (@TypeAtomID) {
    next if ($key eq "");
    printf($LAMMPS "%8d %10.7g%s\n",
      $TypeAtomHash{$key},
      $table{$key}, $comment ? "  # $key" : "");
  }
  printf($LAMMPS "\n");
}


# nonbonded coefficients

sub write_lammps_coeff_pair {
  return if (!$NAtomTypes);
  %Type = %TypeAtom;
  write_lammps_coeff_select("nonbond", "nonb", "%-4.4s", @TypeAtomID);
}


# bond coefficients

sub write_lammps_coeff_bond {
  return if (!$NBondTypes);
  %Type = %TypeBond;
  write_lammps_coeff_select("bond", "bond", "%-9.9s", @TypeBondID);
}


# angle coefficients

sub write_lammps_coeff_angle {
  my $local_warning = $warning;
  return if (!$NAngleTypes);
  %Type = %TypeAngle;
  write_lammps_coeff_select("angle", "angle", "%-13.13s", @TypeAngleID);
  $warning = 0;
  write_lammps_coeff_select("bond-bond", "angle", "%-13.13s", @TypeAngleID);
  write_lammps_coeff_select("bond-angle", "angle", "%-13.13s", @TypeAngleID);
  $warning = $local_warning;	
}


# torsion coefficients

sub write_lammps_coeff_dihedral {
  my $local_warning = $warning;
  return if (!$NDihedralTypes);
  %Type = %TypeDihedral;
  write_lammps_coeff_select("torsion", "torsion", "%-17.17s", @TypeDihedralID);
  $warning = 0;
  write_lammps_coeff_select(
    "middle_bond-torsion", "torsion", "%-17.17s", @TypeDihedralID);
  write_lammps_coeff_select(
    "end_bond-torsion", "torsion", "%-17.17s", @TypeDihedralID);
  write_lammps_coeff_select(
    "angle-torsion", "torsion", "%-17.17s", @TypeDihedralID);
  write_lammps_coeff_select(
    "angle-angle-torsion", "torsion", "%-17.17s", @TypeDihedralID);
  write_lammps_coeff_select(
    "bond-bond_1_3", "torsion", "%-17.17s", @TypeDihedralID);
  $warning = $local_warning;	
}


# improper coefficients

sub write_lammps_coeff_improper {
  my $local_warning = $warning;
  return if (!$NImproperTypes);
  %Type = %TypeImproper;
  write_lammps_coeff_select("oop", "oop", "%-17.17s", @TypeImproperID);
  $warning = 0;
  write_lammps_coeff_select("angle-angle", "oop", "%-17.17s", @TypeImproperID);
  write_lammps_coeff_select("oop-oop", "oop", "%-17.17s", @TypeImproperID);
  $warning = $local_warning;	
}


# general write

# primary terms: a warning is generated upon absence
# secondary terms: missing terms are set to 0 in accordance to a private
# 	conversation with H. Sun

%AutoNames = (
  "nonb" => "nonb", "bond" => "bond,bond", "angle" => "angle_end,angle_apex",
  "torsion" => "torsion_end,torsion_center", "oop" => "oop_end,oop_center");

sub equivalence {
  my @arg = split(",", shift(@_));
  my $name = shift(@_);
  my $adapt = $name ne "oop";
  my $index = $EquivalenceIndex{$name};
  my @k = ();

  foreach (@arg) {
    push(@k, (split(",", $ForceFieldEquivalence{$_}))[$index]); }
  @k = reverse(@k) if ($adapt&&($k[-1] lt $k[0]));
  @k = reverse(@k) if ($adapt&&(scalar(@arg)>3)&&($k[-2] lt $k[1]));
  return @k;
}


sub auto_equivalence {
  my @arg = split(",", shift(@_));
  my $name = shift(@_);
  my $adapt = $name ne "oop";
  my @k = split(",", $AutoNames{$name});
  foreach (@k) { $_ = $AutoEquivalenceIndex{$_}; };
  my @index = (
    $name eq "nonb" ? @k[0] : $name eq "bond" ? @k[0,0] :
    $name eq "angle" ? @k[0,1,0] : $name eq "torsion" ? @k[0,1,1,0] :
    $name eq "oop" ? @k[0,1,0,0] : @k[0]);
  
  @k = ();
  for (my $i=0; $i<scalar(@arg); ++$i) {
    push(@k, (split(",", $ForceFieldAutoEquivalence{@arg[$i]}))[$index[$i]]); }
  @k = reverse(@k) if ($adapt&&($k[-1] lt $k[0]));
  @k = reverse(@k) if ($adapt&&(scalar(@arg)>3)&&($k[-2] lt $k[1]));
  return @k;
}


%ForceFieldCompletion = (
  "bond-bond" => "0,1::1", "bond-angle" => "0,1::2", "angle-angle" => ":0,1:1",
  "middle_bond-torsion_3" => "1::3", "end_bond-torsion_3" => "0,2::6",
  "angle-angle-torsion_1" => ":0,1:1", "angle-torsion_3" => ":0,1:6",
  "bond-bond_1_3" => "0,2::1", "angle-angle" => ":0,3:1" 
);

sub complete_forcefield_coeffs {
  my $name = shift(@_);
  my @k = split(",", shift(@_));
  my @coeff = @_;

  my @n = split(":", $ForceFieldCompletion{$name});
  return @coeff if (!scalar(@n));
  my $ncoeffs = pop(@n);
  @coeff = (@coeff, @coeff) if (2*scalar(@coeff)==$ncoeffs);
  while (scalar(@coeff)<$ncoeffs) { push(@coeff, 0); }
  if ($name eq "angle-angle") {
    foreach ("2,1,0,3", "0,1,3,2") {
      my @i = split(",");
      my @coeffs = find_forcefield_coeffs(\%ForceFieldTable, 
	  equivalence(join(",", @k[@i[0],@i[1],@i[2],@i[3]]), "oop"));
      push(@coeff, scalar(@coeffs) ? @coeffs : 0);
    }
    while (scalar(@coeff)<3) { push(@coeff, 0); }
    foreach ("0,1,2", "0,1,3", "2,1,3") {
      my @i = split(",");
      my @c = find_forcefield_coeffs(\%ForceFieldAngleTable,
	equivalence(
	  join(",", @k[@i[0],@i[1],@i[2]]), "angle"));
      @c = find_forcefield_coeffs(\%ForceFieldAutoAngleTable,
	auto_equivalence(
	  join(",", @k[@i[0],@i[1],@i[2]]), "angle")) if (!scalar(@c));
      push(@coeff, @c[0]);
    }
  }
  elsif (@n[0] ne "") {
    foreach (split(",", @n[0])) {
      my @c = find_forcefield_coeffs(\%ForceFieldBondTable,
	equivalence(join(",", @k[$_, $_+1]), "bond"));
      @c = find_forcefield_coeffs(\%ForceFieldAutoBondTable,
	auto_equivalence(join(",", @k[$_, $_+1]), "bond")) if (!scalar(@c));
      push(@coeff, @c[0]);
    }
  }
  elsif (@n[1] ne "") {
    foreach (split(",", @n[1])) {
      my @c = find_forcefield_coeffs(\%ForceFieldAngleTable,
	equivalence(join(",", @k[$_..$_+2]), "angle"));
      @c = find_forcefield_coeffs(\%ForceFieldAutoAngleTable,
	auto_equivalence(join(",", @k[$_..$_+2]), "angle")) if (!scalar(@c));
      push(@coeff, @c[0]);
    }
  }
  return @coeff;
}


sub write_lammps_coeff_select {
  my $id = shift(@_);
  my $name = $Class{$id};
  my $name_auto = $AutoClass{$id};
  my $eqv = shift(@_);
  my $format = shift(@_);
  my $natoms = $NAtoms{$eqv};
  my $oop = $eqv eq "oop" ? 1 : 0;
  my @k = ();
  my $i = 1;

  return if ($name eq "");
  %ForceFieldTable = create_forcefield_table($natoms, $name, 0, $oop);
  %ForceFieldAutoTable = create_forcefield_table($natoms, $name_auto, 1, $oop);
  printf($LAMMPS "%s Coeffs\n\n", $Header{$id});
  shift(@_); 						# first one is empty
  foreach (@_) {
    my $type = join(",", @k = equivalence($_, $eqv));
    my @coeff = find_forcefield_coeffs(\%ForceFieldTable, @k);
    if ($warning&&(!scalar(@coeff))&&($Type{$_} ne "")) {
      my $error = 1;
      if ($name_auto ne "") {
	$type = join(",", @k = auto_equivalence($_, $eqv));
	@coeff = find_forcefield_coeffs(\%ForceFieldAutoTable, @k);
	if (($class eq "class2")&&(($eqv eq "bond")||($eqv eq "angle"))) {
	  push(@coeff, 0, 0);
	}
	elsif (($eqv eq "torsion")&&$coeff[1]) {

	  # .frc states 1-cos(x) for torsion_3, which discover uses
	  # .frc states 1+cos(x) for torsion_1, which discover uses
	  # conversion of 1+cos(x) to 1-cos(x) (needed by LAMMPS)
	  
	  $coeff[2] += $coeff[2]<180 ? 180 : -180;
	  @k = (0, 0, 0, 0, 0, 0);
	  my $j = ($coeff[1]-1)*2;
	  @k[$j, $j+1] = @coeff[0,2];
	  @coeff = @k;
	}
	if (scalar(@coeff)) {
	  $error = 0; ++$nautos{"total"}; ++$nautos{$eqv}; }
      }
      print("Warning: $id type for [$type] not found\n") if ($error);
    }
    else {
      @coeff = complete_forcefield_coeffs($name, $_, @coeff);
    }
    printf($LAMMPS "%8d", $i++);
    @coeff = reverse(@coeff) if ($eqv eq "nonb");
    while (scalar(@coeff)<$NCoeffs{$id}) { push(@coeff, 0); }
    foreach (@coeff) { printf($LAMMPS " %10.4f", $_); }
    printf($LAMMPS "  # $format -> $format", $_, $type) if ($comment);
    printf($LAMMPS "\n");
  }
  printf($LAMMPS "\n");
}


# structure

sub write_lammps_atoms {
  my @njoins = @NJoins;
  my @files = @_;
  my $imol = 0;
  my $last = 0;
  my @arg = ();
  my $id = 0;
  my $n = 0;
  my $file;
  my $njoin;

  return if (!$NAtoms);
  $file = shift(@files);
  $njoin = shift(@njoins);
  printf($LAMMPS "Atoms\n\n");
  for ($n=1; $n<=$NAtoms; ++$n) {
    if ($n==$njoin+1) {
      $file = shift(@files); $njoin = shift(@njoins); ++$id;
      ++$imol if ($n>1);
    }
    if (eof($file)) { 
      print("Error: unexpected eof for $FileName[$id].\n"); exit; }
    @arg = read_car_next($file, $last); $last = @arg[-1];
    my $i; for ($i=0; $i<3; ++$i) { $pos[$i] = $arg[$i+1]+$offset[$i+3*$id]; }
    printf($LAMMPS "%8d", $n);					# atom
    printf($LAMMPS " %7d", $imol += $arg[5]-$last);		# mol
    printf($LAMMPS " %3d", $TypeAtomHash{$arg[6]});		# type
    printf($LAMMPS " %7.4f", $AtomCharge[$n-1]);		# charge
    printf($LAMMPS " %14.9f %14.9f %14.9f", v_pbc(@pos));	# x, y, z
    printf($LAMMPS "%s\n", $comment ? "  # $arg[6]" : "");
    $last = $arg[5];
  }
  printf($LAMMPS "\n");
  read_car_next($file);
}


sub write_lammps_bonds {
  my $title = shift(@_);
  my $nbonds = shift(@_);
  my @type = delete(@_[$nbonds .. 2*$nbonds-1]);
  my @arg = ();
  my $n = 0;

  return if (!$nbonds);
  printf($LAMMPS "$title\n\n");
  foreach (@_) {
    @arg = split(",");
    printf($LAMMPS "%8d", ++$n);				# bond
    printf($LAMMPS " %7d", shift(@type));			# type
    foreach (@arg) { printf($LAMMPS " %7d", $_); }		# atoms
    if ($comment) {
      my @type = ();
      foreach (@arg) { push(@type, $TypeAtomID[$AtomType[$_]]); }
      printf($LAMMPS "  # %s", join(",", @type));
    }
    printf($LAMMPS "\n");
  }
  printf($LAMMPS "\n");
}


sub write_lammps_types {
  my $file = shift(@_);

  %ForceFieldBondTable = create_forcefield_table(2, "quartic_bond", 0, 0);
  %ForceFieldAutoBondTable = create_forcefield_table(2, "quadratic_bond", 1, 0);
  %ForceFieldAngleTable = create_forcefield_table(3, "quartic_angle", 0, 0);
  %ForceFieldAutoAngleTable = create_forcefield_table(3, "quadratic_angle", 1, 0);

  write_lammps_masses();
  write_lammps_coeff_pair();
  write_lammps_coeff_bond();
  write_lammps_coeff_angle();
  write_lammps_coeff_dihedral();
  write_lammps_coeff_improper();
}


sub write_lammps_structure {
  write_lammps_atoms(@_);
  write_lammps_bonds("Bonds", $NBonds, @BondList, @BondType);
  write_lammps_bonds("Angles", $NAngles, @AngleList, @AngleType);
  write_lammps_bonds("Dihedrals", $NDihedrals, @DihedralList, @DihedralType);
  write_lammps_bonds("Impropers", $NImpropers, @ImproperList, @ImproperType);
}


sub files_eof {
  foreach (@_) { return 1 if (eof($_)); }
  return 0;
}


sub write_lammps {
  my @written = ();
  my @files = ();
  my $id = 0;
  my $i;

  foreach (@FileName) {
    push(@files, open_file("<$_.".($archive ? "arc" : "car")));
  }
  my $nfiles = scalar(@files);
  while (!files_eof(@files)) {
    @offset = ();
    for ($i=0; $i<$nfiles; ++$i) { push(@offset, (0,0,0,0,0,0)); }
    my $NConfsJoin = -1;
    my $ifile = 0;
    my $hdir = 0;
    my @h = (0, 0, 0);
    my @h2 = ();
    for ($i=0; $i<$nfiles; ++$i) {
      my $file = $files[$i];
      my $j;

      read_car_header($file);
      if ($PBCFlag) {
	for ($j=0; $j<3; ++$j) { $offset[3*$ifile+$j] = $Box[$j]; }
	my @h1 = (v_subtr(@Box[3 .. 5], @Box[0 .. 2]), @Box[6 .. 8]);
	$offset[3*$ifile+$dir] = $hdir;
	$hdir += $h1[$dir];
	@h = v_max(@h[0 .. 2], @h1[0 .. 2]);
      }
      ++$ifile;
      if ($NConfsJoin < 0) {
	$NConfsJoin = $NConfigurations;
	next;
      }
      if ($NConfsJoin != $NConfigurations) {
	print("Error: ".
	  "inconsistent number of configurations in joined project.\n");
	exit;
      }
    }
    $id = $ConfigurationID ? $ConfigurationID-1 : $id;
    last if (files_eof(@files)||$written[$id]);
    %nautos = (
      "total" => 0, "bond" => 0, "angle" => 0, "torsion" => 0, "oop" => 0);
    $written[$id] = 1;
    my $dir = sprintf($dir_format, $id);
    my $name = $archive ? "$dir/$base.data" : "$base.data";
    mkdir($dir) if ($archive);
    print("Info: writing lammps data file $name\n") if ($info);
    open($LAMMPS, ">$name");
    write_lammps_header();
    write_lammps_types();
    write_lammps_structure(@files);
    close($LAMMPS);
    ++$id;
  }
  foreach (@files) { close($_); }
}


# main

  initialize();
  open_forcefield();
  read_structure();
  write_lammps();
  close_forcefield();
  summary();

