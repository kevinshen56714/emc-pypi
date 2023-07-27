#!/usr/bin/env perl
#
#  program:	emc_generate.pl
#  author:	Pieter J. in 't Veld
#  date:	April 15, 2020.
#  purpose:	Generate dihedral and improper lists based on PSF	
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20200415	Inception
#

use Cwd;
use Data::Dumper;	# print(Dumper($var)); $var represents a pointer
use File::Basename;
use File::Path;

use strict;

# general constants

$::EMCGenerate::OSType = $^O;

$::EMCGenerate::Year = "2020";
$::EMCGenerate::Copyright = "2004-$::EMCGenerate::Year";
$::EMCGenerate::Version = "0.1beta";
$::EMCGenerate::Date = "April 15, $::EMCGenerate::Year";
{
  my $emc = dirname($0)."/emc.sh";
  $::EMCGenerate::EMCVersion = (
    split("\n", (-e $emc ? `$emc -version` : "9.4.4")))[0];
}
{
  my @arg = split("/", $0);
  @arg = (split("/", $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  $::EMCGenerate::Script = @arg[-1];
  if (defined($ENV{EMC_ROOT})) {
    $::EMCGenerate::Root = $ENV{EMC_ROOT};
    $::EMCGenerate::Root =~ s/~/$ENV{HOME}/g;
  } else {
    pop(@arg); pop(@arg);
    pop(@arg) if (@arg[-1] eq "");
    $::EMCGenerate::Root = join("/", @arg);
  }
}
$::EMCGenerate::pi = 3.14159265358979323846264338327950288;

# defaults

$::EMCGenerate::Columns = 80;

%::EMCGenerate::Field = (
  dpd		=> {auto => 0, bond => 0},
  flag		=> 0,
  "format"	=> "%15.10e",
  id		=> "prot",
  name		=> "charmm/c36a/prot",
  type		=> "charmm",
  location	=> scrub_dir("$::EMCGenerate::Root/field/"),
  write		=> 1
);

@::EMCGenerate::FieldIndex = (
  "pair", "incr", "bond", "angle", "torsion", "improper"
);

%::EMCGenerate::FieldList = (
  id		=> {$::EMCGenerate::Field{name} => $::EMCGenerate::Field{id}},
  name		=> [$::EMCGenerate::Field{name}],
  location	=> [$::EMCGenerate::Field{location}]
);

@::EMCGenerate::PSFIndex = (
  "seg_id", "frag", "res_id", "atom_id", "type", "charge", "mass"
);

%::EMCGenerate::Script = (
  extension	=> ".psf",
  name		=> "default"
);

# commands

%::EMCGenerate::Commands = (
  field		=> {
    comment	=> "set force field type and name based on root location",
    default	=> ""
  },
  field_location => {
    comment	=> "set force field location",
    default	=> $::EMCGenerate::Field{location}
  },
  field_name	=> {
    comment	=> "set force field name",
    default	=> $::EMCGenerate::Field{name}
  }
);

@::EMCGenerate::Notes = (
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
  my $sep = $::EMCGenerate::OSType eq "MSWin32" ? "\\" : "/";
  return dirname(@_).$sep.basename(@_);
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


# force field loads

sub update_fields {
  my $option = shift(@_);
  my $i = 0;
  my $id = $::EMCGenerate::Field{id};
  my @locations; 
  my %location;
  my @names;
  my %ids;

  %::EMCGenerate::Fields = () if ($option eq "reset");
  $::EMCGenerate::Fields{$id} = {%::EMCGenerate::Field} if ($option ne "list");
  foreach (sort(keys(%::EMCGenerate::Fields))) {
    my $ptr = $::EMCGenerate::Fields{$_};
    push(@names, $ptr->{name});
    $ids{$ptr->{name}} = $_;
    if (defined($location{$ptr->{location}})) {
      $ptr->{ilocation} = $location{$ptr->{location}};
    } else {
      $location{$ptr->{location}} = $ptr->{ilocation} = $i++;
      push(@locations, $ptr->{location});
    }
  }
  #return if ($option ne "list");
  $::EMCGenerate::FieldList{location} = [@locations];
  $::EMCGenerate::FieldList{name} = [sort(@names)];
  $::EMCGenerate::FieldList{id} = {%ids};

}


sub update_field {
  my $flag = 0;

  foreach (@::EMCGenerate::Fields) {
    next if ($_->{id} ne $::EMCGenerate::Field{id});
    $_->{@_[0]} = @_[1];
    $flag = 1;
  }
  $::EMCGenerate::Field{@_[0]} = @_[1];
  return $flag;
}


sub scrub_dir {
  my @arg;
  my $first = substr(@_[0], 0, 1) eq "/" ? "/" : "";

  foreach (split("/", @_[0])) {
    push(@arg, $_) if ($_ ne "");
  }
  return $first.join("/", @arg);
}


sub set_field {
  my $line = shift(@_);
  my $warning = shift(@_);
  my @string = @_;
  my @extension = ("frc", "prm", "field");
  my $last_type;
  my @names;
  my %flag;

  foreach (@string) {
    my @arg = split(":");
    my $string = @arg[0];
    my $style = @arg[1];
    my $index = index($string, "-");
    my $name = "";
    my %result;

    $index = index($string, "/") if ($index<0);
    my $field = $index>0 ? substr($string, 0, $index) : $string;

    foreach (".", @{$::EMCGenerate::FieldList{location}}) {
      my $ext;
      my $root = scrub_dir("$::EMCGenerate::Root/field/");
      my $split = $root;
      if (substr($_,0,6) eq "\$root+") {
	my $tmp = scrub_dir("$split/$field");
	$root = $tmp if (-d $tmp);
      } else {
	my $tmp = $split = scrub_dir($_);
	$root = $tmp if (-d $tmp);
      }
      $split .= "/" if (length($split));
      my %styles = {};

      if ($style ne "" && !defined($styles{$style})) {
	error_line($line, "illegal field style '$style'\n");
      }

      my $add = $index>0 ? substr($string, $index) : "";
      my %type = ("prm" => $field, "frc" => "cff", "field" => "get");
      my %convert = (basf => "cff", pcff => "cff", compass => "cff");
      my $offset = scalar(split("/", $root.$add));

      $root =~ s/~/$ENV{HOME}/g;

      if (-d "$root") {
	foreach ("/$field", "") {
	  my $dir = "$root$_";
	  next if (! -d "$dir");
	  foreach (@extension) {
	    $ext = $_;
	    foreach (split("\n", `find $dir/* -name '*.$ext'`)) {
	      next if (m/\/src\//);
	      my $index = index($_, $field.$add); 
	      next if ($index<0);
	      $field = field_type($name = $_, $add);
	      last;
	    }
	    last if ($name ne "");
	  }
	  last if ($name ne "");
	}
	if ($name eq "") {
	  foreach (@extension) {
	    $ext = $_;
	    foreach (split("\n", `find $root/* -name '*$field*.$ext'`)) {
	      next if (m/\/src\//);
	      $name = $_; last;
	    }
	    last if ($name ne "");
	  }
	}
	if ($name ne "") {
	  $result{type} = defined($convert{$field}) ? $convert{$field} : $field;
	  $result{name} = (split("\.$ext", (split($split, $name))[-1]))[0];
	  $result{location} = $split;
	  last;
	}
      }
    }
    if ($name eq "") {
      push(@{$warning},"field '$string' not found; no changes"); }
    else {
      if ($last_type ne "" && $last_type ne $result{type}) {
	error_line($line, 
	  "unsupported merging of field types $last_type and $result{type}\n");}
      $::EMCGenerate::Field{flag} = 1;
      $::EMCGenerate::Field{id} = $string;
      $::EMCGenerate::Field{name} = $result{name};
      $::EMCGenerate::Field{location} = $result{location};
      $::EMCGenerate::Field{type} = $last_type = $result{type};
      update_fields();
    }
  }
}


# initialization

sub version {
  print("EMC setup wrapper, v$::EMCGenerate::Version, $::EMCGenerate::Date\n");
  print("Copyright (c) $::EMCGenerate::Copyright Pieter J. in 't Veld\n");
  exit();
}

sub header {
  print("EMC Setup v$::EMCGenerate::Version ($::EMCGenerate::Date), ");
  print("(c) $::EMCGenerate::Copyright Pieter J. in 't Veld\n\n");
}


sub help {
  my $n;
  my $key;
  my $format;
  my $columns;
  my $offset = 3;

  header();
  #set_variables();
  #set_commands();
  $columns = $::EMCGenerate::Columns-3;
  foreach (keys %::EMCGenerate::Commands) {
    $n = length($_) if (length($_)>$n); }
  $format = "%-$n.".$n."s";
  $offset += $n;

  print("Usage:\n  $::EMCGenerate::Script ");
  print("[-command[=#[,..]]] project\n\n");
  print("Commands:\n");
  foreach $key (sort(keys %::EMCGenerate::Commands)) {
    printf("  -$format", $key);
    $n = $offset;
    foreach (split(" ", ${$::EMCGenerate::Commands{$key}}{comment})) {
      if (($n += length($_)+1)>$columns) {
	printf("\n   $format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    if (${$::EMCGenerate::Commands{$key}}{default} ne "") {
      foreach (split(" ", "[${$::EMCGenerate::Commands{$key}}{default}]")) {
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
  foreach (@::EMCGenerate::Notes) { 
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
      defined($::EMCGenerate::FieldFlags{$_}) ? 0 :
      my_eval($_));
  }
  my $n = scalar(@string);

  if (!defined($::EMCGenerate::Commands{@arg[0]})) { return 1; }

  # F

  elsif ($arg[0] eq "field") { set_field($line, $warning, @string); }
  elsif ($arg[0] eq "field_location" ) { 
    $::EMCGenerate::FieldList{location} =
      [list_unique($line, @string, @{$::EMCGenerate::FieldList{location}})];
    update_field("location", $string[-1]); }
  elsif ($arg[0] eq "field_name" ) {
    $::EMCGenerate::FieldList{name} =
      [list_unique($line, @{$::EMCGenerate::FieldList{name}}, @string)];
    update_field("name", $string[-1]);
  }
  else { return 1; }
  return 0;
}


sub initialize {
  my ($name, $psf, @warning);
  my $ext = $::EMCGenerate::Script{extension};

  help() if (!scalar(@ARGV));
  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") { 
      help() if (options(-1, \@warning, $_));
      my @a = split("=");
      $psf = $::EMCGenerate::Script{name} if (@a[0] eq "-psf");
    }
    elsif ($name eq "") { 
      my @a = split("\\.", basename($_)); 
      $::EMCGenerate::Script{extension} = $ext = ".@a[-1]" if (scalar(@a)>1);
      $psf = my_strip($_, $ext); 
      $::EMCGenerate::Project{name} = $name = basename($_, $ext);
      $::EMCGenerate::Project{directory} = $name = dirname($_);
    }
  }
}


# PSF interpretation

sub read_psf_atoms {
  my $data = shift(@_);
  my $line = shift(@_);
  my $n = shift(@_);
  my $hash = shift(@_);
  my $id = shift(@_);
  my @index = @::EMCGenerate::PSFIndex;
  my $last_frag = 0;
  my $frag = 0;

  while ($$line<scalar(@{$data})) {
    my @arg = split(" ", $data->[$$line++]); last if (!scalar(@arg));
    my $index = shift(@arg);
    my $ptr = $hash->{$id}->{$index} = {};
    foreach (@index) { 
      my $value = shift(@arg);
      if ($_ eq "frag") {
	++$frag if ($value ne $last_frag);
	$last_frag = $value;
	$value = $frag;
      }
      $ptr->{$_} = sprintf($_ eq "charge" ? "%.5g" : "%s", $value); 
    }
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
  my $directory = $::EMCGenerate::Project{directory};
  my $name = $::EMCGenerate::Project{name};
  my $stream = fopen("$directory/$name.psf", "r");
  my $line = 0;
  my %hash;
  my @data;

  foreach (<$stream>) { chop(); push(@data, $_); }
  close($stream);
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


# import field

sub read_field_equivalence {
  my $data = shift(@_);
  my $line = shift(@_);
  my $hash = shift(@_);
  my $item = shift(@_);
  my @index = @::EMCGenerate::FieldIndex;

  $hash->{$item} = {} if (!defined($hash->{$item}));
  while ($$line<scalar(@{$data})) {
    my @arg = split(" ", $data->[$$line++]);
    next if (!scalar(@arg));
    next if (substr(@arg[0],0,1) eq "#");
    last if (@arg[0] eq "ITEM" && @arg[1] eq "END");
    my $type = shift(@arg);
    my $ptr = $hash->{$item};
    foreach (@index) { $ptr->{$_}->{$type} = shift(@arg); }
  }
}


sub read_field_bonded {
  my $data = shift(@_);
  my $line = shift(@_);
  my $hash = shift(@_);
  my $item = shift(@_);
  my @index = @::EMCGenerate::FieldIndex;
  my %ns = (bond => 2, angle => 3, torsion => 4, improper => 4, cmap => 8);
  my $ntypes = $ns{$item};

  $hash->{$item} = {} if (!defined($hash->{$item}));
  while ($$line<scalar(@{$data})) {
    my @arg = split(" ", $data->[$$line++]);
    next if (!scalar(@arg));
    next if (substr(@arg[0],0,1) eq "#");
    last if (@arg[0] eq "ITEM" && @arg[1] eq "END");
    my $key = join("\t", splice(@arg,0,$ntypes));
    $hash->{$item}->{$key} = [@arg];
  }
}


sub read_field {
  my $name = $::EMCGenerate::Field{name};
  my $location = $::EMCGenerate::Field{location};
  my $stream = fopen("$location/$name.prm", "r");
  my %allowed = (equivalence => 1, improper => 2);
  my $read = 0;
  my $line = 0;
  my @data = ();
  my %hash = ();
  
  foreach (<$stream>) { chop; push(@data, $_); }
  close($stream);
  
  foreach (@data) {
    ++$line;
    my @arg = split(" ");
    next if (!scalar(@arg));
    next if (substr(@arg[0],0,1) eq "#");
    next if (@arg[0] ne "ITEM");
    my $item = lc(@arg[1]);
    if ($item eq "equivalence") {
      read_field_equivalence(\@data, \$line, \%hash, $item); }
    elsif ($item eq "improper") {
      read_field_bonded(\@data, \$line, \%hash, $item); }
  }
  return %hash;
}


# output

sub print_atoms {
  my @ptr = (shift(@_));
  my @index = @::EMCGenerate::PSFIndex;

  tprint("", "index", @index);
  foreach (sort({$a<=>$b} keys(%{@ptr[0]}))) {
    my @arg;
    @ptr[1] = @ptr[0]->{$_};
    foreach (@index) { push(@arg, @ptr[1]->{$_}); }
    tprint("ATOM", $_, @arg);
  }
}


sub print_equivalence {
  my $ptr = shift(@_);
  my @index = @::EMCGenerate::FieldIndex;
  my @ptr;

  tprint("", "type", @index);
  foreach (@index) { push(@ptr, $ptr->{$_}); }
  foreach (sort(keys(%{@ptr[0]}))) {
    my @arg;
    my $type = $_;
    foreach (@ptr) {
      push(@arg, $_->{$type});
    }
    tprint("TYPE", $type, @arg);
  }
}


sub compare {
  return
    @_[0] lt @_[-1] ? -1 :
    @_[0] gt @_[-1] ? 1 :
    scalar(@_)<4 ? 0 :
    @_[1] lt @_[-2] ? -1 :
    @_[1] gt @_[-2] ? 1 : 0;
}


# collections

sub print_bonded {
  my $PSF = shift(@_);
  my $FIELD = shift(@_);
  my $item = shift(@_);
  my $atoms = $PSF->{atom};
  my $check = $item ne "improper";
  my $eqv = $item eq "cmap" ? "torsion" : $item;

  my @output;
  foreach (@{$PSF->{$item}}) {
    my @arg = @{$_};
    my $equi = $FIELD->{equivalence};
    
    my @ids;
    my @types;
    foreach (@{$_}) {
      push(@ids, $atoms->{$_}->{atom_id});
      push(@types, $equi->{$eqv}->{$atoms->{$_}->{type}});
    }
    if ($check) {
      my $cmp = compare(@types);
      $cmp = compare(@ids) if (!$cmp);
      if ($cmp>0) {
	@arg = reverse(@arg);
	@ids = reverse(@ids);
	@types = reverse(@types);
      }
    }
    my $residue = $atoms->{@arg[0]}->{res_id};
    my $fragment = $atoms->{@arg[0]}->{frag};
    if (scalar(@ids)*2<=8) {
      push(@output,
	join("\t", sprintf("%7.7s", $fragment), $residue, @ids, @types));
    } else {
      push(@output,
	join("\t", sprintf("%7.7s", $fragment), $residue, @ids)."\n".
	join("\t", "", "", @types));
    }
  }

  tprint(uc($item."s"), scalar(@output));
  tprint();
  foreach (sort(@output)) { print("$_\n"); }
  tprint();
}


# main

{
  initialize();

  my %PSF = read_psf();
  my %FIELD = read_field();

  #print_atoms($PSF{atoms});
  #print_equivalence($FIELD{equivalence});

  foreach ("bond", "angle", "torsion", "improper", "cmap") {
    print_bonded(\%PSF, \%FIELD, $_);
  }
}

