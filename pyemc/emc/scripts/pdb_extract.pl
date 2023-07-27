#!/usr/bin/env perl
#
#  program:	generate.pl
#  author:	Pieter J. in 't Veld
#  date:	May 10, 2020.
#  purpose:	Extract segname from PDB and PSF	
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20200510	Inception
#

use Cwd;
use Data::Dumper;	# print(Dumper($var)); $var represents a pointer
use File::Basename;
use File::Path;

use strict;


# general constants

$::PDBExtract::OSType = $^O;

$::PDBExtract::Year = "2020";
$::PDBExtract::Copyright = "2004-$::PDBExtract::Year";
$::PDBExtract::Version = "0.1beta";
$::PDBExtract::Date = "May 10, $::PDBExtract::Year";
{
  my $emc = dirname($0)."/emc.sh";
  $::PDBExtract::EMCVersion = (
    split("\n", (-e $emc ? `$emc -version` : "9.4.4")))[0];
}
{
  my @arg = split("/", $0);
  @arg = (split("/", $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  $::PDBExtract::Script = @arg[-1];
  if (defined($ENV{EMC_ROOT})) {
    $::PDBExtract::Root = $ENV{EMC_ROOT};
    $::PDBExtract::Root =~ s/~/$ENV{HOME}/g;
  } else {
    pop(@arg); pop(@arg);
    pop(@arg) if (@arg[-1] eq "");
    $::PDBExtract::Root = join("/", @arg);
  }
}
$::PDBExtract::pi = 3.14159265358979323846264338327950288;

# defaults

$::PDBExtract::Columns = 80;

%::PDBExtract::Field = (
  dpd		=> {auto => 0, bond => 0},
  flag		=> 0,
  "format"	=> "%15.10e",
  id		=> "prot",
  name		=> "charmm/c36a/prot",
  type		=> "charmm",
  location	=> scrub_dir("$::PDBExtract::Root/field/"),
  write		=> 1
);

@::PDBExtract::FieldIndex = (
  "pair", "incr", "bond", "angle", "torsion", "improper"
);

%::PDBExtract::FieldList = (
  id		=> {$::PDBExtract::Field{name} => $::PDBExtract::Field{id}},
  name		=> [$::PDBExtract::Field{name}],
  location	=> [$::PDBExtract::Field{location}]
);

@::PDBExtract::PSFIndex = (
  ["atom_id", 10, 0],
  ["seg_name", 8, 1], 
  ["frag", 8, 1], 
  ["res_name", 8, 1],
  ["atom_name", 8, 1],
  ["type", 7, 1],
  ["charge", 9, 0],
  ["mass", 13, 0],
  ["last", 11, 0]
);

@::PDBExtract::PDBIndex = (
  ["ident", 0, 6, 1],
  ["atom_id", 6, 5, 0],
  ["atom_name", 11, 5, 0],
  ["loc_id", 16, 1, 0],
  ["res_name", 17, 4, 1],
  ["chain_id", 21, 1, 0],
  ["res_id", 22, 4, 0],
  ["code", 26, 1, 0],
  ["empty", 27, 3, 0],
  ["p_x", 30, 8, 0],
  ["p_y", 38, 8, 0],
  ["p_z", 46, 8, 0],
  ["occupancy", 54, 6, 0],
  ["temp_factor", 60, 6, 0],
  ["empty", 66, 6, 0],
  ["seg_name", 72, 4, 1],
  ["element", 76, 2, 0],
  ["charge", 78, 2, 0]
);

%::PDBExtract::Script = (
  extension	=> ".pdb",
  name		=> "default"
);

# commands

%::PDBExtract::Commands = (
  atom		=> {
    comment	=> "set atom id bounds",
    default	=> ""
  },
  residue	=> {
    comment	=> "set residue id bounds",
    default	=> ""
  },
  segment	=> {
    comment	=> "set segments",
    default	=> ""
  }
);

@::PDBExtract::Notes = (
  "Fields are expected in either EMC or local locations"
);

# general functions

sub info {
  printf("Info: ".shift(@_), @_) if ($::Foam::Flag{info});
}


sub debug {
  printf("Debug: ".shift(@_), @_) if ($::Foam::Flag{debug});
}


sub tdebug {
  print(join("\t", "Debug:", @_), "\n") if ($::Foam::Flag{debug});
}


sub warning {
  printf("Warning: ".shift(@_), @_) if ($::Foam::Flag{warn});
}


sub error {
  printf("Error: ".shift(@_), @_);
  printf("\n");
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


sub tprint {
  print(join("\t", @_), "\n");
}


# i/o routines

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


sub my_warn {
  my ( $file, $line ) = ( caller )[1,2];
  $file = scalar reverse(reverse($file) =~ m{^(.*?)[\\/]});
  warn ("$file:$line ", @_);
}


sub my_strip {
  my $sep = $::PDBExtract::OSType eq "MSWin32" ? "\\" : "/";
  return dirname(@_).$sep.basename(@_);
}


sub scrub_dir {
  my @arg;
  my $first = substr(@_[0], 0, 1) eq "/" ? "/" : "";

  foreach (split("/", @_[0])) {
    push(@arg, $_) if ($_ ne "");
  }
  return $first.join("/", @arg);
}


# list management

sub list_unique {
  my $line = shift(@_);
  my %check = ();
  my @list;

  foreach (@_) {
    if (defined($check{$_})) {
      warning(
	"omitting reoccurring entry '$_' in line $line of input.\n") if ($line);
      next;
    }
    push(@list, $_);
    $check{$_} = 1;
  }
  return @list;
}


sub trim {
  my $s = shift(@_);
  $s =~ s/^\s+|\s+$//g;
  return $s;
}


# initialization

sub version {
  print("PDB Extract, v$::PDBExtract::Version, $::PDBExtract::Date\n");
  print("Copyright (c) $::PDBExtract::Copyright Pieter J. in 't Veld\n");
  exit();
}

sub header {
  print("PDB Extract v$::PDBExtract::Version ($::PDBExtract::Date), ");
  print("(c) $::PDBExtract::Copyright Pieter J. in 't Veld\n\n");
}


sub help {
  my $n;
  my $key;
  my $format;
  my $columns;
  my $offset = 3;

  header();
  $columns = $::PDBExtract::Columns-3;
  foreach (keys %::PDBExtract::Commands) {
    $n = length($_) if (length($_)>$n); }
  $n += 4-$n%4;
  $format = "%-$n.".$n."s";
  $offset += $n;

  print("Usage:\n  $::PDBExtract::Script ");
  print("[-command[=#[,..]]] project output\n\n");
  print("Commands:\n");
  foreach $key (sort(keys %::PDBExtract::Commands)) {
    printf("  -$format", $key);
    $n = $offset;
    foreach (split(" ", ${$::PDBExtract::Commands{$key}}{comment})) {
      if (($n += length($_)+1)>$columns) {
	printf("\n   $format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    if (${$::PDBExtract::Commands{$key}}{default} ne "") {
      foreach (split(" ", "[${$::PDBExtract::Commands{$key}}{default}]")) {
	if (($n += length($_)+1)>$columns) {
	  printf("\n   $format", ""); $n = $offset+length($_)+1; }
	print(" $_");
      }
    }
    print("\n");
  }

  printf("\nNotes:\n");
  $offset = $n = 3;
  $format = "%$n.".$n."s";
  foreach (@::PDBExtract::Notes) { 
    $n = $offset;
    printf($format, "*");
    foreach (split(" ")) {
      if (($n += length($_)+1)>$columns) {
	printf("\n$format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    print("\n");
  }
  printf("\n");
  exit(-1);
}


sub set_select_range {
  my $line = shift(@_);
  my $id = shift(@_);
  my @value = @_;

  error_line(
      $line, "incorrect number of $id entries") if (scalar(@value)%2);
  $::PDBExtract::Select{$id} = [] if (!defined($::PDBExtract::Select{$id}));
  while (scalar(@value)) {
    push(@{$::PDBExtract::Select{$id}}, [splice(@value,0,2)]);
  }
}


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


sub options {
  my @value;
  my $line = shift(@_);
  my $warning = shift(@_);
  my @arg = @_;
  @arg = split("=", @arg[0]) if (scalar(@arg)<2);
  @arg[0] = substr(@arg[0],1) if (substr(@arg[0],0,1) eq "-");
  @arg[0] = lc(@arg[0]);
  my @tmp = @arg; shift(@tmp);
  @tmp = split(",", @tmp[0]) if (scalar(@tmp)<2);
  @tmp = split(":", @tmp[0]) if (scalar(@tmp)<2);

  my @string;
  foreach (@tmp) { 
    last if (substr($_,0,1) eq "#");
    push(@string, $_);
    push(@value,
      $_ eq "-" ? 0 :
      substr($_,0,1) eq "/" ? 0 : 
      substr($_,0,1) eq "~" ? 0 :
      defined($::PDBExtract::FieldFlags{$_}) ? 0 :
      my_eval($_));
  }
  my $n = scalar(@string);

  if (!defined($::PDBExtract::Commands{@arg[0]})) { return 1; }
  elsif ($arg[0] eq "atom") { set_select_range($line, "atom", @value); }
  elsif ($arg[0] eq "residue") { set_select_range($line, "residue", @value); }
  elsif ($arg[0] eq "segment") {
    foreach (@string) { $::PDBExtract::Select{segment}->{$_} = 1; }
  }
  else { return 1; }
  return 0;
}


sub initialize {
  my ($input, $output, $psf, @warning);
  my $ext = $::PDBExtract::Script{extension};

  help() if (!scalar(@ARGV));
  set_select_range(0, "atom");
  set_select_range(0, "residue");
  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") { 
      help() if (options(-1, \@warning, $_));
      my @a = split("=");
      $psf = $::PDBExtract::Script{name} if (@a[0] eq "-psf");
    }
    elsif ($input eq "") { 
      my @a = split("\\.", basename($_)); 
      $::PDBExtract::Script{extension} = $ext = ".@a[-1]" if (scalar(@a)>1);
      $psf = my_strip($_, $ext); 
      $::PDBExtract::Project{name} = $input = basename($_, $ext);
      $::PDBExtract::Project{directory} = dirname($_);
    }
    elsif ($output eq "") {
      $::PDBExtract::Project{output} = $output = basename($_, $ext);
    }
  }
  help() if ($output eq "");
}


# PDB interpretation

# PDB read

sub read_pdb_atoms {
  my $data = shift(@_);
  my $line = shift(@_);
  my $hash = shift(@_);
  my $id = shift(@_);
  my @index = @::PDBExtract::PDBIndex;
  my $index = 0;

  $hash->{atom} = [];
  while ($$line<scalar(@{$data})) {
    my %atom;
    my $input = trim($data->[$$line++]); 
    my $id = trim(substr($input, 0, 6));

    if ($id eq "END") { last; }
    elsif ($id eq "CRYST1") { $hash->{geometry} = $input; next; }
    elsif ($id ne "ATOM") { next; }
    foreach (@index) {
      if ($_->[0] ne "atom_id") {
	$atom{$_->[0]} = trim(substr($input, $_->[1], $_->[2]));
      } else {
	$atom{$_->[0]} = ++$index;
      }
    }
    push(@{$hash->{atom}}, {%atom})
  }
}


sub read_pdb {
  my $directory = $::PDBExtract::Project{directory};
  my $name = $::PDBExtract::Project{name};
  my $stream = fopen("$directory/$name.pdb", "r");
  my $line = 0;
  my %hash;
  my @data;

  foreach (<$stream>) { chop(); push(@data, $_); }
  read_pdb_atoms(\@data, \$line, \%hash, "atom");
  close($stream);
  return %hash;
}


# PDB write

sub write_pdb {
  my $hash = shift(@_);
  my $name = $::PDBExtract::Project{output};
  my $stream = fopen($name.".pdb", "w");
  my @index = @::PDBExtract::PDBIndex;
  my $select = $::PDBExtract::Select{id};

  printf($stream "%s\n", $hash->{geometry});
  foreach (@{$hash->{atom}}) {
    my $atom = $_;
    next if (!defined($select->{$atom->{atom_id}}));
    foreach (@index) {
      my $fmt = sprintf("%%%s%s.%ss", $_->[3] ? "-" : "", $_->[2], $_->[2]);
      if ($_->[0] eq "atom_id") {
	printf($stream $fmt, $::PDBExtract::Select{id}->{$atom->{atom_id}});
      } else {
	printf($stream $fmt, $atom->{$_->[0]});
      }
    }
    printf($stream "\n");
  }
  printf($stream "END\n");
  close($stream);
}


# PSF interpretation

# PSF read

sub read_psf_atoms {
  my $data = shift(@_);
  my $line = shift(@_);
  my $n = shift(@_);
  my $hash = shift(@_);
  my $id = shift(@_);
  my @index = @::PDBExtract::PSFIndex;
  my $last_segname = "";
  my $last_frag = 0;
  my $frag = 0;

  $hash->{$id} = [];
  while ($$line<scalar(@{$data})) {
    my @arg = split(" ", $data->[$$line++]); last if (!scalar(@arg));
    my %atom;

    foreach (@index) { 
      my $value = shift(@arg);
      if ($_->[0] eq "seg_name") {
	$frag = 0 if ($value ne $last_segname);
	$last_segname = $value;
      } elsif ($_->[0] eq "frag") {
	++$frag if ($value ne $last_frag);
	$last_frag = $value;
	$value = $frag;
      }
      $atom{$_->[0]} = sprintf($_ eq "charge" ? "%.5g" : "%s", $value); 
    }
    push(@{$hash->{$id}}, {%atom});
  }
}


sub read_psf_bonded {
  my $data = shift(@_);
  my $line = shift(@_);
  my $n = shift(@_);
  my $hash = shift(@_);
  my $id = shift(@_);
  my %ns = (bond => 2, angle => 3, torsion => 4, improper => 4, cmap => 8);
  my $natoms = $ns{$id};
  my $ptr = $hash->{$id} = [];

  return if (!$natoms);
  while ($$line<scalar(@{$data})) {
    my @arg = split(" ", $data->[$$line++]);
    last if (!scalar(@arg));
    while (scalar(@arg)) { push(@{$ptr}, [splice(@arg, 0, $natoms)]); }
  }
}


sub read_psf {
  my $directory = $::PDBExtract::Project{directory};
  my $name = $::PDBExtract::Project{name};
  my $stream = fopen("$directory/$name.psf", "r");
  my $line = 0;
  my %hash;
  my @data;

  foreach (<$stream>) { chop(); push(@data, $_); }
  while ($line<scalar(@data)) {
    my @arg = split(" ", @data[$line++]);
    next if (!scalar(@arg));
    if (@arg[1] eq "!NATOM") { 
      read_psf_atoms(\@data, \$line, @arg[0], \%hash, "atom"); }
    elsif (@arg[1] eq "!NBOND:") { 
      read_psf_bonded(\@data, \$line, @arg[0], \%hash, "bond"); }
    elsif (@arg[1] eq "!NTHETA:") { 
      read_psf_bonded(\@data, \$line, @arg[0], \%hash, "angle"); }
    elsif (@arg[1] eq "!NPHI:") { 
      read_psf_bonded(\@data, \$line, @arg[0], \%hash, "torsion"); }
    elsif (@arg[1] eq "!NIMPHI:") { 
      read_psf_bonded(\@data, \$line, @arg[0], \%hash, "improper"); }
    elsif (@arg[1] eq "!NCRTERM:") { 
      read_psf_bonded(\@data, \$line, @arg[0], \%hash, "cmap"); }
  }
  close($stream);
  return %hash;
}


# PSF write

sub write_psf_atoms {
  my $stream = shift(@_);
  my $hash = shift(@_);
  my $id = shift(@_);
  my $title = shift(@_);
  my @index = @::PDBExtract::PSFIndex;
  my $select = $::PDBExtract::Select{id};
  my $last_segname = "";
  my $last_frag = 0;
  my $frag = 0;
  my $n = 0;

  foreach (@{$hash->{$id}}) {
    ++$n if (defined($select->{$_->{atom_id}}));
  }
  printf($stream "%8.8s %s\n", $n, $title);
  foreach (@{$hash->{$id}}) {
    next if (!defined($select->{$_->{atom_id}}));
    my $atom = $_;
    foreach (@index) {
      my $value = $atom->{$_->[0]};
      my $fmt = "%".($_->[2] ? "-" : "")."$_->[1].$_->[1]s";
      if ($_->[0] eq "atom_id") {
	printf($stream $fmt, $select->{$value});
      } elsif ($_->[0] eq "seg_name") {
	$frag = 0 if ($value ne $last_segname);
	printf($stream " ".$fmt, $last_segname = $value);
      } elsif ($_->[0] eq "frag") {
	++$frag if ($value ne $last_frag);
	$last_frag = $value;
	printf($stream " ".$fmt, $frag);
      } else {
	printf($stream " ".$fmt, $value);
      }
    }
    printf($stream "\n");
  }
  printf($stream "\n");
}


sub write_psf_bonded {
  my $stream = shift(@_);
  my $hash = shift(@_);
  my $id = shift(@_);
  my $title = shift(@_);
  my @index = @::PDBExtract::PSFIndex;
  my $select = $::PDBExtract::Select{id};
  my $last_frag = 0;
  my $frag = 0;
  my $n = 0;

  foreach (@{$hash->{$id}}) {
    my $flag = 1;
    foreach (@{$_}) { $flag &= defined($select->{$_}) ? 1 : 0; }
    ++$n if ($flag);
  }
  printf($stream "%8.8s %s\n", $n, $title);
  $n = 0;
  foreach (@{$hash->{$id}}) {
    my $flag = 1;
    foreach (@{$_}) { $flag &= defined($select->{$_}) ? 1 : 0; }
    next if (!$flag);
    printf($stream "\n") if ($n>=8);
    $n = 0 if ($n>=8);
    foreach (@{$_}) { printf($stream "%10.10s", $select->{$_}); ++$n; }
  }
  printf($stream "\n\n");
}


sub write_psf {
  my $hash = shift(@_);
  my $name = $::PDBExtract::Project{output};
  my $stream = fopen($name.".psf", "w");

  printf($stream "%s\n\n", "PSF EXT CMAP");
  printf($stream "%8.8s %s\n", 2, "!NTITLE");
  printf($stream "%-6.6s %s\n", "REMARK", 
    "created by PDB Extract v$::PDBExtract::Version ($::PDBExtract::Date)");
  printf($stream "%-6.6s %s %s\n", "REMARK", "created on", `date`);

  write_psf_atoms($stream, $hash, "atom", "!NATOM");
  write_psf_bonded($stream, $hash, "bond", "!NBOND: bonds");
  write_psf_bonded($stream, $hash, "angle", "!NTHETA: angles");
  write_psf_bonded($stream, $hash, "torsion", "!NPHI: dihedrals");
  write_psf_bonded($stream, $hash, "improper", "!NIMPHI: impropers");
  write_psf_bonded($stream, $hash, "cmap", "!NCRTERM: cross-terms");

  close($stream);
}


# selection

sub set_select {
  my $pdb = shift(@_);
  my $index = 0;

  undef($::PDBExtract::Select{id});
  foreach (@{$pdb->{atom}}) {
    my $atom = $_;
    my $flag = -1;

    foreach (@{$::PDBExtract::Select{atom}}) {
      $flag = 0; next if ($atom->{atom_id}<$_->[0] || $atom->{atom_id}>$_->[1]);
      $flag = 1; last;
    }
    if ($flag<1) {
      foreach (@{$::PDBExtract::Select{residue}}) {
	$flag = 0; next if ($atom->{res_id}<$_->[0] || $atom->{res_id}>$_->[1]);
	$flag = 1; last;
      }
    }
    if ($flag<1) {
      if (defined($::PDBExtract::Select{segment})) {
	$flag = defined($::PDBExtract::Select{segment}->{$atom->{seg_name}});
      }
    }
    $::PDBExtract::Select{id}->{$atom->{atom_id}} = ++$index if ($flag);
  }
}


# main

{
  initialize();

  my %PSF = read_psf();
  my %PDB = read_pdb();
  
  set_select(\%PDB);
  write_pdb(\%PDB);
  write_psf(\%PSF);
}

