#!/usr/bin/perl
#
#  script:	module.pl
#  author:	Pieter J. in 't Veld
#  date:	June 6, 2020.
#  purpose:	Create EMC modules using predefined templates
#
#  Copyright (c) 2004-2020 Pieter J. in 't Veld
#  Distributed under GNU Public License v3 as stated in LICENSE file in EMC
#  root directory
#

# functions

sub uc_first {
  my $result="";
  my @part=split("_", shift);
  foreach (@part) { $result .= ucfirst($_); }
  return $result;
}


sub replace {
  my $template=shift;
  my $name=shift;
  my $Name=uc_first($name);
  my $NAME=uc($name);
  my $ext=shift;
  my @lines=split("\n", `cat $template$ext`);
  
  open(FILE, ">", $name.$ext);
  foreach (@lines)
  {
    $tmp=$_;
    $tmp=~s/template/$name/g;
    $tmp=~s/Template/$Name/g;
    $tmp=~s/TEMPLATE/$NAME/g;
    print(FILE $tmp."\n");
  }
  print(FILE "\n");
  close(FILE);
}


# main

{
  replace(@ARGV[0, 1], ".h");
  replace(@ARGV[0, 1], ".c");
}
