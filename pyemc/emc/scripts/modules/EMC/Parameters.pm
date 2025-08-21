#!/usr/bin/env perl
#
#  module:	EMC::Parameters.pm
#  author:	Pieter J. in 't Veld
#  date:	September 29, 2022.
#  purpose:	Parameters structure routines; part of EMC distribution
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
#        indicator	BOOLEAN	include "parameters_" indicator in commands
#        commands	BOOLEAN	include commands in $root->{options}
#
#  specific members:
#    data		ARRAY of HASH
#      data		ARRAY	values for comma separated input
#      line		VALUE	line number in input file
#      verbatim		STRING	verbatim input line
#
#    name		STRING	input file name
#
#    verbatim		ARRAY of HASH
#      data		ARRAY	values from .esh
#      line		VALUE	line number in input .esh
#      verbatim		STRING	verbatim input
#
#  notes:
#    20220929	Inception of v1.0
#

package EMC::Parameters;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&func);		# export of functions, e.g. func
				# 'sub import' is executed upon 'use EMC::Parameters'
#use vars qw($var %hash);	# available as $EMC::IO::var and %EMC::IO::hash

use EMC::Common;
use EMC::Element;
use EMC::IO;
use EMC::Math;
use EMC::References;
use EMC::Types;


# defaults

$EMC::Parameters::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "September 29, 2022",
  version	=> "1.0"
};


# construct

sub construct {
  my $parameters = EMC::Common::hash(EMC::Common::element(shift(@_)));
  my $attr = EMC::Common::attributes(@_);
  
  set_functions($parameters, $attr);
  set_defaults($parameters);
  set_commands($parameters);
  return $parameters;
}


# initialization

sub set_defaults {
  my $parameters = EMC::Common::hash(shift(@_));
  my $root = ref(@_[0]) eq "HASH" ? shift(@_) : undef;
  my $backwards = EMC::Common::element($root, "global", "flag", "backwards");

  $parameters = EMC::Common::attributes(
    $parameters,
    {
      # B

      bond		=> [],

      # D

      data		=> {},

      # F

      flag		=> 0,

      # N

      name		=> "parameters",
      nonbonds		=> undef,

      # R

      read		=> undef,

      # S

      suffix		=> "_parm",

      # V

      verbatim		=> undef
    }
  );
  $parameters->{identity} = EMC::Common::attributes(
    EMC::Common::hash($parameters, "identity"),
    $EMC::Parameters::Identity
  );
  return $parameters;
}


sub transfer {
  my $parameters = EMC::Common::hash(shift(@_));
  my $flag = EMC::Common::element($parameters, "flag");
  my $context = EMC::Common::element($parameters, "context");
  
  EMC::Element::transfer(shift(@_),
    [\@::EMC::Bonds,			\$parameters->{bond}],
    [\%::EMC::Parameters,		\$parameters],
    [\$::EMC::Parameters{data},		\$parameters->{data}],
    [\$::EMC::Parameters{flag},		\$parameters->{flag}],
    [\$::EMC::Parameters{name},		\$parameters->{name}],
    [\$::EMC::Parameters{read},		\$parameters->{read}],
    [\$::EMC::Parameters{suffix},	\$parameters->{suffix}],
    [\@::EMC::Set,			\$parameters->{nonbonds}],
    [\@::EMC::Temperatures,		\$parameters->{temperature}],
    [\$::EMC::Verbatim{parameters},	\$parameters->{verbatim}],
  );
}


sub set_context {
  my $parameters = EMC::Common::hash(shift(@_));
  my $root = EMC::Common::hash(shift(@_));
  my $global = EMC::Common::element($root, "global");
  my $units = EMC::Common::element($global, "units");
  my $flag = EMC::Common::element($parameters, "flag");
  my $context = EMC::Common::element($parameters, "context");

}


sub set_commands {
  my $parameters = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::element($parameters, "set");
  my $context = EMC::Common::element($parameters, "context");
  my $flag = EMC::Common::element($parameters, "flag");


  EMC::Options::set_command(
    $parameters->{commands} = EMC::Common::attributes(
      EMC::Common::hash($parameters, "commands"),
      {
	# R

	parameters	=> {
	  comment	=> "set parameters file name",
	  default	=> $parameters->{name},
	  gui		=> ["browse", "chemistry", "field", "advanced"]}
      }
    ),
    {
      set		=> \&EMC::Parameters::set_options
    }
  );

  EMC::Options::set_command(
    $parameters->{items} = EMC::Common::attributes(
      EMC::Common::hash($parameters, "items"),
      {
	# N

	nonbonds	=> {
	  set		=> \&set_item_nonbonds
	},

	# P

	parameters	=> {
	  environment	=> 1,
	  set		=> \&set_item_parameters
	}
      }
    ),
    {
      chemistry		=> 1,
      environment	=> 0,
      order		=> 0
    }
  );

  return $parameters;
}


