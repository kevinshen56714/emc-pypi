#!/usr/bin/env perl
#
#  module:	EMC::Item.pm
#  author:	Pieter J. in 't Veld
#  date:	December 19, 2021.
#  purpose:	Item structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  members:
#    index	ARRAY	handling order of hash elements (structs)
#    [any_name]	STRUCT	
#      options	ARRAY	options coming directly after ITEM indicator
#      data	ARRAY	respective array of entries containing arrays of
#			elements
#      [...]	STRUCT	subsequent structs
#
#  notes:
#    20211219	Inception of v1.0
#    20220930	New version v1.1
#    		Addition of $EMC::Item::endless
#    20240324	Change to altered format of EMC::IO::get()
#    		and EMC::IO::get_preprocess()
#

package EMC::Item;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.2";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Common;
use EMC::List;


# defaults

$EMC::Item::Identity = {
  author	=> "Pieter J. in 't Veld",
  date		=> "March 24, 2024",
  version	=> $VERSION
};


# functions

# read

sub split_data {				# <= split_data
  my $s = shift(@_);
  my @arg = split(",", $s);
  my @result = ();
  my @i = map({index(@arg[0],$_)} (":", "="));

  if (@i[0]>=0 && @i[0]<@i[1]) {
    @arg = split(" ", $s);
    push(@result, @arg[0]);
    $s = substr($s,length(@arg[0]));
  }
  foreach (split("\t", $s)) {
    foreach (split(",", $_)) { 
      $_ =~ s/^\s+|\s+$//g;
      foreach ($_ =~ /(".+"|\S+)/g) {
	push(@result, $_);
      }
    }
  }
  if (substr(@result[0],0,1) ne "\"") {
    @arg = split(" ", @result[0]);
    if (scalar(@arg)>1) {
      shift(@result);
      unshift(@result, @arg);
    }
  }
  push (@result, ",") if (substr(@_[0],-1,1) eq ",");
  @arg = (); 
  foreach (@result) {
    last if (substr($_,0,1) eq "#");
    push(@arg, $_) if ($_ ne "");
  }
  return @arg;
}


