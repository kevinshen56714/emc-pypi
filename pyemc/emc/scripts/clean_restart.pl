#!/usr/bin/env perl

  foreach (split("\n", `find . -name '*.restart1'`))
  {
    next if (! -f $_);
    next if (! -f ($file = substr($_, 0, length($_)-1))."2");
    @f1 = stat($file."1");
    @f2 = stat($file."2");
    $ext = @f1[7]>@f2[7] ? "1" : 
	   @f1[7]<@f2[7] ? "2" :
	   @f1[9]>@f2[9] ? "1" : "2";
    printf(
      "%10d %10d %10d %10d %d %s\n",
      @f1[7], @f2[7], @f1[9], @f2[9], $ext, $file);
    `gzip $file$ext`;
    unlink $file.($ext eq "1" ? "2" : "1");
  }