sub set_options {
  my $struct = shift(@_);
  my $option = EMC::Common::element($struct, "option");
  my $args = EMC::Common::element($struct, "args");
  my $file = EMC::Common::element($struct, "file");
  my $line = EMC::Common::element($struct, "line");
  my $parameters = EMC::Common::element($struct, "module");

  # R

  if ($option eq "parameters") {
    return $parameters->{name} = $args->[0]; }
  
  return undef;
}


sub set_functions {
  my $parameters = EMC::Common::hash(shift(@_));
  my $set = EMC::Common::hash($parameters, "set");
  my $attr = EMC::Common::attributes(@_);
  my $flags = {commands => 1, depricated => 0, indicator => 1, items => 1};

  $set->{commands} = \&EMC::Parameters::set_commands;
  $set->{context} = \&EMC::Parameters::set_context;
  $set->{defaults} = \&EMC::Parameters::set_defaults;
  $set->{options} = \&EMC::Parameters::set_options;
  
  foreach (keys(%{$flags})) {
    $set->{flag}->{$_} =
      EMC::Math::flag(defined($attr->{$_}) ? $attr->{$_} : $flags->{$_});
  }
  return $parameters;
}


# set item

sub set_item_nonbonds {
  my $struct = shift(@_);
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return if (EMC::Common::element($options, "comment"));
  
  my $root = EMC::Common::element($struct, "root");
  my $option = EMC::Common::element($struct, "option");
  my $types = EMC::Common::element($struct, "module", "parent");

  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");
  my $i = 0;

  my $cutoff = EMC::Common::element($types, "cutoff");
  my $pair_constants = EMC::Common::element($types, "pair_constants");
  my $nonbonds = EMC::Common::array($types, "parameters", "nonbonds");
  
  foreach (@{$data}) {
    my @arg = @{$_};
    my $line = $lines->[$i++];
    my $n = scalar(@arg);

    if ($n<3) {
      EMC::Message::error_line($line, "incorrect parameter entry\n"); }
    if ($n<4) {
      @arg[3] = $pair_constants->{r}; }
    if ($n<5) {
      @arg[4] = $pair_constants->{gamma}; }

    @arg[0,1] = sort(@arg[0,1]);
    for ($i=2; $i<$n; ++$i) { @arg[$i] = EMC::Math::eval(@arg[$i])->[0]; }

    push(@{$nonbonds}, [@arg[0,1,2,3,4]]);
    $cutoff->{@arg[0]} = @arg[3] if (@arg[0] eq @arg[1]);
  }
  return $root;
}


sub set_item_parameters {
  my $struct = shift(@_);
  my $item = EMC::Common::element($struct, "item");
  my $options = EMC::Hash::arguments(EMC::Common::element($item, "options"));

  return if (EMC::Common::element($options, "comment"));
  
  my $root = EMC::Common::element($struct, "root");
  my $module = EMC::Common::element($struct, "module");
  my $data = EMC::Common::element($item, "data");
  my $lines = EMC::Common::element($item, "lines");

  $module->{verbatim} = {data => $data, line => $lines};

  return $root;
}


# functions