sub set_include {
  my $stack = shift(@_);
  my $include = shift(@_);
  my $name = shift(@_);
  my $line = shift(@_);
  my $index = shift(@_);
  my $data = shift(@_);
  my $get = shift(@_);
  my @arg = @_;

  foreach (@arg) { $_ =~ s/^\"+|\"+$//g; }
  push(@{$stack}, {name => $name, index => $index, data => $data});
  if (!defined($name = EMC::IO::locate(@arg[0], ".inc", @{$include}))) {
    EMC::Message::error_line(
      "$name:$line", "cannot include \"@arg[0]\"\n");
  }
  EMC::Message::info("including \"%s\"\n", $name);
  my $stream = EMC::IO::open($name, "r");
  push(@{$stack}, {name => $name, index => 0, data => $get->($stream)});
  EMC::IO::close($stream);
  return $stack;
}


sub read {
  my $stream = ref(@_[0]) ne "HASH" ? shift(@_) : undef;
  my $attr = ref(@_[0]) eq "HASH" ? shift(@_) : {};
  $attr->{flag} = EMC::Common::attributes({trim => 1}, $attr->{flag});
  my $convert = EMC::List::hash(
    EMC::Element::extract($attr, "convert"));
  my $endless = EMC::List::hash(
    EMC::Element::extract($attr, "endless"));
  my $env_only = EMC::List::hash(
    EMC::Element::extract($attr, "env_only"));
  my $env_verbatim = EMC::List::hash(
    EMC::Element::extract($attr, "env_verbatim"));
  my $environment = EMC::List::hash(
    EMC::Element::extract($attr, "environment"));
  my $locate = EMC::List::hash(
    EMC::Element::extract($attr, "locate"));
  my $stage_only = EMC::List::hash(
    EMC::Element::extract($attr, "stage_only"));
  my $verbatim = EMC::List::hash(
    EMC::Element::extract($attr, "verbatim"));
  my $ignore = EMC::List::hash(
    EMC::Element::extract($attr, "ignore"));
  my $extend = {"&" => 1, "\\" => 1};

  my $fenvironment = EMC::Common::element($attr, "flag", "environment");
  my $get = EMC::Common::element($attr, "flag", "preprocess") 
	    && !$fenvironment ? \&EMC::IO::get_preprocess : \&EMC::IO::get;

  my $fheader = EMC::Common::element($attr, "flag", "header");
  my $fsplit = EMC::Common::element($attr, "flag", "split");
  my $ftrim = EMC::Common::element($attr, "flag", "trim");
  my $include = EMC::Common::element($attr, "include");
  my $name = EMC::Common::element($attr, "name");
  my $stage = EMC::Common::element($attr, "stage");
  my $trial = EMC::Common::element($attr, "trial");
  my $raw = EMC::Common::element($attr, "data");
  my $default = $trial;

  $raw = $raw ? ref($raw) eq "HASH" ? EMC::Hash::copy($raw) : undef : undef;

  my $stack = [
    {name => $name, index => 0, data => $raw ? $raw : $get->($stream)}];
  my $fverbatim = 0;
  my $fcomment = 0;
  my $fappend = 0;
  my $level = 0;
  my $line = 0;
  my $next = 0;
  my $first = 1;
  my $nempty = 0;
  my $header;
  my $lines;
  my $item;
  my $data;
  my $ptr;
  my $id;

  while (scalar(@{$stack})) {
    my $io = pop(@{$stack});
    my $name = $io->{name};
    my $index = $io->{index};
    my $idata = $io->{data};
    my $line = 0;

    while (scalar(@{$idata->{data}})) {
      my $s = shift(@{$idata->{data}});
	 $s = EMC::Common::trim($s) if (!$fverbatim);
      my @arg = $fsplit ? split_data($s) : split("\t", $s);
      
      if (defined($idata->{lines}->{$index})) {
	my $ptr = $idata->{lines}->{$index++};
	$name = $ptr->{name};
	$line = $ptr->{line};
      } else {
	++$index;
	++$line;
      }
      if (!$fverbatim) {
	if ($fheader && !scalar(@arg)) {
	  next if ($next);
	  if (defined($header)) {
	    $ptr->{header}->{header} = $header;
	    push(@{$ptr->{index}}, "header");
	    undef($header);
	  }
	  $next = 1;
	  next;
	}
      }
      @arg = split_data($s) if (scalar(@arg)==1);
      if ($ftrim && $first && !scalar(@arg)) {
	next if ($fverbatim ? substr($s,0,1) ne "#" : 1);
      }
      $first = 0;
      if (defined($id)) {				# item section
	++$nempty if ($fverbatim && !scalar(@arg) && !$fcomment);
	if (@arg[0] eq "ITEM") {
	  if (lc(@arg[1]) eq "end") {
	    --$level;
	    if (!$level) {
	      if ($ftrim && $nempty) {
		for ($nempty=0; $nempty<scalar(@{$data}); ++$nempty) {
		  last if (@{$data}[-1-$nempty] ne "");
		}
		splice(@{$data}, -$nempty) if ($nempty && @{$data});
		splice(@{$lines}, -$nempty) if ($nempty && @{$lines});
	      }
	      $fcomment = 0;
	      undef($data);
	      undef($id);
	      next;
	    }
	  } else {
	    if ($endless && defined($endless->{lc(@arg[1])})) {
	      if ($include && lc(@arg[1]) eq "include") {
		if (!$fverbatim) {
		  shift(@arg); shift(@arg);
		  set_include($stack,
		    $include, $name, $line, $index, $io->{data}, $get, @arg);
		  last;
		}
	      }
	    } else {
	      ++$level;
	    }
	  }
	  $nempty = 0 if (scalar(@arg));
	}
	next if (!$fverbatim && !scalar(@arg));
	if ($fverbatim) {
	  push(@{$data}, $s);
	  push(@{$lines}, $name ? "$name:$line" : $line);
	} elsif ($fappend) {
	  pop(@arg) if (($fappend = defined($extend->{@arg[-1]}) ? 1 : 0));
	  push(@{$data->[-1]}, (grep { $s ne '' } @arg));
	  $lines->[-1] .= "-$line" if (!$fappend);
	} else {
	  pop(@arg) if (($fappend = defined($extend->{@arg[-1]}) ? 1 : 0));
	  push(@{$data}, [grep { $s ne '' } @arg]);
	  push(@{$lines}, $name ? "$name:$line" : $line);
	}
      } else {						# item header
	if (substr(@arg[0],0,1) eq "#") {
	  $header = [] if (!defined($header));
	  push(@{$header}, $s);
	  next;
	} else {
	  next if (!scalar(@arg));
	  my $key = shift(@arg);
	  if ($key ne "ITEM") {
	    EMC::Message::error_line(
	      "$name:$line", "unexpected keyword '$key'\n");
	  }
	  $id = lc(shift(@arg));
	  if ($id eq "index") {
	    EMC::Message::error_line("$name:$line", "unallowed item 'index'\n");
	  }
	  $id = $convert->{$id} if ($convert && defined($convert->{$id}));
	  $fverbatim = $verbatim && defined($verbatim->{$id}) ? 1 : 0;
	  $item = {} if (!defined($item));
	  $ptr = $item;
	  my $point;
	  if ($environment) {				# environment $ptr def
	    if ($fenvironment && !defined($environment->{$id})) {
	      my $options = EMC::Hash::arguments(
		{stage => $stage, trial => $trial}, 
		{line => $line, order => ["stage", "trial"]}, 
		$id eq "stage" || $id eq $trial ? () : @arg);

	      $ptr = $ptr->{stages} = EMC::Common::hash($ptr, "stages");
	      if (defined($stage)) {
		$options->{stage} = $stage = @arg[0] if ($id eq "stage");
		$ptr = EMC::Common::hash($ptr, $stage);
	      }
	      if (defined($trial)) {
		$options->{trial} = $trial = @arg[0] if ($id eq "trial");
		if (defined($stage_only->{$id})) {
		  $ptr = EMC::Common::hash($ptr, $default);
		} else {
		  $ptr = EMC::Common::hash($ptr, $trial);
		}
	      }
	    } elsif ($id eq "environment") {
	      $fenvironment = 1;
	    } elsif ($fenvironment^defined($env_only->{$id})) {
	      if (!defined($ignore->{$id})) {
		EMC::Message::error_line(
		  "$name:$line", "unallowed item '$id'\n");
	      }
	    }
	    if ($fenvironment && !$fverbatim) {
	      $fverbatim = 1 if (defined($env_verbatim->{$id}));
	    }
	  } else {					# regular $ptr def
	    $ptr = EMC::Common::hash($ptr, $id);
	  }
	  $ptr->{index} = [] if (!defined($ptr->{index}));
	  push(@{$ptr->{index}}, $id);
	  if ($endless && !defined($endless->{$id})) {
	    $ptr = EMC::Common::hash($ptr, $id);
	  }
	  if ($locate && defined($locate->{$id}) && !$fenvironment) {
	    my $options = EMC::Hash::arguments(
	      {stage => "default", spot => "default"}, 
	      {line => $line, order => ["stage", "spot"],
		replace => $id eq "emc" ? {phase => "stage"} : undef},
	      @arg);
	    $ptr = EMC::Common::hash($ptr, $options->{stage}, $options->{spot});
	  }
	  $nempty = 0;
	  $fappend = 0;
	  undef($header);
	  if ($endless && defined($endless->{$id})) {
	    if (defined($include) ? $id ne "include" : 1) {
	      EMC::Message::message(@arg, "\n") if ($id eq "write");
	      undef($id);
	    } else {
	      set_include($stack,
	       	$include, $name, $line, $index, $io->{data}, $get, @arg);
	      undef($id) if (!$level);
	      last;
	    }
	  } elsif (!$level) {
	    $ptr->{flag}->{verbatim} = $fverbatim;
	    $ptr->{flag}->{line} = "$name:$line";
	    $ptr->{header} = $header;
	    $ptr->{options} = [@arg];
	    if (defined($ptr->{data})) { $data = $ptr->{data}; }
	    else { $data = $ptr->{data} = []; }
	    if (defined($ptr->{lines})) { $lines = $ptr->{lines}; }
	    else { $lines = $ptr->{lines} = []; }
	    ++$level;
	  }
	  $first = 1;
	}
      }
    }
  }
  return $item;
}


# write

sub write {
  my $stream = shift(@_);
  my $item = shift(@_);
  my $attr = EMC::Common::attributes(shift(@_));
  my $single = {
    angle => 1, angle_auto => 1, bond => 1, bond_auto => 1, cmap => 1,
    equivalence => 1, equivalence_auto => 1, improper => 1, improper_auto => 1,
    increment => 1, mass => 1, nonbond => 1, nonbond_auto => 1, precedence => 1,
    references => 1, templates => 1, rules => 1, torsion => 1,
    torsion_auto => 1};
  my $indent = defined($attr->{tab}) ? int($attr->{tab}) : 2;
  my $fsingle = 0;

  return if (!defined($item));
  $indent = 1 if ($indent<1);
  $indent *= 8;
  foreach(defined($item->{index}) ? 
		@{$item->{index}} : sort(keys(%{$item}))) {
    my $id = $_;
    my $comment;

    next if (!defined($item->{$id}));
    if (defined($item->{$id}->{header})) {
      print($stream join("\n", @{$item->{$id}->{header}}));
    } else {
      print($stream join(" ", "#", ucfirst($id), "section"));
    }
    print($stream "\n\n");
    next if (!defined($item->{$id}->{data}));
    print($stream join("\t", "ITEM", uc($id)));
    if (defined($item->{$id}->{options})) {
      print($stream "\t", join("\t", @{$item->{$id}->{options}}));
    }
    print($stream "\n\n");
    
    next if (!defined($item->{$id}->{data}));		# without END
    
    $fsingle = defined($single->{$id}) ? 1 : 0;		# with END
    foreach (@{$item->{$id}->{data}}) {
      my $data = $_;

      print($stream "\n") if ($comment);
      $comment = 0 if ($comment);
      my @data = @{$data}; 
      if (substr(@data[0],0,1) eq "#") {
	#print($stream shift(@data), " ");
	$comment = 1;
      }
      if (!$fsingle && scalar(@data)>1) {
	my $n = $indent-length(@data[0]);
	print($stream shift(@data));
	for ($n+=8 if ($n<0); $n>0; $n-=8) { print($stream "\t"); }
      }
      print($stream join("\t", @data), "\n");
    }
    print($stream "\n", join("\t", "ITEM", "END", "# ".uc($id)), "\n\n");
  }
}

