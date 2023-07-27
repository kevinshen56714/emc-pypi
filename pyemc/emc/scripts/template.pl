#!/usr/bin/env perl
#
#  program:	template.pl
#  author:	Pieter J. in 't Veld
#  date:	October 31, 2007
#  purpose:	Creation of modules from templates; part of EMC distribution
#
#  notes:
#    20071031	Creation date; usage: template.pl template file .ext
#
#  Copyright (c) 2004-2023 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#

  sub replace {
    my $template=shift;
    my $name=shift;
    my $Name=ucfirst($name);
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
 
  replace(@ARGV);

