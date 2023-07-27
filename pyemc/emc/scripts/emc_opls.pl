#!/usr/bin/env perl
#
#  program:	emc_opls.pl
#  author:	Pieter J. in 't Veld
#  date:	September 23 - October 12, November 16, 2012,
#  		March 21, 2013, December 30, 31, 2014, April 22, 2015,
#  		February 6, 2017, October 16, 2019.
#  purpose:	Interpret OPLSAA force field files and convert them into
#  		EMC textual force field formats; part of EMC distribution
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20120923	Conception date
#    20130324	Inclusion of extra torsion types
#    20141230	Debugged handling of extra torsion types
#    20150422	Changed mixing rule to GEOMETRIC
#    20170506	Added override to automated pruning of torsion types
#    20191016	Set NEquivalences to 7
#

# functions

$script = "opls.pl";
$author = "Pieter J. in 't Veld";
$version = "v0.8beta";
$date = "October 16, 2019";
$PARMS = 0;
$BONDS = 0;
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
$Increments = {};
$Templates = {};
$Active = {};
$Rules = {};
$Extras = {};
$Version = "";

$SourceName = "src/oplsaa";
$NOPLSUA = 54;	# start of OPLSUA parameters
$NOPLSAA = 135;	# start of OPLSAA parameters
$OPLSUA = 0;
$Dummy = lc("DM");
$LonePair = lc("LP");
$Wildcard = "*";
$Anything = "?";
$NTorsions = 0;
$Warning = 1;
$Message = 1;
$Debug = 0;
$Doubles = 0;
$FFMode = "";
$FFDepth = 3;
$FFShake = "ALL";
$FFCharge = "ALL";

sub check_shake {
  foreach ("NONE", "HYDROGEN", "WATER", "ALL") { return if ($_ eq uc(@_[0])); }
  error("unknown shake mode '@_[0]'");
}

sub error {
  printf("Error: %s\n\n", join(" ", @_));
  exit(-1);
}


sub warning {
  printf("Warning: %s", join(" ", @_)) if ($Warning);
}


sub debug {
  printf("Debug: \t%s", join("\t", @_)) if ($Debug);
}


sub info {
  printf("Info: %s", join(" ", @_)) if ($Message);
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
  $PARMS = fopen($ParameterName, "r") if (!scalar($PARMS));
  $BONDS = fopen($BondedName, "r") if (!scalar($BONDS));
  $OUT_PARMS = fopen($CreatedParameterName, "w") if (!scalar($OUT_PARMS));
  $OUT_TOPOL = fopen($CreatedTopologyName, "w") if (!scalar($OUT_TOPOL));
}


