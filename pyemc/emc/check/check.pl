#!/usr/bin/env perl

sub files {
  my $stream;
  my $files = {};

  open($stream, "<", @_[0]);
  foreach (<$stream>) {
    chomp;
    $files->{(split(":"))[0]} = 1;
  }
  close($stream);
  return $files;
}


{
  my $notes = files("notes.txt");
  my $all = files("all.txt");

  foreach (sort(keys(%{$all}))) {
    next if (defined($notes->{$_}));
    next if ($_ =~ m/\.swp/g);
    next if ($_ =~ m/header\.h/g);
    next if ($_ =~ m/deem/g);
    next if ($_ =~ m/zlib/g);
    print("$_\n");
  }
}
