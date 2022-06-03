#!/usr/bin/env perl

  print("#define PARSE_OPER_LIST \\\n");
  foreach (@ARGV) {
    my $a = lc($_);
    my $A = uc($_);
    print("  PARSE_OPER(Long, $A, $a, $a, 1, &) \\\n");
  }

