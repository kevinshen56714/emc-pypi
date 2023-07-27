#!/usr/bin/env perl
#
#  program:	emc_martini.pl
#  author:	Pieter J. in 't Veld
#  date:	December 8, 2012, October 30, 2014, November 28, 2015,
#  		October 16, 2019, March 21, 2021.
#  purpose:	interpret Martini force field files and convert them into
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
#    20141030	- Fixed SMILES determination for rings
#    20151130	- Fixed links for interconnected rings
#    20191016	- Change to v1.4
#    		- Set NEquivalences to 7
#    20210321	- Change to v2.0
#    		- Added mass definitions of all types
#    		- Added information from martini.itp to all force fields
#    		- Updated local variable definitions

# settings

use File::Basename;

$script = basename($0);
$author = "Pieter J. in 't Veld";
$version = "v2.0";
$date = "March 21, 2021";
$EMCVersion = "9.4.4";

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
$FFMode = "MARTINI";
$FFApply = "ALL";
$Version = "2011";
$Source = "src";

$Accuracy = 0.001;
$Energy = "KJ/MOL";
$Density = "G/CC";
$Length = "NANOMETER";
$Mix = "NONE";
$NBonded = 1;
$Inner = 0.9;
$Cutoff = 1.2;
$ImproperDouble = 0;
$KConstraint = 20000;
@MassDefault = (72, 54);

@SearchDirectory = ((split($script, $0))[0], "src/", "");

# functions

# initialization

sub header {
  message("Martini conversion $version, $date, (c) $author\n\n");
}

sub help {
  $Message = 1;
  header();
  message("Usage:\n  $script [-option[=value]] file[.itp] ...\n");
  message("\nOptions:\n");
  message("  -debug\tTurn debug messages on\n");
  message("  -double\tAdd inversed doubles to improper list\n");
  message("  -help\t\tThis message\n");
  message("  -info\t\tTurn messages and info on\n");
  message("  -literature\tShow literature references\n");
  message("  -output\tSet alternate output file name\n");
  message("  -quiet\tTurn all output off\n");
  message("  -source\tSet source directory [$Source]\n");
  message("\nNotes:\n");
  message("  * Assumes existing input files: file.itp\n");
  message("  * Creates output: file.prm | [output.prm]\n");
  message("\n");
  exit;
}


sub init {
  my @names = ();
  my $fmartini = 1;

  $BondedName = "";
  $ParameterName = "";
  foreach (@_) {
    if (substr($_, 0, 1) eq "-") {
      my @arg = split("=");
      my $flag = @arg[1] eq "" ? 1 : eval(@arg[1]) ? 1 : 0;
      if ($arg[0] eq "-help") { help(); }
      elsif ($arg[0] eq "-debug") { $Debug = 1; }
      elsif ($arg[0] eq "-double") { $ImproperDouble = $flag; }
      elsif ($arg[0] eq "-ffapply") { $FFApply = $arg[1]; }
      elsif ($arg[0] eq "-info") { $Message = 1; }
      elsif ($arg[0] eq "-literature") { $Literature = 1; }
      elsif ($arg[0] eq "-quiet") { $Message = $Debug = 0; }
      elsif ($arg[0] eq "-output") { $CreatedParameterName = $arg[1]; }
      elsif ($arg[0] eq "-source") { $Source = $arg[1]; }
      else { help(); }
      next;
    }
    push(@names, $_);
  }
  help() if (scalar(@names)<1);
  foreach(@names) { 
    $fmartini = 0 if (($_ = sstrip(sstrip($_, ".prm"), ".itp")) eq "martini");
  }
  header(); 
  info("adding inversed doubles to impropers\n") if ($ImproperDouble);
  if ($Source ne "") {
    foreach (@names) { $_ = $Source."/".$_; }
  }
  init_martini() if ($fmartini);
  fspool(@names);
  $CreatedParameterName = $names[0] if ($CreatedParameterName eq "");
  $CreatedParameterName = sstrip($CreatedParameterName, ".itp");
  $CreatedParameterName = sstrip($CreatedParameterName, ".prm");
  $CreatedParameterName = sappend($CreatedParameterName, ".prm");
}


