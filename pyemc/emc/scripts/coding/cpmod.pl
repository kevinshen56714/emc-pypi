#!/usr/bin/env perl
#
#  file:	cpmod.pl
#  author:	Pieter J. in 't Veld
#  date:	March 10, 2006, April 14, 2007, September 30, 2010,
#  		February 8, 2018, June 6, 2020.
#  purpose:	copy modules, preserving function and data structure; part of
#  		EMC distribution
#
#  Copyright (c) 2004-2020 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20060310	Inception date
#    20070414	Added replacement of prefaces
#    20180208	Added check for .sh
#    20200606	Added changes to include paths
#

sub test {
  my $file = shift;
  my $xor = shift;
  my $result = scalar(stat($file))^$xor;

  printf("Error: %s %sexist%s.\n", 
    $file, $xor ? "does not " : "", $xor ? "" : "s") if ($result);
  return $result;
}


sub replace {
  my $ext = shift;
  my $input = $files[0];
  my $output = $files[1];
  my $file_in;
  my $file_out;
 
  return if (test($input.$ext, 1)||test($output.$ext, 0));
  open($file_in, "<", $input.$ext);
  open($file_out, ">", $output.$ext);
  foreach (<$file_in>)
  {
    my $tmp = $_;
    if (length($prefaces[0])) {					# 20070414
      #$tmp =~ s/$includes[0]/$includes[1]/g;			# 20200606
      $tmp =~ s/$prefaces[0]/$prefaces[1]/g;
      $tmp =~ s/$Prefaces[0]/$Prefaces[1]/g;
      $tmp =~ s/$PREFACES[0]/$PREFACES[1]/g;
    }
    $tmp =~ s/$names[0]/$names[1]/g;
    $tmp =~ s/$Names[0]/$Names[1]/g;
    $tmp =~ s/$NAMES[0]/$NAMES[1]/g;
    print($file_out $tmp);
  }
  close($file_out);
  close($file_in);
  ++$nreplacements;
}


sub strip {
  return (split("\\.h", (split("\\.c", shift))[0]))[0];
}


sub uc_first {
  my $result = "";
  my @list = split("_", shift);
  foreach (@list) {
    $result = $result.ucfirst($_);
  }
  return $result;
}


sub initialize {
  @files = ();
  @names = ();
  @Names = ();
  @NAMES = ();
  @prefaces = ();
  @Prefaces = ();
  @PREFACES = ();
  $help = 0;
  $nreplacements = 0;
  
  foreach(@ARGV) {
    if (substr($_,0,1) eq '-') {
      $help = 1;
    }
    else {
      push(@files, $_) if (scalar(@files)<2);
    }
  }
  if ($help || (scalar(@files)!=2))
  {
    printf("usage: cpmod [preface/]name [preface/]replacement\n\n");
    exit(-1); 
  }
  my $pop = 1;
  foreach(@files) {
    my @arg = split("/");
    $pop = 0 if (scalar(@arg)<2);
  }
  foreach(@files) {
    $_ = (split("\\.h", (split("\\.c", (split("\\.cpp"))[0]))[0]))[0];
    my @arg = split("/");
    $_ = lc($_);
    push(@names, lc($arg[-1]));
    push(@NAMES, uc($arg[-1]));
    push(@Names, uc_first($arg[-1]));
    pop(@arg) if ($pop);
    push(@includes, lc(join("/", @arg)));			# 20200606
    push(@prefaces, lc(join("_", @arg)));
    push(@PREFACES, uc(join("_", @arg)));
    foreach(@arg) { $_ = uc_first($_); }
    push(@Prefaces, join("", @arg));
  }
}


# main

  initialize();
  replace(".h") if (-e "$files[0].h");
  replace(".c") if (-e "$files[0].c");
  replace(".cpp") if (-e "$files[0].cpp");
  replace(".sh") if (-e "$files[0].sh");			# 20180208
  
  print("copied $nreplacements file", $nreplacements==1 ? "" : "s", "\n");

