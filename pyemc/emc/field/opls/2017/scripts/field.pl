#!/usr/bin/env perl

# Module initialization

BEGIN {
  use File::Basename;
  if (-d dirname($0)."/modules") {
    $::EMC::Modules{dir} = dirname($0)."/modules";
  } else {
    $::EMC::Modules{dir} = $ENV{EMC_ROOT}."/scripts/modules";
  }
  if (! -d $::EMC::Modules{dir}) {
    print("Error: cannot locate modules directory: set EMC_ROOT?\n\n");
    exit(-1);
  }
}
use lib $::EMC::Modules{dir};

use EMC;

{
  if (!scalar(@ARGV)) {
    print("usage: $0 project\n\n");
    exit(-1);
  }
  
  my $name = @ARGV[0];
  my $stream = EMC::IO::open($name, "r");
  my $field = EMC::Fields::read($stream);

  EMC::Message::dumper("field = ", $field);
  EMC::IO::close($stream, $name);
}