sub init_martini {
  return if (scalar($IN_PARMS));
  $IN_PARMS = fopen("$Source/martini.itp", "r");
  get_masses();
  get_nonbonds();
  %MMasses = %Masses;
  %MNonbond = %Nonbond;
  undef(%Masses);
  undef(%Element);
  undef(%Nonbond);
  undef(%Equivalences);
  fclose($IN_PARMS);
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
  my $file;
  my $result;

  error("illegal mode") if (!($mode eq "r" || $mode eq "w"));
  info("opening \"$name\" for", ($mode eq "r" ? "read" : "writ")."ing\n")
    if (substr($name,-4,4) ne ".tmp");
  open($file, ($mode eq "r" ? "<" : ">").$name);
  error("cannot open file \"$name\"") if (!scalar(stat($file)));
  return $file;
}


sub fclose {
  my $file = shift(@_);

  close($file) if (scalar($file));
}


sub open_all {
  $IN_PARMS = fopen($ParameterName, "r") if (!scalar(stat($IN_PARMS)));
  $OUT_PARMS = fopen($CreatedParameterName, "w") if (!scalar(stat($OUT_PARMS)));
  $OUT_TOPOL = $OUT_PARMS;
}


sub close_all {
  fclose($IN_PARMS);
  fclose($OUT_PARMS);
  unlink($ParameterName);
}