sub close_all {
  fclose($TOPOL);
  fclose($PARMS);
  fclose($BONDS);
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


sub redefine {
  return $Redefine{@_[0]} eq "" ? @_[0] : $Redefine{@_[0]};
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
    "extra types", "extra bonds", "extra angles", "extra torsions",
    "extra impropers", "references", "rules", "redefinitions", "repairs",
    "extra nonbonds");
  my @nargs = (1, 1, 5, 1, 3, 3, 4, 5, 5, 6, 4, 2, 2, 3, 4);

  $Masses = {};
  $Extras = {};
  $Rules = {};
  $Active = {};
  $Equivalence = {};
  seek($TOPOL, 0, 0);
  foreach(<$TOPOL>) {
    chop();
    next if (substr($_, 0, 1) eq "#");
    my @arg; foreach (split("\t")) {
      last if (substr($_,0,1) eq "#");
      push(@arg, $_) if ($_ ne "");
    }
    if (!$read) {
      $read = 1 if (join(" ", @arg[0, 1]) eq "ITEM DEFINE");
      $read = 2 if (join(" ", @arg[0, 1]) eq "ITEM MASS");
      $read = 2 if (join(" ", @arg[0, 1]) eq "ITEM MASSES");
      $read = 3 if (join(" ", @arg[0, 1]) eq "ITEM PRECEDENCE");
      $read = 4 if (join(" ", @arg[0, 1]) eq "ITEM EQUIVALENCE");
      $read = 5 if (join(" ", @arg[0, 1]) eq "ITEM EXTRA");
      $read = 14 if (join(" ", @arg[0, 1]) eq "ITEM NONBOND");
      $read = 6 if (join(" ", @arg[0, 1]) eq "ITEM BOND");
      $read = 7 if (join(" ", @arg[0, 1]) eq "ITEM ANGLE");
      $read = 8 if (join(" ", @arg[0, 1]) eq "ITEM TORSION");
      $read = 9 if (join(" ", @arg[0, 1]) eq "ITEM IMPROPER");
      $read = 10 if (join(" ", @arg[0, 1]) eq "ITEM REFERENCES");
      $read = 11 if (join(" ", @arg[0, 1]) eq "ITEM RULES");
      $read = 12 if (join(" ", @arg[0, 1]) eq "ITEM REDEFINE");
      $read = 13 if (join(" ", @arg[0, 1]) eq "ITEM REPAIR");
      info("reading $message[$read]\n") if ($read);
      next;
    }
    $read = 0 if (join(" ", @arg[0, 1]) eq "ITEM END");
    next if (!$read);
    next if (scalar(@arg)<@nargs[$read]);
    if ($read==1) {						# define
      foreach (@arg[0 .. 1]) { $_ = uc($_); }
      if ($arg[0] eq "FFMODE") { $FFMode = $arg[1]; }
      elsif ($arg[0] eq "FFDEPTH") { $FFDepth = $arg[1]; }
      elsif ($arg[0] eq "FFCHARGE") { $FFCharge = $arg[1]; }
      elsif (join(" ", @arg[0, 1]) eq "FFTYPE ATOMISTIC") { $OPLSUA = 0; }
      elsif (join(" ", @arg[0, 1]) eq "FFTYPE UNITED") { $OPLSUA = 1; }
      elsif ($arg[0] eq "SHAKE") { check_shake($FFShake = $arg[1]); }
    } elsif ($read==2) {					# masses
      $arg[0] = lc($arg[0]);
      $Masses{$arg[0]} = join("\t", @arg);
      $Element{$arg[0]} = $arg[2];
    } elsif ($read==3) {					# precedence
      next if ($_ eq "");
      push(@Precedences, lc($_));
    } elsif ($read==4) {					# equivalence
      $Type{$arg[1]} = 1;
      while (scalar(@arg)<$NEquivalences) { push(@arg, @arg[-1]); }
      $Equivalence{$arg[0]} =
      $EquivalenceAuto{$arg[0]} = join("\t", @arg);
    } elsif ($read==10) {					# references
      push(@References, join("\t", @arg[0,3,1,2]));
    } elsif ($read==11) {					# rules
      my $index = sprintf("%.10g", shift(@arg));
      $Active{$index} = 1;
      $Active{int($index)} = 1;
      my $l = length($n = scalar(@arg)), $i = 0;
      foreach (@arg) {
	$ext = substr(sprintf("%03ld", $i), -$l-1, 3);
	$Rules{$i++ ? "$index.$ext" : $index} = $_;
      }
    } elsif ($read==12) {					# redefine
	$Redefine{lc($arg[0])} = lc($arg[1]);
    } elsif ($read==13) {					# repair
	$Repair{lc(@arg[0])} = join("\t", @arg[1,2,3]);
    } elsif ($read==5) {					# extra
      foreach(@arg) { $_ = lc($_); }
      $Extras{$arg[0]} = join("\t", @arg);
    } elsif ($read==14) {					# nonbond
      my $key = join("\t", arrange(splice(@arg,0,2)));
      my $k = join("\t", @arg);
      $Nonbond{$key} = $k;
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
      next if (scalar(@arg)==6);
      my $key = join("\t", arrange(splice(@arg,0,4)));
      my $k = join("\t", @arg);
      $TorsionExtra{$key} = $k;
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


sub get_pairs {
  my $i, $key, %data, %count, %ref, @arg, %atom, $index, $number, $comment;
  my $charge, $sigma, $epsilon, $type, $element, $basis;
  my $n, $last;
  my $skip = 2;

  $Type = {};
  info("reading pairs\n");
  seek($PARMS, 0, 0);
  foreach(<$PARMS>) {
    @arg = split(" "); 
    if ($skip) { 
      $Version = join(" ", @arg[-2,-1]) if ($Version eq "");
      $skip--; next;
    }
    next if (substr($_, 0, 1) eq "#" || substr($_, 5, 2) eq "  ");
    last if (join(" ", @arg[0,1,2]) eq "Do not modify");
    next if (scalar(@arg)<2);
    $index = sprintf("%.10g", shift(@arg));
    $number = sprintf("%.10g", shift(@arg));
    $type = redefine(lc($element = shift(@arg)));
    $charge = sprintf("%.10g", shift(@arg));
    $sigma = sprintf("%.10g", shift(@arg));
    $epsilon = sprintf("%.10g", shift(@arg));
    $comment = join(" ", @arg);
    if ($Repair{$index} ne "") {				# repairs
      ($number, $element, $type) = split("\t", $Repair{$index});
    }
    $element = element($element);
    if ($type eq $Dummy) {
      $atom{$number} = $type = $Anything;
    } else {
      $atom{$number} = $element if ($Active{$index});
      $atom{$number} = $element if ($atom{$number} eq "");
    }
    next if (!$Active{$index});
    $key = join("\t", ($type, $sigma, $epsilon));
    $data{$index} = join("\t", ($index, $atom{$number}, $type, $charge, $sigma, $epsilon, $comment));
    $count{$key} = $ref{$type}++ if ($count{$key} eq "");
  }
  foreach (sort {$a <=> $b} keys(%data)) {
    @arg = split("\t", $data{$_});
    $atom{$arg[2]} = $arg[1];
  }
  $Index = {};
  #$Nonbond = {};
  $Type{$Wildcard} = 1;
  foreach (sort {$a <=> $b} keys(%data)) {
    @arg = split("\t", $data{$_});
    ($index, $element, $type, $charge, $sigma, $epsilon, $comment) = @arg;
    $index = $_;
    $key = join("\t", ($type, $sigma, $epsilon));
    $n = $ref{$type}>1 ? $index==int($index) ? $count{$key} ? (length($type)<2 ? "_" : "").$count{$key} : "" : "" : "";
    $key = join("\t", $type.$n, $type.$n);
    $Nonbond{$key} = join("\t",$sigma,$epsilon) if (!defined($Nonbond{$key}));
    $Type{$type} = 1;
    $Index{$index} = join("\t", 
      $index, $element, $type, $type.$n, $charge, $sigma, $epsilon, $comment);
    $Element{$type.$n} = $element if ($Element{$type.$n} eq "");
  }
}


sub print_doubles {
  my $header = shift(@_);
  
  return if (!scalar(@_));
  if ($Doubles) {
    print("\n$header\n\n");
    foreach (sort(@_)) { print("$_\n"); }
    print("\n");
  }
}


sub get_bond_angle {
  my %data, @arg, @id, $index, $key, @k, @comment, $i, $n;
  my $read = 0, $line = 0, %aline, %bline, @dangle, @dbond;
  my %naauto, %nbauto, %nangle, %nbond;

  info("reading bonds and angles\n");
  seek($BONDS, 0, 0);
  foreach(<$BONDS>) {
    ++$line;
    next if (substr($_, 0, 1) eq "#");
    @id = split("-", substr($_, 0, $n = substr($_, 5, 1) eq " " ? 5 : 8));
    next if (scalar(@id)<2 || scalar(@id)>3);
    next if (substr($_, $n, 1) ne " ");
    my $auto = 0, $dummy = 0;
    foreach(@id) {
      $_ = redefine(lc(redefine((split(" "))[0])));
      $dummy = 1 if ($_ eq $Dummy);
      $_ = $Wildcard if ($_ eq $Dummy);
      $auto |= $_ eq $Wildcard ? 1 : 0;
    }
    next if ($dummy||!(
	$Type{$id[0]} && $Type{$id[1]} && ($n == 5 ? 1 : $Type{$id[2]})));
    $key = join("\t", arrange(@id));
    @arg = split(" ", substr($_, $n, 100));
    for ($i=0; $i<2; ++$i) { $k[$i] = sprintf("%.10g", shift(@arg)); }
    $comment[$line] = join(" ", @arg);
    if ($n == 5) {
      if ($auto) {
	$BondAuto{$key} = join("\t", @k) if ($BondAuto{$key} eq "");
      } else {
	$Bond{$key} = join("\t", @k)  if ($Bond{$key} eq "");
	$bline{$key} = $line if (!$nbond{$key});
	if (($n = $nbond{$key})) {
	  ++$NBondDoubles;
	  for ($i=($n==1 ? 0 : 1); $i<2; ++$i) {
	    my $l = $i ? $line : $lline{$key};
	    my $id = $i ? $index : (split("\t", $Bond{$key}))[-1];
	    push(@dbond, "$key\t$id\t$l\t$comment[$l]");
	  }
	}
	++$nbond{$key};

	if ($OPLSUA && $key =~ m/ct/) {
	  my $tmp = $key;
	  $tmp =~ s/ct/c\*/g;
	  $tmp = join("\t", arrange(split("\t", $tmp)));
	  $BondAuto{$tmp} = join("\t", @k) if (!$nbauto{$tmp});
	  ++$nbauto{$tmp};
	}
      }
    } else {
      if ($auto) {
	$AngleAuto{$key} = join("\t", @k) if ($AngleAuto{$key} eq "");
      } else {
	$Angle{$key} = join("\t", @k) if ($Angle{$key} eq "");
	$aline{$key} = $line if (!$nangle{$key});
	if (($n = $nangle{$key})) {
	  ++$NAngleDoubles;
	  for ($i=($n==1 ? 0 : 1); $i<2; ++$i) {
	    my $l = $i ? $line : $lline{$key};
	    my $id = $i ? $index : (split("\t", $Angle{$key}))[-1];
	    push(@dangle, "$key\t$id\t$l\t$comment[$l]");
	  }
	}
	++$nangle{$key};

	if ($OPLSUA && $key =~ m/ct/) {
	  my $tmp = $key;
	  $tmp =~ s/ct/c\*/g;
	  $tmp = join("\t", arrange(split("\t", $tmp)));
	  $AngleAuto{$tmp} = join("\t", @k) if (!$naauto{$tmp});
	  ++$naauto{$tmp};
	}
      }
    }
  }
  print_doubles("BOND DOUBLES", @dbond);
  print_doubles("ANGLE DOUBLES", @dangle);
}


sub get_torsion_improper {
  my %data, @arg, $index, $key, @k, $i, $n, %ntorsion, %nauto, @id;
  my $read, $line, $comment, @doubles, @nindex, $indexn;

  $read = $line = 0;
  info("reading torsions and impropers\n");
  print("\n") if ($Debug);
  debug("TORSIONS:\n");
  debug("\n");
  seek($PARMS, 0, 0);
  foreach(<$PARMS>) {
    ++$line;
    next if (substr($_, 0, 1) eq "#");
    @arg = split(" ");
    if (!$read) {
      $read = 1 if ($arg[0] eq "Type");
      next;
    }
    next if (scalar(@arg)<2);
    $indexn = $index = sprintf("%.10g", shift(@arg));
    $indexn = "$index.$nindex[$index]" if ($nindex[$index]);
    ++$nindex[$indexn];
    next if ($index == 100 || $index == 500);
    @k = ();
    for ($i=0; $i<4; ++$i) {
      my $v = sprintf("%.10g", shift(@arg));
      next if ($i&&!$v);
      push(@k, $v);
      push(@k, $i+1);
      push(@k, 0);
    }
    $key = substr($_, 47, 15);
    $key =~ s/[()]/ /g;
    @id = split("-", $key);
    my $auto = 0, $flag = 1, $check = 0;
    foreach(@id) {
      $_ = redefine(lc((split(" "))[0]));
      my $f = (($_ eq $Dummy)||($_ =~ m/\?/)||($_ eq "cm")) ? 1 : 0;
      $flag &= $Type{$_} if (!$f);
      $auto |= $f; $check |= ($_ eq "?t") ? 1 : 0;
      $_ = $Wildcard if (($_ eq $Dummy)||($_ eq "??"));
      $_ = $Wildcard.substr($_,1,1) if (substr($_,0,1) eq "?");
      $_ = substr($_,0,1).$Wildcard if (substr($_,1,1) eq "?");
    }
    next if (!$flag);
    if (substr($_, 63, 40) =~ m/improper/) {
      foreach(@id) { $_ = "*" if ($_ eq "x" || $_ eq "y" || $_ eq "z"); }
    }
    if (substr($_, 63, 40) =~ m/improper/) {
      $key = join("\t", arrange_imp(@id[1,0,2,3]));
      if ($OPLSUA) {
	if ($key =~ m/ct/) {
	  $key =~ s/ct/c\*/g;
	  $key = join("\t", arrange(split("\t", $key)));
	}
      }
      my $data = join("\t", $k[4]**2/4*$k[3], $k[2]);
      if ($key =~ m/\*/) {
	$ImproperAuto{$key} = $data if ($ImproperAuto{$key} eq "");
      } else {
	$Improper{$key} = $data if ($Improper{$key} eq "");
      }
      next;
    }
    $key = join("\t", @id = arrange(@id));
    @arg = split(" ", substr($_, 63, 40));
    $TorsionComment{$indexn} = $line.(scalar(@arg)>0 ? "\t".join(" ", @arg):"");
    $TorsionIndexN{$indexn} = join("\t", $key, @k);
    if ($auto) {
      if ($OPLSUA) {
	if ($key =~ m/ct/) {
	  $key =~ s/ct/c\*/g;
	  $key = join("\t", arrange(split("\t", $key)));
	}
      }
      $TorsionAuto{$key} = join("\t", @k, $indexn) if (!$nauto{$key});
      ++$nauto{$key};
    } else {
      debug("\t$indexn\t$key\t".join("\t", @k)."\n");
      if (!($n = $ntorsion{$key})) {
	$Torsion{$key} = join("\t", @k, $indexn);
	$TorsionKey{$NTorsions} = $key;
	my $ti = $TorsionIndex{$index};
	$TorsionIndex{$index} = $ti eq "" ? 
	    $NTorsions : join("\t", split("\t", $ti), $NTorsions);
	++$NTorsions;

	if ($OPLSUA && $key =~ m/ct/) {
	  my $tmp = $key;
	  $tmp =~ s/ct/c\*/g;
	  $tmp = join("\t", arrange(split("\t", $tmp)));
	  $TorsionAuto{$tmp} = join("\t", @k, $indexn) if (!$nauto{$tmp});
	  ++$nauto{$tmp};
	}
      } else {
	@arg = split("\t", $Torsion{$key});
	$TorsionDouble{$indexn} = join("\t", $key, @k, $indexn);
	for ($i=($n==1 ? 0 : 1); $i<2; ++$i) {		# include first occur
	  my $id = $i ? $indexn : (split("\t", $Torsion{$key}))[-1];
	  debug("double\t$indexn\t$key\t$id\n");
	  push(@doubles, join("\t", $key, $id, $TorsionComment{$id}));
	  $TorsionDouble{@arg[-1]} = join("\t", $key, @arg) if (!$i);
	  my $ti = $TorsionDoubleIndex{int($id)};
	  $TorsionDoubleIndex{int($id)} = $ti eq "" ? 
	      $id : join("\t", split("\t", $ti), $id);
	}
	++$NTorsionDoubles;
      }
      ++$ntorsion{$key};
    }
  }
  print("\n") if ($Debug);
  print_doubles("TORSION DOUBLES", @doubles);
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


sub set_rules {
  foreach (sort(keys(%Rules))) {
    my @arg = split("\t", $Index{$Index{$_} eq "" ? int($_) : $_});
    $Rules{$_} = join("\t", @arg[3], $Rules{$_}, @arg[3, 1, 0, 4]);
  }
}


sub set_extras {
  my @arg, @extra, %torsion, %torsion_double, %offset, $key;
  my $index, $basis, $type, $charge, $itorsion;
  my $id, $type, $dummy, $sigma, $epsilon, $comment;
  my $ntd = $NTorsionDoubles;

  debug("EXTRAS:\n");
  debug("\n");

  %torsion = ();						# transfer
  foreach (keys(%Torsion)) {
    $torsion{$_} = $Torsion{$_} if (defined($Torsion{$_}));
  }

  foreach (sort(keys(%Extras))) {
    debug("$_");
    @extra = split("\t", $Extras{$_});
    ($index, $basis, $type, $charge) = splice(@extra, 0, 4);
    if ($Rules{$index} eq "") {
      error("no rule exists for extra index $index\n");
    }
    if (!defined($Masses{$type})) {				# masses
      @arg = split("\t", $Masses{$basis});
      @arg[0] = $type;
      $Masses{$type} = join("\t", @arg);
      $Element{$type} = $Element{$basis};
    }
    elsif (!defined($Element{$type})) {
      $Element{$type} = $Element{$basis};
    }
    if (!defined($Equivalence{$type})) {			# equivalence
      @arg = split("\t", $EquivalenceAuto{$basis});
      @arg[0] = $type;
      $EquivalenceAuto{$type} = join("\t", @arg);
      @arg = split("\t", $EquivalenceAuto{$basis});
      @arg[0,4] = ($type, $type);
      $Equivalence{$type} = join("\t", @arg);
    }
    @arg = split("\t", $Index{int($index)});			# index
    $charge = @arg[4] if ($charge eq "" || $charge eq "-");
    @arg[3,4] = ($type, $charge);
    $Index{$index} = join("\t", @arg);
    $Type{$type} = 1;
    foreach (@extra) {						# torsions
      ($itorsion, $id) = split(":");
      print("\t$_") if ($Debug);
      foreach (split("\t", $TorsionIndex{int($itorsion)})) {	# update index
	next if (($key = $TorsionKey{$_}) eq "");
	@arg = split("\t", $key);
	foreach (@arg[0,1,2,3]) {
	  $_ = $type if ($_ eq $basis);
	}
	$torsion{join("\t", @arg)} = $Torsion{$key};
	my @a = split("\t", $Torsion{$key});
	#$Torsion{$key} = "";
      }
      if (defined($TorsionDoubleIndex{int($itorsion)})) {
	print("*") if ($Debug);
	foreach (split("\t", $TorsionDoubleIndex{int($itorsion)})) {
	  next if ($id && ($itorsion eq $_));
	  next if ($TorsionDouble{$_} eq "");
	  @arg = split("\t", $TorsionDouble{$_});
	  foreach (@arg[0,1,2,3]) {
	    $_ = $type if ($_ eq $basis);
	  }
	  $TorsionDouble{$_} = join("\t", @arg);
	  $torsion_double{@arg[-1]} = 1;
	}
      }
      next if (!$id);
      if (defined($TorsionDouble{$itorsion})) {			# set double
	@arg = split("\t", $TorsionDouble{$itorsion});
	foreach (@arg[0,1,2,3]) {
	  if (($_ eq $basis) && (!--$id)) { $_ = $type; last;  }
	}
	error("invalid occurence".
	  " in extra index $index for torsion $itorsion\n") if ($id);
	$TorsionDouble{$itorsion} = join("\t", @arg);
	$torsion_double{@arg[-1]} = 1;
      }
    }
    print("\n") if ($Debug);
  }
  print("\n") if ($Debug);

  foreach (keys(%torsion_double)) {				# transcribe
    @arg = split("\t", $TorsionDouble{$_});
    @arg[0,1,2,3] = arrange(@arg[0,1,2,3]);
    my $key = join("\t", splice(@arg, 0, 4));
    $torsion{$key} = join("\t", @arg);
    delete $TorsionDouble{$_};
    --$NTorsionDoubles;
  }

  my @last;							# prune doubles
  my @arg;
  my @doubles;
  my $index;
  my $start;
  my @keys = sort(values(%TorsionDouble));
  my $n = scalar(@keys);

  debug("PRUNING:\n");
  debug("\n");
  for ($index = $start = 0; $index<=scalar(@keys); ++$index) {
    @last = @arg;
    print("\n") if ($Debug && $index>1);
    debug(join("\t", @last[-1,0,1,2,3])) if ($index);
    if ($index<$n) {
      @arg = split("\t", @keys[$index]);
      next if (!$index);
      next if (join("\t", @arg[0,1,2,3]) eq join("\t", @last[0,1,2,3]));
    }
    if ($index-$start==1) {
      print("\ttransfer") if ($Debug);
      my @arg = @last;
      my $key =  join("\t", splice(@arg, 0, 4));
      $torsion{$key} = join("\t", @arg);
      delete $TorsionDouble{(split("\t", @keys[$start]))[-1]};
    } else {
      my $i; for ($i=$start; $i<$index; ++$i) {
	@arg = split("\t", @keys[$i]);
	push(@doubles, join("\t", @arg[0,1,2,3,-1], $TorsionComment{@arg[-1]}));
      }
    }
    $start = $index;
  }
  print("\n\n") if ($Debug);

  debug("OVERRIDE:\n");						# override
  debug("\n");
  foreach (sort(keys(%TorsionExtra))) {
    my $key = $_;
    my @arg = split("\t", $TorsionExtra{$_});
    my $index = join("\.", split(":", @arg[-1]));
    if (defined($TorsionIndexN{$index}) || scalar(@arg)==1) {
      if (!defined($TorsionIndexN{$index})) {
	warning("torsion index $index does not exist\n");
	$torsion{$key} = join("\t", (0, 1, 0, $index));
	next;
      }
      @arg = split("\t", $TorsionIndexN{$index});
      my $ikey = join("\t", splice(@arg, 0, 4));
      if (0 && $key ne $ikey) {
	my $k1 = join(":", split("\t", $key));
	my $k2 = join(":", split("\t", $ikey));
	warning("different keys: $k2 -> $k1\n");
      }
      debug("$key\t->\t$index\n");
      $torsion{$key} = join("\t", @arg, $index);
    }
  }
  print("\n") if ($Debug);

  print_doubles("REMAINING TORSION DOUBLES", @doubles) if ($NTorsionDoubles);
  
  %Torsion = %torsion;
  
  if ($NBondDoubles) {						# reporting
    warning("bond doubles exist\n");
  }
  if ($NAngleDoubles) {
    warning("angle doubles exist\n");
  }
  if ($NTorsionDoubles) {
    my $message = $ntd==$NTorsionDoubles ? 
	"($ntd in total)" : "(reduced from $ntd to $NTorsionDoubles)";
    warning("torsion doubles exist $message\n");
  }
}


sub put_header {
  my $file = shift(@_);
  my $text = shift(@_);
  my $definition = shift(@_);

  printf($file "#
#  OPLS $text using $ParameterName, $BondedName, and $DefineName
#  converted by $script $version, $date by $author
#  to be used in conjuction with EMC v9.3.5 or higher
#\n");

  return if (!$definition);
  printf($file "\n# Force field definition\n\n");
  printf($file "ITEM\tDEFINE\n\n");
  printf($file "FFMODE\t\t".
    ($FFMode eq "" ? "OPLS" : $FFMode)."\n");
  printf($file "FFTYPE\t\t".($OPLSUA ? "UNITED" : "ATOMISTIC")."\n");
  printf($file "FFDEPTH\t\t$FFDepth\n");
  printf($file "FFCHARGE\t$FFCharge\n");
  printf($file "VERSION\t\t".$Version."\n");
  printf($file "CREATED\t\t".`date +"%b %Y"`);
  printf($file "LENGTH\t\tANGSTROM\n");
  printf($file "ENERGY\t\tKCAL/MOL\n");
  printf($file "DENSITY\t\tG/CC\n");
  printf($file "MIX\t\tGEOMETRIC\n");
  printf($file "NBONDED\t\t3\n");
  printf($file "ANGLE\t\tERROR\n");
  printf($file "PAIR14\t\tINCLUDE\n");
  printf($file "TORSION\t\tERROR\n");
  printf($file "SHAKE\t\t$FFShake\n");
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
    my $type = redefine(shift(@arg));
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
  foreach(sort {
    lc($a) lt lc($b) ? -1 : 
    lc($a) gt lc($b) ? 1 :
    $a lt $b ? -1 : 
    $a gt $b ? 1 : 0} values(%Rules)) {
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
  printf($OUT_TOPOL "# id\tindex\ttype\tcomment\n\n");
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
    $Comments[$arg[0]] = join("\t", @arg[3], $comment);
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
  printf($OUT_TOPOL "\nITEM\tEND\n");
}


sub header {
  message("OPLS conversion $version, $date, (c) $author\n\n");
}

sub help {
  $Message = 1;
  header();
  message("Usage:\n  $script [-option[=value]] project\n");
  message("\nOptions:\n");
  message("  -aa\t\tAll-atom output\n");
  message("  -ua\t\tUnited-atom output\n");
  message("  -source\tProvide alternate input.[par|sb] name [$SourceName]\n");
  message("  -literature\tShow literature references\n");
  message("  -doubles\tShow occurence of double entries\n");
  message("  -info\t\tTurn messages and info on\n");
  message("  -debug\tTurn debugging information on\n");
  message("  -quiet\tTurn all output off\n");
  message("\nNotes:\n");
  message("  * Assumes existing input files: project.par, project.sb, project.define\n");
  message("  * Creates output: output.prm, output.top\n");
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
      if ($arg[0] eq "-ua") { $OPLSUA = 1; }
      elsif ($arg[0] eq "-aa") { $OPLSUA = 0; }
      elsif ($arg[0] eq "-debug") { $Debug = 1; }
      elsif ($arg[0] eq "-info") { $Message = 1; }
      elsif ($arg[0] eq "-quiet") { $Message = $Debug = 0; }
      elsif ($arg[0] eq "-source") { $SourceName = $arg[1]; }
      elsif ($arg[0] eq "-literature") { $Literature = 1; }
      elsif ($arg[0] eq "-doubles") { $Doubles = 1; }
      else { help(); }
      next;
    }
    push(@names, $_);
  }
  help() if (scalar(@names)!=1);
  $SourceName = $names[0] if ($SourceName eq "");
  $ParameterName = $SourceName.".par";
  $BondedName = $SourceName.".sb";
  $DefineName = $names[0].".define" if ($DefineName eq "");
  $CreatedParameterName = $names[0].".prm";
  $CreatedTopologyName = $names[0].".top";
}


# main

  init(@ARGV);

  header();
  open_all();
  get_define();
  get_pairs();
  get_bond_angle();
  get_torsion_improper();

  set_equivalences();
  set_extras();
  set_precedences();
  set_rules();

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


