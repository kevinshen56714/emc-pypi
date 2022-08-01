#!/usr/bin/env perl
#
#  program:	header.pl
#  author:	Pieter J. in 't Veld
#  date:	May 18, 2019.
#  purpose:	Abstract header information from all *.c and *.h files and
#  		search and replace lines as stated in main
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#

@header_file_names = split(" ", `find core/* -name '*.h'`);
@module_file_names = split(" ", `find core/* -name '*.c'`);

sub functions {
  my $name = shift;
  my $mode = shift;
  my $functions = shift;
  my $level = 0;
  my $paren = 0;
  my $comment = 0;
  my $line = 0;
  my $typedef = 0;
  my $last = "";
  my $total;
  my $file;

  $constants = 0;
  open($file, "<$name");
  while (<$file>)
  {
    chop;
    ++$line;
    --$typedef if ($typedef);
    if ($skip)
    {
      --$skip if (!m/ID/g);
    }
    if ($commentline)
    {
      if ($extend)
      {
	$extend = m/\\/g; next;
      }
      $commentline = 0;
    }
    if ($comment)
    {
      next if (!(m/\*\//g));
      $_ = $';
      $comment = 0;
      $extend = 0;
    }
    else
    {
      if (m/#ifdef/g && m/_ID/g) {
       	$skip = 2;
      }
      $extend = m/\\/g;
      if (m/\/\*/g)
      {
	$comment = 1; $_ = $`;
      }
      if ((m/\/\//g)||(m/\#/g))
      {
	$commentline = 1; $_ = $`;
      }
      if (m/typedef/g)
      {
	$skip = 1; my $full = $_;
	++$skip if (!($full =~ m/\;/g));
	$typedef = $skip;
      }
    }
    my $arg = "";
    my $exclude = $comment ? 1 : substr($_,0,1) eq "#" ? 1 : 0;
    my $struct = ($mode ? 1 : $typedef&&!($level||$paren)) ? 1 : 0;
    #print("[$exclude:$level:$paren] $_\n");
    if ((!($exclude||$skip||$paren))&&
	  ($mode ? $level : !(m/static/g || $level)))
    {
      my $next = $_;
      while ($next =~ m/\(/g)
      {
	$next = $';
	$arg = $`;
	foreach(" ", "\t", "\\+", "\\-", "\\*", "\\/", "\\^", "\\|", "\\&", "!", "=", "\\{")
	{
	  $arg = (split($_, $arg))[-1];
	}
	$arg = "" if ($arg[-1] =~ m/(\;)(\))(\,)(\+)(\-)(\*)(\^)(\/)(\[)(\])/g);
	$functions->{$arg} = $name if (length($arg));
      }
    }
    if ((!($exclude||length($arg))) && $struct)
    {
      if (($mode ? 1 : $typedef ? !m/\(/g : 1)&&(m/struct /g))
      {
	$arg = $'; $arg = "struct ".(split("\t", (split(" ", $arg))[0]))[0];
	$functions->{$arg} = $name if (length($arg));
      }
    }
    $constants = 1 if (m/CONSTANTS_/g);
    $total = $_; 
    while ($total =~ m/\{/g) { ++$level; $total = $'; }
    $total = $_;
    while ($total =~ m/\}/g) { --$level; $total = $'; }
    next if ($mode);
    $total = $_;
    while ($total =~ m/\(/g) { ++$paren; $total = $'; }
    $total = $_;
    while ($total =~ m/\)/g) { --$paren; $total = $'; }
  }
}


sub replace
{
  $search		= shift;
  $screen		= 1;
  if ($search eq "-q") { $screen = 0; $search = shift; }
  $replace		= shift;
  foreach (@_)
  {
    $name		= $_;
    $found		= 0;
    $nlines		= 0;
    $nchanges		= 0;
    @output		= ();
    open($file, "<".$name);
    while (<$file>)
    {
      ++$nlines;
      $line		= $_;
      $line		=~s/$search/$replace/g;
      push(@output, $line);
      next if ($line eq $_);
      printf("%s:%s: %s", $name, $nlines, $line) if ($screen);
      ++$nchanges;
    }
    close($file);
    next if ($nchanges<1);
    open($file, ">".$name);
    foreach (@output) { printf($file "%s", $_); }
    close($file);
    printf("%s: changed %s line%s.\n",
      $name, $nchanges, $nchanges!=1 ? "s" : "") if ($screen);
  }
}

# main

  %headers = ();
  foreach(@header_file_names)
  {
    functions($_, 0, \%headers);
  }
  %modules = ();
  foreach(@ARGV)
  {
    my %tmp = ();
    my $name = $_;
    $name =~ s/\.c/\.h/g;
    functions($_, 1, \%tmp);
    foreach (sort(keys(%tmp)))
    {
      my $arg = $headers{$_};
      $modules{$arg} = $_ if ($arg ne "");
    }
    $search = '#include "core/header.h"'."\n";
    @replace = ('#include "core/default.h"'."\n");
    foreach(sort(keys(%modules)))
    {
      push(@replace, "#include \"$_\"\n") if ($_ ne $name);
      $constants = 0 if ($_ eq "core/constants.h");
    }
    push(@replace, '#include "core/constants.h"'."\n") if ($constants);
    print(join("", sort(@replace)));
    replace($search, join("", sort(@replace)), $name);
    exit;
  }

