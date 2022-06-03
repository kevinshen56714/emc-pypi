#!/usr/bin/env perl

{
  foreach (<>) {
    chop();
    $_ =~ s/^\s+|\s+$//g;
    print("$_\n");
    break;
  }
}

