#!/usr/bin/env perl

{
  # init

  my %nargs = (
    nonbond => 2, increment => 2, bond => 2, angle => 3, torsion => 4,
    improper => 4
  );
  my @arg = @ARGV;
  my $mode = lc(shift(@arg));

  if (!defined($nargs{$mode})) {
    print("usage: list.pl mode type type [...]\n\n");
    exit(-1);
  }
  if (scalar(@arg)!=$nargs{$mode}) {
    print("incorrect number of types for '$mode'\n\n");
    exit(-1);
  }

  # setup

  my @types = ();
  foreach (@arg) { 
    $_ = lc($_);
    my $i = index($_, "*");
    push(@types, $i<0 ? [$i, $_] : [$i, substr($_,0,$i)]);
  };
  my $ntypes = scalar(@types);

  # interpretation

  my $i; for ($i=0; $i<=$ntypes; ++$i) { shift(@ARGV); }
  foreach(<>) {
    chop();
    @arg = split(" ", lc($_));
    next if (!scalar(@arg));
    if (!$read) {
      next if (@arg[0] ne "item");
      next if ((@arg[1] ne $mode)&&(@arg[1] ne $mode."_auto"));
      $read = 1;
      next;
    }
    if (join(" ", @arg[0,1]) eq "item end") {
      $read = 0;
      next;
    }
    next if (substr(@arg[0],0,1) eq "#");
    my $flag = 1; $i = 0; foreach (@types) {
      if (@{$_}[1] ne (@{$_}[0]<0 ? @arg[$i] : substr(@arg[$i],0,@{$_}[0]))) {
	$flag = 0; last;
      }
      ++$i;
    }
    if (!$flag) {
      $flag = 1; $i = 0; foreach (reverse(@types)) {
	if (@{$_}[1] ne (@{$_}[0]<0 ? @arg[$i] : substr(@arg[$i],0,@{$_}[0]))) {
	  $flag = 0; last;
	}
	++$i;
      }
    }
    next if (!$flag);
    print("$_\n");
  }
}
