#!/bin/bash

# main

  for file in caso4.top caso4.prm; do
    replace.pl "ca\+g" "CA+G" $file;
    replace.pl h1og H1OG $file;
    replace.pl o2hg O2HG $file;
    replace.pl o1sg O1SG $file;
    replace.pl s4og S4OG $file;
  done;