sub fspool() {
  $ParameterName = "martini.$$.tmp";
  my $output = fopen($ParameterName, "w");
  foreach (@_) {
    my $input = fopen(sappend($_, ".itp"), "r");
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
  return @_ if (@_[0] lt @_[-1]);
  if (@_[0] eq @_[-1]) {
    return @_ if (scalar(@_) < 4);
    return @_ if (@_[1] lt @_[2]);
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

sub split_line {
  my @arg;

  foreach (split(" ", $_)) {
    last if (substr($_,0,1) eq ";");
    push(@arg, $_);
  }
  return @arg;
}


sub get_version {
  seek($IN_PARMS, 0, 0);
  foreach(<$IN_PARMS>) {
    my @arg = split_line($_);
    next if (!scalar(@arg));
    if (@arg[1] eq "FORCEFIELD") {
      $Version = @arg[2];
    } elsif (@arg[2] eq "FORCEFIELD") {
      $FFMode = @arg[1];
      $Version = @arg[3];
      last;
    } elsif (@arg[2] eq "updated" && $Version eq "") {
      $Version = @arg[-1];
    }
    last if (substr($_,0,1) ne ";");
  }
}


sub get_masses {
  my $type;
  my $mass;
  my $charge;
  my $ptype;
  my $c6;
  my $c12;
  my $s;
  my $read = 0;

  undef(%Masses);
  undef(%Element);
  seek($IN_PARMS, 0, 0);
  foreach(<$IN_PARMS>) {
    my @arg = split_line($_);
    next if (!scalar(@arg));
    if (!$read) {
      $read = 1 if (join("", @arg) eq "[atomtypes]");
      next;
    }
    last if (substr($arg[0],0,1) eq "[");
    next if (scalar(@arg)<2);
    $type = shift(@arg);
    $mass = shift(@arg);
    $charge = eval(shift(@arg));
    $ptype = shift(@arg);
    $c6 = shift(@arg);
    $c12 = shift(@arg);
    $Element{$type} = $type;
    $Masses{$type} = join("\t", $type, $mass, 2, $charge);
    my @equi = ();
    for (my $i = 0; $i<$NEquivalences; ++$i) { push(@equi, $type); }
    $Equivalences{$type} = join("\t", @equi);
  }
}


sub get_nonbonds {
  my $type1;
  my $type2;
  my $function;
  my $c6;
  my $c12;
  my $sigma;
  my $eps;
  my $read = 0;

  undef(%Nonbond);
  seek($IN_PARMS, 0, 0);
  foreach(<$IN_PARMS>) {
    my @arg = split_line($_);
    next if (!scalar(@arg));
    if (!$read) {
      $read = 1 if (join("", @arg) eq "[nonbond_params]");
      debug("getting nonbonds\n") if ($read);
      next;
    }
    last if (substr($arg[0],0,1) eq "[");
    next if (scalar(@arg)<2);
    $type1 = shift(@arg);
    $type2 = shift(@arg);
    $function = shift(@arg);
    $c6 = shift(@arg);
    $c12 = shift(@arg);
    $sigma = $c6<=0.0 ? 0.0 : round(($c12/$c6)**(1/6), $Accuracy);
    $eps = $c12<=0.0 ? 0.0 : round(0.25*$c6*$c6/$c12, $Accuracy);
    if ($type2 lt $type1) {
      my $t = $type1; $type1 = $type2; $type2 = $t;
    }
    debug("nonbond [$type1 $type2] [$c6 $c12] -> [$sigma $eps]\n");
    $Nonbond{join("\t", $type1, $type2, $sigma, $eps)} = 1;
  }
}


sub assign_mass {
  my $type = shift(@_);
  my $mass = shift(@_);
  my $charge = eval(shift(@_));
  my $set = shift(@_);
  my $fcount = shift(@_);
  my @equi = split("\t", $Equivalences{$type});
  my $flag = scalar(@equi)<1 ? 1 : 0;

  debug("equivalence [@equi]");
  $mass = @MassDefault[(substr($type,0,1) eq "S" ? 1 : 0)] if ($mass eq "");
  $charge = 0 if ($charge eq "");
  my $t = @equi[1]; $t = $type if ($t eq "");
  $Element{$type = $t.($fcount ? ++$Count{$t} : "")} = $t;
  @equi[0] = $type;
  my $i; for ($i=1; $i<$NEquivalences; ++$i) { 
    @equi[$i] = $i<$set ? (@equi[$i] eq "" ? $t : @equi[$i]) : $type; }
  print(" -> [@equi]\n") if ($Debug);
  $Masses{$type} = join("\t", $type, $mass, 2, $charge);
  $Equivalences{$type} = join("\t", @equi);
  info("assigning new mass $type for molecule $MoleculeName\n") if ($fcount);
  return $type;
}


sub compare {
  return $NConnects[$a] > $NConnects[$b] ? -1 :
    $NConnects[$a] < $NConnects[$b] ? 1 : $b<$a ? -1 : 1;
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
    my $t;
    my $i = 0;
    my @x;
    my @n = @$nconnects;
    my @idx = @$index;
    
    foreach (@idx) { @x[$i] = $i; $i++; }
    @x = sort({@n[@idx[$a]] > @n[@idx[$b]] ? -1 :
       	@n[@idx[$a]] < @n[@idx[$b]] ? 1 : @idx[$a] < @idx[$b] ? -1 : 1} @x);
    $i = 0; foreach (@x) { 
      last if (@{$orig}[@idx[$_]] eq @{$types}[@idx[$_]]); ++$i; }
    if ($i<scalar(@x)) { 
      my $id = @idx[@x[$i]];				# assign new mass
      my $mass = (split("\t", $Masses{@arg[@x[$i]]}))[1];
      my $charge = eval((split("\t", $Masses{@arg[@x[$i]]}))[-1]);
      my @a = split("\t", @$atoms[$id]); shift(@a);
      @arg = @{$types}[@{$index}];
      $type = assign_mass(@arg[@x[$i]], $mass, $charge, $dim, 1);
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
  } elsif ($improper && $ImproperDouble) {
    $$bonded{$key} = $parms;
    $$bonded{join("\t", (split("\t", $key))[0,1,3,2])} = $parms;
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
    ++@{$nconnects}[$_] if ($nconnects);
    if (${$current} eq "") {				# assign first
      ${$current} = $_; next;
    }
    my $add = $_;
    my @a = split("\t", ${$current});
    foreach (@a) {					# check existing bond
      $add = "" if ($add eq $_); }
    next if ($add eq "");				# skip existing
    ${$current} = 
      join("\t", shift(@a), sort {$a <=> $b} @a,$add);	# assign connection
  }
}


sub smiles_entry {					# create single entry
  my $atoms = shift(@_);
  my $entry = shift(@_);

  my @arg = split("\t", @$atoms[$entry]);
  my $charge = eval(@arg[-1]);
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
  my @nlink = @{@{$link}[$first]};
  my $amp = "";

  @$visit[$first] = 1;
  debug("links on site [$first] = {".join(", ", @nlink)."}\n");
  foreach (@nlink) { if ($_>9) { $amp = "%"; last ; } }
  foreach (@nlink) { $smiles .= "$amp$_"; }
  foreach (sort({$a <=> $b} @id)) {
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


sub append_link {
  return @_[0] ne "" ? "@_[0],@_[1]" : @_[1];
}


sub set_links {
  my $current = shift(@_);
  my $parent = shift(@_);
  my $connect = shift(@_);
  my $visited = shift(@_);
  my $link = shift(@_);
  my $nlink = shift(@_);
  my $level = shift(@_);
  my @connects = split("\t", @{$connect}[$current]); shift(@connects);

  @$visited[$current] = $level;
  debug("scanning links: site [$current] with [".join(", ", @connects)."]\n");
  foreach (sort({ $b <=> $a} @connects)) {
    next if ((!@$visited[$_]) || ($_ == $parent));
    my $n = scalar(@{$link[$_]});
    my $m = scalar(@{$link[$current]});
    my $i; for ($i=0; $i<$n; ++$i) {
      my $j; for ($j=0; $j<$m; ++$j) {
	last if (@{$link[$_]}[$i] == @{$link[$current]}[$j]); }
      last if ($m && ($j<$m));
    }
    next if ($n && ($i<$n));
    debug("linking [$current, $_] with $$nlink, level = $level\n");
    push(@{$link[$current]}, ${$nlink}); push(@{$link[$_]}, ${$nlink}++);
  }
  foreach (sort { $a <=> $b} @connects) {
    next if (@$visited[$_]);
    set_links($_, $current, $connect, $visited, $link, $nlink, $level+1);
  }
  return;
}


sub smiles {						# create smiles
  my $current = shift(@_);
  my $connects = shift(@_);
  my $atoms = shift(@_);
  my $count = 1;
  my $i;
  my $k = 0;
  my $nlink = 1;
  my $n = scalar(@$atoms);
  my @entry = ("");
  my @visit = (0);
  my @bonds = ();
  my @link = ([]);
  my @cross = ();

  debug("creating smiles\n");
  for ($i=1; $i<$n; ++$i) {				# create entries
    push(@entry, smiles_entry($atoms, $i));
    push(@visit, 0); push(@link, []);
  }
  foreach (@{$connects}) {
    next if ($_ eq "");
    $_ = "$k" if ($_ eq "");
    my @id = split("\t");
    my $i = shift(@id);
    foreach (sort(@id)) {
      assign_connect(\@cross, 0, $i, $_);
      assign_connect(\@cross, 0, $_, $i);
    }
  }
  foreach (@{$connects}) {
    debug("connects: [$_]\n");
  }    
  $cross[1] = $current if (scalar(@cross)==0);
  set_links($current, -1, \@cross, \@visit, \@link, \$nlink, 1);
  foreach (@link) {					# post process links
    if (scalar(@{$_})) {
      foreach (@{$_}) { $_ = $nlink-$_; }; @{$_} = sort({$a <=> $b} @{$_}); }
  }
  foreach (@visit) { $_ = 0; }				# reset
  return smiles_rec($current, \@cross, \@entry, \@link, \@visit);
}


sub assign_template {					# create template
  my $name = shift(@_);
  my $connects = shift(@_);
  my $atoms = shift(@_);

  assign_connect($connects, 0, 1);
  assign_connect($connects, 0, scalar(@$atoms)-1);
  if ($Templates{$name} eq "") {
    debug("assigning template for [$name]\n");
    $Templates{$name} = smiles(1, $connects, $atoms);
  } else {
    warning("skipping template [$name] redefinition\n");
  }
  @$connects = ();
  return 0;
}


sub get_molecules {
  %{$Bond}= ();
  %{$Angle} = ();
  %{$Torsion} = ();
  %{$Improper} = ();
  seek($IN_PARMS, 0, SEEK_SET);

  my @lines = <$IN_PARMS>; push(@lines, "");
  my $mode = 0, $template = 0;
  my $name, $nrexcl;
  my ($id, $type, $resnr, $residue, $atom, $cgnr, $charge, $mass, $masses);
  my ($parms, $current, $last, $function);
  my @connects = ();
  my @nconnects = ();
  my (@i, @un, @p, $k, $line0, $linen, $t);
  my (@atoms, @types, @index, @orig);
  my $pass = 1;
  my $line = 0;
  my ($lastline, $pos, @tmp, $bonded);
  my @list = (0, 0, 0, \%Bond, \%Bond, \%Angle, \%Torsion, \%Improper);

  my @headings = (					# paragraph index
    "[moleculetype]", "[atoms]", "[constraints]",
    "[bonds]", "[angles]", "[dihedrals]", "[impropers]");
  my @nindices = (0, 0, 1, 2, 2, 3, 4, 4);
  my @paragraphs = (), $paragraph;

  foreach (@lines) {
    my @arg = split_line($_);
    if (substr(@arg[0],0,1) eq "[") {
      push(@paragraphs, join(" ", $paragraph, $line)) if ($paragraph ne "");
      @arg = scrub(@arg); $i = 0; $mode = 0;
      foreach(@headings) { 
	++$i; next if (join("", @arg) ne $_); $mode = $i; last;
      } 
      $paragraph = join(" ", $mode, $line+1);
    }
    ++$line;
  }
  push(@paragraphs, join(" ", $paragraph, $line)) if ($paragraph ne "");

  foreach (@paragraphs) {				# data interpretation
    ($mode, $line0, $linen) = split(" ", $_);
    next if ($mode == 0);
    debug("getting ".@headings[$mode-1]."\n");
    $bonded = @list[$mode];
    if ($mode==1) {					# molecule type
      $template = assign_template($name, \@connects, \@atoms) if ($template);
      $mode = 1; @atoms = (); @types = (); @connects = ();  @nconnects = ();
      $name = "";
      for ($line=$line0; $line<$linen; ++$line) {
	$_ = @lines[$line]; my @arg = split(" "); next if ($arg[0] eq "");
	$MoleculeName = $name = shift(@arg);
	$nrexcl = shift(@arg);
      }
      debug("getting molecule [$name]\n");
    } elsif ($mode==2) {				# atoms
      for ($line=$line0; $line<$linen; ++$line) {
	$_ = @lines[$line]; my @arg = split_line($_); next if ($arg[0] eq "");
	next if (substr($arg[0],0,1) eq ";");
	($id, $type, $resnr, $residue, $atom, $cgnr, $charge, $t, $mass) = @arg;
	$mass = $t if ($t ne "" && $t ne ";");
	if ($type ne "" && !defined($Masses{$type})) {
	  assign_mass($type, $mass, $charge, 2, 0);
	} elsif ($mass>0.0) {
	  my $t = "";
	  my $v;

	  foreach (keys(%Masses)) {
	    next if ($type ne (split("\t", $Equivalences{$_}))[1]);
	    $t = $_ if ($mass eq (split("\t", $Masses{$_}))[1]);
	  }
	  $type = $t ne "" ? $t : assign_mass($type, $mass, $charge, 2, 1);
	}
	$atoms[$id] = join("\t", $type, $resnr, $residue, $atom, $charge);
	$types[$id] = $orig[$id] = $type;
      }
      $template = 1;
    } else {						# bonded contributions
      if ($mode<5) {					# create connectivity
	for ($line=$line0; $line<$linen; ++$line) {
	  $_ = @lines[$line]; my @arg = split(" "); next if ($arg[0] eq "");
	  next if (substr($arg[0],0,1) eq ";");
	  check(\@types, $line, @index = order(@arg[0,1]));
	  assign_connect(\@connects, \@nconnects, @index);
	}
      }
      $template = 1; $last = ""; $parms = ""; $nindex = @nindices[$mode];
      %tmp = %$bonded;
      for ($pass=0; $pass<4; ++$pass) {
	%$bonded = %tmp if ($pass);
	for ($line=$line0; $line<$linen; ++$line) {
	  $_ = @lines[$line]; my @arg = split(" "); next if ($arg[0] eq "");
	  next if (substr($arg[0],0,1) eq ";");
	  my @i = (), $j; for ($j=0; $j<$nindex; ++$j) { push(@i,shift(@arg)); }
	  $function = shift(@arg);
	  check(\@types, $line, @i = order(@un = @i));
	  $current = join("\t", @i);
	  @arg = smooth(scrub(@arg));
	  push(@arg, $KConstraint) if ($mode==3);	# constraint exception
	  if ($mode==6) {				# torsion exceptions
	    if ($function!=2) {
	      assign_parms($bonded,
	       	\@nconnects, \@p, \@types, \@orig, \@atoms, $parms, $mode)
		if (($line == $n-1) || ($last ne "" && $last ne $current));
	      $arg[0] -= 360 if (($arg[0] %= 360)>180);
	      my $t = join("\t", @arg[1,2,0]);		# k, n, delta
	      $parms = $current ne $last ? $t : "$parms\t$t";
	      @p = @i; $last = $current;
	      next;
	    }
	    my $t = join("\t", @arg[1,0]);
	    assign_parms(\%Improper,
	      \@nconnects, \@un, \@types, \@orig, \@atoms, $t, 7) if ($pass==1);
	    next;
	  } else {
	    $parms = join("\t", @arg[1,0]);
	    assign_parms($bonded,
	      \@nconnects, \@i, \@types, \@orig, \@atoms, $parms, $mode);
	  }
	}
      }
    }
  }
  assign_template($name, \@connects, \@atoms) if ($template);
}


# output

sub transcribe_martini {
  my %keys;
  my %extra;

  foreach (keys(%Element)) {
    next if ($Element{$_} eq $_);
    $extra{$Element{$_}} = {} if (!defined($extra{$Element{$_}}));
    ${$extra{$Element{$_}}}{$Element{$_}} = 1;
    ${$extra{$Element{$_}}}{$_} = 1;
  }
  foreach (keys(%Nonbond)) {
    @arg = split("\t");
    $keys{join("\t", order(@arg[0,1]))} = 1;
  }
  foreach (keys(%MNonbond)) {
    @arg = split("\t");
    next if (defined($keys{join("\t", order(@arg[0,1]))}));
    next if (!defined($Element{@arg[0]}));
    next if (!defined($Element{@arg[1]}));
    $Nonbond{join("\t", @arg)} = 1;
  }
}


sub put_header {
  my $file = shift(@_);
  my $text = shift(@_);
  my $definition = shift(@_);

  printf($file "#
#  Martini $text using $ParameterName
#  converted by $script $version, $date by $author
#  to be used in conjuction with EMC v$EMCVersion or higher
#\n");

  return if (!$definition);
  printf($file "\n# Force field definition\n\n");
  printf($file "ITEM\tDEFINE\n\n");
  printf($file "FFMODE\t$FFMode\n");
  printf($file "FFTYPE\t$FFType\n");
  printf($file "FFAPPLY\t$FFApply\n");
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
  printf($OUT_PARMS "# type\tmass\telement\tncons\tcharge\tcomment\n\n");
  foreach(sort values(%Masses)) {
    my @arg = split("\t");
    my $type = shift(@arg), $s;
    my $mass = shift(@arg);
    $comment = "";
    if (($s = substr($type, 0, 1)) eq "S") {
      $comment = "ring "; $s  = substr($type, 1, 1);
    }
    if ($s eq "P") {
      $comment .= "polar";
    } elsif ($s eq "N") {
      $comment .= "intermediate";
    } elsif ($s eq "C") {
      $comment .= "apolar";
    } elsif ($s eq "Q") {
      $comment .= "charged";
    } elsif ($s eq "B") {
      $comment = "big particle";
    } elsif ($s eq "D") {
      $comment = "dummy particle";
    } elsif (substr($type, 0, 2) eq "AC") {
      $comment = "amino acid";
    }
    next if ($Element{$type} eq "");
    printf($OUT_PARMS "%s\n", 
      join("\t", $type, $mass, $Element{$type}, @arg, $comment));
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
  transcribe_martini() if (%MNonbond);
  return if (!%Nonbond);

  info("writing nonbonded\n");
  printf($OUT_PARMS "\n# Nonbonded parameters\n\n");
  printf($OUT_PARMS "ITEM\tNONBOND\n\n");
  printf($OUT_PARMS "# type1\ttype2\tsigma\tepsilon\n\n");
  foreach (sort keys(%Nonbond)) {
    printf($OUT_PARMS "$_\n");
  }
  printf($OUT_PARMS "\nITEM\tEND\n");
  $BondAuto{join("\t", "*", "*")} = join("\t", 1250, 0.47);
  #$AngleAuto{join("\t", "*", "*", "*")} = join("\t", 25, 180);
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
    printf($OUT_PARMS "# type1\ttype2\ttype3\ttype4\tk\tn\tdelta\t...\n\n");
    foreach (sort keys(%TorsionAuto)) {
      printf($OUT_PARMS "$_\t%s\n", $TorsionAuto{$_});
    }
    printf($OUT_PARMS "\nITEM\tEND\n");
  }
    
  if (scalar(keys(%Torsion))) {
    printf($OUT_PARMS "\n# Torsion parameters\n\n");
    printf($OUT_PARMS "ITEM\tTORSION\n\n");
    printf($OUT_PARMS "# type1\ttype2\ttype3\ttype4\tk\tn\tdelta\t...\n\n");
    foreach (sort keys(%Torsion)) {
      printf($OUT_PARMS "$_\t%s\n", $Torsion{$_});
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
  get_nonbonds();
  get_molecules();

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