sub read {					# <= read_parameters
  my $parameters = shift(@_);
  my $name = shift(@_);
  my $suffix = shift(@_);

  my $root = EMC::Common::element($parameters, "root");
  my $nonbonds = EMC::Common::element($parameters, "nonbonds");
  my $verbatim = EMC::Common::element($parameters, "verbatim");
  my $pdata = $parameters->{data} = EMC::Common::hash($parameters, "data");
  
  my $types = EMC::Common::element($parameters, "parent");
  my $bond = EMC::Common::element($types, "bond");
  my $cutoff = EMC::Common::element($types, "cutoff");
  my $fields = EMC::Common::element($root, "fields");
  my $field = EMC::Common::element($root, "fields", "field");
  my $inverse = EMC::Common::element($types, "inverse");
  my $mass = EMC::Common::element($types, "mass");
  my $pair_constants = EMC::Common::element($types, "pair_constants");
  my $references = EMC::Common::element($types, "references");
  my $type = EMC::Common::element($types, "type");

  my $global = EMC::Common::element($parameters, "root", "global");
  my $flag = EMC::Common::element($global, "flag");
  my $project = EMC::Common::element($global, "project");

  my $aij0 = $pair_constants->{a};
  my $r0 = $pair_constants->{r};
  my $gamma = $pair_constants->{gamma};
  my $flag_wild = 0;
  my $flag_set = 0;
  my $error = 0;
  my $first = 1;
  my $stream;
  my %sites;
  my $data;

  return if (!$field->{write});
  if (!EMC::IO::exist($name, @{$suffix}) &&
      !$parameters->{read} &&
      !defined($verbatim)) {
    return if (!defined($nonbonds));
    foreach (@{$nonbonds}) {
      my @arg = @{$_};
      foreach (@arg[0,1]) { 
	$cutoff->{$_} = $r0 if (!defined($cutoff->{$_})); }
      next if (@arg[0] ne @arg[1]);
      $cutoff->{@arg[0]} = @arg[3];
    }
    foreach (@{$nonbonds}) {
      my @arg = @{$_};
      next if (scalar(@arg)<2);
      $sites{@arg[0]} = 1 if (length(@arg[0])>0);
      $sites{@arg[1]} = 1 if (length(@arg[1])>0);
      EMC::References::define($references, @arg[0,1]) if (!$references->{flag});
      my $key = join(":", sort(@arg[0,1]));
      $flag_wild = 1 if ($key eq "*:*");
      my $lref = $references->{length};
      my @cutoff = ($cutoff->{@arg[0]}, $cutoff->{@arg[1]});
      my $correction =
	$lref>0 ? 0.5*(@cutoff[0]**3+@cutoff[1]**3)/$lref**3 : 1;
      my $aij = eval(@arg[2]);
      my $length = 
	scalar(@arg)>3 ? @arg[3] :
	$lref>0 ? 0.5*(@cutoff[0]+@cutoff[1])/$lref : 1;
      my $gamma = scalar(@arg)>4 ? eval(@arg[4]) : $gamma;
      if (!$correction) {
	EMC::Message::warning("missing cut off for @arg[0]\n"); $error = 1;
      } else {
	$aij = ($flag->{chi}>0 ? $aij/0.286 : $aij-25)/$correction+25;
	$pdata->{$key} = [$aij, $length, $gamma];
      }
    }
    EMC::Message::error("missing reference parameters\n") if ($error);
    $flag_set = 1;
  } else {
    my $source;

    if (defined($verbatim)) {
      EMC::Message::info("reading parameters from input\n");
      $source = $verbatim;
    } else {
      ($stream, $name) = EMC::IO::open($name, "r", $suffix);
      EMC::Message::info("reading parameters from \"%s\"\n", $name);
      $source = EMC::IO::get_data_quick($stream, $name);
      EMC::IO::close($stream, $name);
    }
    if ($field->{type} eq "dpd") {
      EMC::Message::info(
	"assuming %s parameters\n", $flag->{chi} ? "chi" : "dpd");
    }
  
    my ($name, $iline) = split(":", $source->{lines}->[0]);
    my $fline = scalar(@{$source->{lines}})>1 ? 1 : 0;
    
    $iline = 0 if ($fline);
    foreach (@{$source->{data}}) {
      my @arg = @{$_};
      my $line = $fline ? $source->{lines}->[$iline++] : "$name:".$iline++;
      
      if (scalar(@arg)<3) {
	EMC::Message::error_line($line, "expecting at least 3 arguments\n");
      }
      next if (substr(@arg[0],0,1) eq "#");
      next if (!scalar(@arg));
      if ($first) {
	$first = 0; 
	shift(@arg) if (@arg[0] eq "");
	shift(@arg) if (@arg[0] eq "");
	$parameters->{temperature} = [@arg];
	next;
      }
      $sites{@arg[0]} = 1 if (length(@arg[0])>0);
      $sites{@arg[1]} = 1 if (length(@arg[1])>0);
      EMC::References::define($references, @arg[0,1]) if (!$references->{flag});
      next if (!defined($type->{$arg[0]}));
      next if (!defined($type->{$arg[1]}));
      my $key = join(":", sort(@arg[0,1]));
      my $length = $references->{length}>0 ? 
	0.5*($cutoff->{@arg[0]}+$cutoff->{@arg[1]})/
	     $references->{length} : 1;
      my $correction = $references->{length}>0 ? 
	0.5*($cutoff->{@arg[0]}**3+$cutoff->{@arg[1]}**3)/
	     $references->{length}**3 : 1;

      # note: correction is needed for the way DPD interaction parameters are 
      # calculated based on length; might need to be removed in future

      @arg[2] = eval(@arg[2]);
      if (!$correction) {
	EMC::Message::warning("missing cut off for @arg[0]\n");
       	$error = 1;
      } else {
	my $offset = 0;
	$pdata->{$key} = [
	  ($flag->{chi}>0 ? @arg[2]/0.286:@arg[2]-$offset)/$correction+$offset,
	  $length, $gamma];
      }
    }
    EMC::Message::error("missing reference parameters\n") if ($error);
    close($stream) if (scalar($stream));
  }

  # Add replicas

  EMC::Types::create_replicas($types) if (!$references->{flag});
  foreach (@{$types->{replicas}}) {
    my @arg = @{$_};
    next if (scalar(@arg)<2);
    my @a = split(":", shift(@arg));
    if ($sites{@a[0]}) {
      EMC::Message::warning("replica parameter %s already exists\n", @a[0]);
      next;
    }
    my $type = @a[0];
    my $factor = scalar(@a)>1 ? @a[1] : 1;
    @a = split(":", @arg[-1]);
    my $offset = defined($inverse->{@a[0]}) ? 0 : pop(@arg);
    my $flag_exist = 0;
    my $flag_norm = 1;
    my @n = (0, 0, 0);
    my $count = 0;
    my @types;
    my @p;

    EMC::Message::info(
      "adding parameter $type using {%s}\n", join(", ", @arg));
    foreach (@arg) {
      my @a = split(":");
      $flag_norm = 0 if (!(defined(@a[2]) ? EMC::Math::flag(@a[2]) : 1));
    }
    foreach (@arg) {
      my @a = split(":");				# create self
      my $t = shift(@a);
      my $frac = defined(@a[0]) ? eval(shift(@a)) : 1;

      push(@types, $t);
      $t = $inverse->{$t};
      if (defined($pdata->{join(":", $t, $t)})) {
	my @q = @{$pdata->{join(":", $t, $t)}};
	@q[1] = 1 if (!@q[1]);
	my $i; for ($i=0; $i<3; ++$i) { 
	  my $f = ($i ? 1 : 1/@q[1]**3);
	  @n[$i] += $f*($flag_norm ? ($i ? $frac : 1/$frac) : 1);
	  @p[$i] += $f*@q[$i]*($i ? $frac : 1/$frac);
       	}
	$flag_exist = 1;
	++$count;
      }
    }
    if ($flag_exist) {
      my $i; for ($i=0; $i<3; ++$i) {
	@p[$i] *= $count if (!$flag_norm);
	@p[$i] /= @n[$i];
      }
      @p[2] = $gamma;
      @p[0] = (@p[0]-$aij0)*$factor+$aij0;
      $pdata->{join(":", $type, $type)} = [@p];
      foreach (@types) { 
	$pdata->{join(":", sort($type, $_))} = [@p];
      }
    }
    my $target = $inverse->{@types[0]};
    foreach(sort(keys(%{$pdata}))) {			# create others
      my @a = split(":");
      my $other = @a[0] eq $target ? @a[1] : @a[1] eq $target ? @a[0] : "";
      next if ($other eq "" || $other eq $type);
      my @n;
      my @p;

      $count = 0;
      foreach (@arg) {
	my @a = split(":");
	my $t = shift(@a);
	my $frac = defined(@a[0]) ? eval(shift(@a)) : 1;
	my $src = join(":", sort($other, $inverse->{$t}));
	my @q = @{$pdata->{$src}};
	
	my $i; for ($i=0; $i<scalar(@q); ++$i) { 
	  my $f = ($i ? 1 : 1/@q[1]**3);
	  @n[$i] += $f*($flag_norm ? ($i ? $frac : 1/$frac) : 1);
	  @p[$i] += $f*@q[$i]*($i ? $frac : 1/$frac);
       	}
	++$count;
      }
      my $i; for ($i=0; $i<3; ++$i) {
	@p[$i] *= $count if (!$flag_norm);
	@p[$i] /= @n[$i];
      }
      @p[2] = $gamma;
      @p[0] = (@p[0]-$aij0)*$factor+$aij0+$offset;
      @{$pdata->{join(":", sort($other, $type))}} = @p;
      $sites{$type} = 1;
    }
  }
  if (!$flag_set) {					# create missing

    my $length = $references->{length}>0 ? $references->{length} : 1.0;
    
    foreach (@{$nonbonds}) {
      my @v = @{$_};
      next if (scalar(@v)<2);
      my @b = (shift(@v), shift(@v));
      my @a = sort(@b); foreach (@a) { 
	$_ = defined($inverse->{$_}) ? $inverse->{$_} :
	     ($_ =~ m/\*/) ? $_ : $_;
      }
      my $key = join(":", @a);
      if (defined($inverse->{@v[0]})) {
	@b = sort(@v[0,1]);
	my $source =  join(
	  ":", $inverse->{@b[0]}, $inverse->{@b[1]});
	if (defined($pdata->{$key}) && 
	    defined($pdata->{$source}))
	{
	  EMC::Message::info(
	    "setting pair {%s} to {%s}\n", join(", ", @a), join(", ", @b));
	  @{$pdata->{$key}} = @{$pdata->{$source}};
	}
      }
      elsif (defined($pdata->{$key})) {
	my @p = @{$pdata->{$key}};
	my $i; for ($i=0; $i<scalar(@v); ++$i) { @p[$i] = @v[$i]; }
	EMC::Message::info(
	  "setting pair {%s} to {%s}\n", join(", ", @a), join(", ", @p));
	$pdata->{$key} = [@p];
      }
      else {
	EMC::References::define($references, @a);
	my @p = ($aij0, $length, $gamma);
	my $i; for ($i=0; $i<scalar(@v); ++$i) { @p[$i] = @v[$i]; }
	EMC::Message::info(
	  "setting pair {%s} to {%s}\n", join(", ", @a), join(", ", @p));
	$pdata->{$key} = [@p];
      }
    }
  }
  my $psites = $parameters->{sites} = [];
  foreach(sort(keys(%sites))) {
    next if (!defined($sites{$_}));
    if ($references->{flag} && !defined($type->{$_})) {
      EMC::Message::warning(
	"omitted type \'$_\' (not defined in first column of ".
	"$references->{name}.csv)\n");
      next;
    }
    push(@{$psites}, $_) if ($_ ne "*");
  }
  if ($flag->{assume}) {
    for (my $i = 0; $i<scalar(@{$psites}); ++$i) {
      my $pair = join(":", $psites->[$i,$i]);
      my $cutoff = $cutoff->{$psites->[$i]};
      if (!scalar(@{$pdata->{$pair}})) {
	$pdata->{$pair} = [$aij0, $cutoff, $gamma];
      }
    }
  }
  for (my $i = 0; $i<scalar(@{$psites}); ++$i) {
    for (my $j = $i; $j<scalar(@{$psites}); ++$j) {
      my $a = $psites->[$i];
      my $b = $psites->[$j];
      my $pair = join(":", $a, $b);
      next if ($flag_wild && $a eq $b);
      if (!defined($pdata->{$pair}) || 
	  !scalar(@{$pdata->{$pair}})) {
	EMC::Message::warning("missing parameters for pair {%s, %s}\n", $a, $b);
      }
    }
  }
  if ($field->{dpd}->{bond})
  {
    EMC::Message::info("transfering nonbond to bond parameters\n");
    foreach (sort(keys(%{$pdata})))
    {
      my @t = split(":");
      next if (scalar(@t)!=2);
      next if (defined($bond->{join("\t",@t)}));
      $bond->{join("\t",@t)} = join("\t",@{$pdata->{$_}}[0,1]);
    }
  }
  if (scalar(@{$fields->{list}->{name}})) {
    EMC::Message::info("replacing field name with project name\n");
  }
  $field->{list}->{name} = [$project->{name}];
  $field->{name} = $field->{id} = $project->{name};
  $field->{location} = "./";
  $parameters->{flag} = 1;
  EMC::Fields::update_fields($root->{fields}, $field, "reset");
}

