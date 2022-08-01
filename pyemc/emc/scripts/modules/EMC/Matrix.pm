#!/usr/bin/env perl
#
#  module:	EMC::Matrix.pm
#  author:	Pieter J. in 't Veld
#  date:	October 27, 2019.
#  purpose:	Matrix operations; part of EMC distribution
#
#  Copyright (c) 2004-2022 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20191027	Inception of v1.0
#

package EMC::Matrix;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);


# functions

sub set_variables {
  $EMC::Matrix::Script = "EMC::Matrix.pm";
  $EMC::Matrix::Author = "Pieter J. in 't Veld";
  $EMC::Matrix::Version = "1.0";
  $EMC::Matrix::Date = "October 27, 2019";
  $EMC::Matrix::EMCVersion = "9.4.4";
}


# vector operations

sub vset {
  my ($v, $n) = @_[0,1];
  my $d = scalar(@_)>2 ? @_[2] : 0;

  for (my $i=0; $i<$n; ++$i) { $v->[$i] = $d; }
  return $v;
}


sub vjoin {
  return (@{@_[0]}, @{@_[1]});
}


sub vdim {
  return $#{@_[0]}+1;
}


sub vmax {
  my ($v, $abs) = @_[0,1];
  my $max = 0.0;

  foreach (@{$v}) {
    $max = ($abs ? abs($_) : $_) if (($abs ? abs($_) : $_) > $max);
  }
  return $max;
}


sub vcut {
  my ($v, $cut, $relative) = @_[0,1,2];

  $cut *= vmax($v, 1) if ($relative);
  foreach (@{$v}) {
    $_ = 0 if (abs($_) < $cut);
  }
  return $v;
}


sub vround {
  my ($v, $round) = @_[0,1];

  foreach (@{$v}) {
    $_ = int($_/$round+($_<0 ? -0.5 : 0.5))*$round;
  }
  return $v;
}


sub vprint {
  my @row;
  foreach (@{@_[0]}) { push(@row, sprintf("%.4g", $_)); }
  print(join("\t", @row), "\n");
}


# matrix operations

sub mdim {
  return ($#{@_[0]}+1, $#{@_[0]->[0]}+1);
}


sub mmax {
  my ($m, $abs) = @_[0,1];
  my $max = 0.0;

  foreach (@{$m}) {
    foreach (@{$_}) {
      $max = ($abs ? abs($_) : $_) if (($abs ? abs($_) : $_) > $max);
    }
  }
  return $max;
}


sub mcut {
  my ($m, $cut, $relative) = @_[0,1,2];

  $cut *= mmax($m, 1) if ($relative);
  foreach (@{$m}) {
    foreach (@{$_}) {
      $_ = 0 if (abs($_) < $cut);
    }
  }
  return $m;
}


sub mround {
  my ($m, $round) = @_[0,1];

  foreach (@{$m}) {
    foreach (@{$_}) {
      $_ = int($_/$round+($_<0 ? -0.5 : 0.5))*$round;
    }
  }
  return $m;
}


sub mcopy {
  my $a = shift(@_);
  my $b = [];

  foreach (@{$a}) {
    push(@{$b}, [@{$_}]);
  }
  return $b;
}


sub mtm {
  my $m = shift(@_);
  my @dim = mdim($m);
  my $n = @dim[-1]-1;
  my @null = ();
  my $mtm;
  my @b;
  my ($i, $j);

  for ($i=0; $i<$n; ++$i) {
    for ($j=0; $j<=$n; ++$j) {
      foreach (@{$m}) { 
	$mtm->[$i]->[$j] += $_->[$i]*$_->[$j]; }
    }
  }
  return $mtm;
}


sub mheader {
  my @i;
  my @j;

  foreach (@{@_[0]}) {
    my @arg = split("\t");
    push(@i, @arg[0]); push(@j, @arg[1]);
  }
  print("\t", join("\t", @i), "\n");
  print("\t", join("\t", @j), "\n");
}


sub vprint {
  my $row = shift(@_);
  my @data;
  foreach (@{$row}) { push(@data, sprintf("%.4g", $_)); }
  print(join("\t", @data), "\n");
}


sub mprint {
  my $m = shift(@_);
  my @dim = EMC::Matrix::mdim($m);
  my $i = 1;

  #print(join(" x ", EMC::Matrix::mdim($m)), " matrix\n");
  for ($i=0; $i<@dim[1]; ++$i) { 
    printf("%s%s", $i ? "\t" : "      |\t", $i+1); };
  print("\n");
  for ($i=0; $i<=@dim[1]; ++$i) {
    print("--------"); };
  print("\n");
  $i = 1;
  foreach (@{$m}) { 
    printf("%-6.6s|\t", $i++);
    EMC::Matrix::vprint($_);
  }
  print("\n");
}


sub mreduce {
  my $m = shift(@_);
  my %hash;
  my @mm;

  foreach (@{$m}) {
    $hash{join("\t", @{$_})} = 1;
  }
  foreach (reverse(sort(keys(%hash)))) {
    push(@mm, [split("\t")]);
  }
  @{$m} = @mm;
  return $m;
}


sub msolve {
  my ($a, $cut, $show, $issues, $svd, $mm) = @_[0,1,2,3,4,5];
  my $m = EMC::Matrix::mcopy($a);
  my $nrows = $#{$a};
  my $ncols = $#{$a->[0]};
  my $eps = $cut>0 ? $cut : 1e-6;
  my $i = 0;
  my @issues;

  $$mm = $m if (defined($mm));
  $$svd = 0 if (defined($svd));
  EMC::Matrix::mprint($m) if ($show);
  ROW: for ($i=0; $i<=$nrows; ++$i) {
    my $k = $i;
    print("i = $i\n") if ($show);
    last ROW if ($i==$ncols);
    while (abs($m->[$i]->[$i])<$eps) {
      last ROW if ($k++>$nrows);
      my $row = splice(@{$m}, $i, 1);
      push(@{$m}, $row);
    }
    my $mi = $m->[$i];
    my $f = $mi->[$i];
    for (my $k=0; $k<=$ncols; ++$k) {
      $mi->[$k] /= $f if ($mi->[$k]);
    }
    if (!$issues) {
      for (my $j=0; $j<=$nrows; ++$j) {
	next if ($i==$j);
	my $mj = $m->[$j];
	next if (!($f = $mj->[$i]));
	for (my $k=0; $k<=$ncols; ++$k) {
	  $mj->[$k] -= $mi->[$k]*$f;
	  $mj->[$k] = 0 if (abs($mj->[$k])<$eps);
	}
      }
    } else {
      for (my $j=0; $j<=$nrows; ++$j) {
	next if ($i==$j);
	my $mj = $m->[$j];
	next if (!($f = $mj->[$i]));
	my @nzero = (0, 0);
	for (my $k=0; $k<=$ncols; ++$k) {
	  ++@nzero[0] if ($k<$ncols && !$mj->[$k]);
	  $mj->[$k] -= $mi->[$k]*$f;
	  $mj->[$k] = 0 if (abs($mj->[$k])<$eps);
	  ++@nzero[1] if ($k<$ncols && !$mj->[$k]);
	}
	next if (@nzero[0] == @nzero[1]);
	$issues->{$i} = 1 if (@nzero[1]==$ncols && $mj->[$ncols]);
      }
    }
    EMC::Matrix::mprint($m) if ($show);
  }
  if ($i<$ncols) {
    my ($u, $w, $v, $b, $x) = ([], [], [], [], []);
    my ($wmax, $wmin);

    foreach (@{$a}) {
      push(@{$u}, [@{$_}[0 .. $#{$_}-1]]);
      push(@{$b}, @{$_}[-1]);
    }
    my ($m, $n) = mdim($u);
    
    $$svd = 1 if (defined($svd));
    EMC::Matrix::msvd($u, $m, $n, $w, $v);
    EMC::Matrix::vcut($w, $eps, 0);
    EMC::Matrix::msvdsol($u, $w, $v, $m, $n, $b, $x);
    EMC::Matrix::vround($x, $eps, 0);
    print("sol\t") if ($show);
    EMC::Matrix::vprint($x) if ($show);
    return $x;
  }
  for (my $i=0; $i<scalar(@{$m}); ++$i) {
    my $f = 1; foreach (@{$m->[$i]}) {
      $_ = int($_/$eps+($_<0 ? -0.5 : 0.5))*$eps;
      $f = 0 if (abs($_)>=$eps);
    }
    splice(@{$m}, $i--, 1) if ($f);
  }
  return undef if ($#{$m}!=$ncols-1);
  my $sol = [];
  foreach (@{$m}) { push(@{$sol}, @{$_}[-1]); }
  return EMC::Matrix::vround($sol, $eps, 0);
}


sub minvert {
  my $a = shift(@_);
  my $m = EMC::Matrix::mcopy($a);
  my $nrows = $#{$a};
  my $ncols = $#{$a->[0]};
  my $unit = [];

  if ($nrows!=$ncols) {
    EMC::Message::error("cannot invert non-square matrix.\n");
  }
  EMC::Matrix::vset($unit, $nrows+1, 0);
  for (my $i=0; $i<=$nrows; ++$i)
  {
    $unit->[$i] = 1;
    push(@{$m->[$i]}, @{$unit});
    $unit->[$i] = 0;
  }
  EMC::Matrix::mprint($m);
  return EMC::Matrix::msolve($m, @_);
}


# simple operations

sub SIGN {
  my ($a, $b) = @_[0,1];

  return (($b) >= 0.0 ? abs($a) : -abs($a));
}


sub MAX {
  my ($a, $b) = @_[0,1];

  return $a > $b ? $a : $b;
}


sub MIN {
  my ($a, $b) = @_[0,1];

  return $a < $b ? $a : $b;
}


# Computes (a^2 + b^2)^(1/2) without destructive underflow or overflow.

sub pythag {
  my $a = shift(@_);
  my $b = shift(@_);

  my $absa = abs($a);
  my $absb = abs($b);
  if ($absa > $absb) {
    return $absa*sqrt(1.0+$absb*$absb/($absa*$absa));
  }
  else {
    return ($absb == 0.0 ? 0.0 : $absb*sqrt(1.0+$absa*$absa/($absb*$absb)));
  }
}


# Given a matrix a[1..m][1..n], this routine computes its singular value
# decomposition, A = U ·W ·V T . The matrix U replaces a on output. The
# diagonal matrix of singular values W is output as a vector w[1..n]. 
# The matrix V (not the transpose V T ) is output as v[1..n][1..n].

sub msvd {
  my ($a, $m, $n, $w, $v) = @_[0,1,2,3,4];
  my ($flag, $i, $its, $j, $jj, $k, $l, $nm);
  my ($anorm, $c, $f, $g, $h, $s, $scale, $x, $y, $z);
  my @rv1 = ();

  $g = $scale = $anorm = 0.0;
  for ($i=0; $i<$n; $i++) {
    $l = $i+1;
    @rv1[$i] = $scale*$g;
    $g = $s = $scale = 0.0;	# Householder reduction to bidiagonal form.
    if ($i < $m) {
      for ($k=$i; $k<$m; $k++) {
       	$scale += abs($a->[$k]->[$i]);
      }	
      if ($scale) {
	for ($k=$i; $k<$m; $k++) { 
	  $a->[$k]->[$i] /= $scale;
	  $s += $a->[$k]->[$i]*$a->[$k]->[$i];
	}
	$f = $a->[$i]->[$i];
	$g = -EMC::Matrix::SIGN(sqrt($s),$f);
	$h = $f*$g-$s;
	$a->[$i]->[$i] = $f-$g;
	for ($j=$l; $j<$n; $j++) {
	  for ($s=0.0,$k=$i; $k<$m; $k++) {
	    $s += $a->[$k]->[$i]*$a->[$k]->[$j];
	  }
	  $f = $s/$h;
	  for ($k=$i; $k<$m; $k++) {
	    $a->[$k]->[$j] += $f*$a->[$k]->[$i];
	  }
	}
	for ($k=$i; $k<$m; $k++) {
	  $a->[$k]->[$i] *= $scale;
	}
      }
    }
    $w->[$i] = $scale*$g;
    $g = $s = $scale = 0.0;
    if ($i < $m && $i != $n-1) {
      for ($k=$l; $k<$n; $k++) {
	$scale += abs($a->[$i]->[$k]);
      }
      if ($scale) {
	for ($k=$l; $k<$n; $k++) {
	  $a->[$i]->[$k] /= $scale;
	  $s += $a->[$i]->[$k]*$a->[$i]->[$k];
	}
	$f = $a->[$i]->[$l];
	$g = -EMC::Matrix::SIGN(sqrt($s),$f);
	$h = $f*$g-$s;
	$a->[$i]->[$l] = $f-$g;
	for ($k=$l; $k<$n; $k++) {
	  @rv1[$k] = $a->[$i]->[$k]/$h;
	}
	for ($j=$l; $j<$m; $j++) {
	  for ($s=0.0,$k=$l; $k<$n; $k++) {
	    $s += $a->[$j]->[$k]*$a->[$i]->[$k];
	  }
	  for ($k=$l; $k<$n; $k++) {
	    $a->[$j]->[$k] += $s*@rv1[$k];
	  }
	}
	for ($k=$l; $k<$n; $k++) {
	  $a->[$i]->[$k] *= $scale;
	}
      }
    }
    $anorm = EMC::Matrix::MAX($anorm,(abs($w->[$i])+abs(@rv1[$i])));
  }
  for ($i=$n-1; $i>=0; $i--) {	# Accumulation of right-hand transformations.
    if ($i < $n) {
      if ($g) {
	for ($j=$l; $j<$n; $j++) {
				# Double division to avoid possible underflow.
	  $v->[$j]->[$i] = ($a->[$i]->[$j]/$a->[$i]->[$l])/$g;
	}
	for ($j=$l; $j<$n; $j++) {
	  for ($s=0.0,$k=$l; $k<$n; $k++) {
	    $s += $a->[$i]->[$k]*$v->[$k]->[$j];
	  }
	  for ($k=$l; $k<$n; $k++) {
	    $v->[$k]->[$j] += $s*$v->[$k]->[$i];
	  }
	}
      }
      for ($j=$l; $j<$n; $j++) {
	$v->[$i]->[$j] = $v->[$j]->[$i] = 0.0;
      }
    }
    $v->[$i]->[$i] = 1.0; $g = @rv1[$i]; $l = $i;
  }
  for ($i=EMC::Matrix::MIN($m,$n)-1; $i>=0; $i--) {
				# Accumulation of left-hand transformations.
    $l = $i+1;
    $g = $w->[$i];
    for ($j=$l; $j<$n; $j++) {
      $a->[$i]->[$j] = 0.0;
    }
    if ($g) {
      $g = 1.0/$g;
      for ($j=$l; $j<$n; $j++) {
	for ($s=0.0,$k=$l; $k<$m; $k++) {
	  $s += $a->[$k]->[$i]*$a->[$k]->[$j];
	}
	$f = ($s/$a->[$i]->[$i])*$g;
	for ($k=$i; $k<$m; $k++) {
	  $a->[$k]->[$j] += $f*$a->[$k]->[$i];
	}
      }
      for ($j=$i; $j<$m; $j++) {
	$a->[$j]->[$i] *= $g;
      }
    } else {
      for ($j=$i; $j<$m; $j++) {
	$a->[$j]->[$i] = 0.0;
      }
    }
    ++$a->[$i]->[$i];
  }
  for ($k=$n-1; $k>=0; $k--) {	# Diagonalization of the bidiagonal form:
				# Loop over singular values, and over allowed
				# iterations.
    for ($its=0; $its<30; $its++) {
      $flag = 1;
      for ($l=$k; $l>=0; $l--) {# Test for splitting.
	$nm = $l-1;		# Note that @rv1[0] is always zero.
	if (abs(@rv1[$l])+$anorm == $anorm) {
	  $flag = 0;
	  last;
       	}
	last if (abs($w->[$nm])+$anorm == $anorm);
      }
      if ($flag) {		# Cancellation of @rv1[$l], if $l > 0.
	$c = 0.0; 
	$s = 1.0;
	for ($i=$l; $i<=$k; $i++) {
	  $f = $s*@rv1[$i];
	  @rv1[$i] = $c*@rv1[$i];
	  last if (abs($f)+$anorm == $anorm);
	  $g = $w->[$i];
	  $h = EMC::Matrix::pythag($f,$g);
	  $w->[$i] = $h;
	  $h = 1.0/$h;
	  $c = $g*$h;
	  $s = -$f*$h;
	  for ($j=0; $j<$m; $j++) {
	    $y = $a->[$j]->[$nm];
	    $z = $a->[$j]->[$i];
	    $a->[$j]->[$nm] = $y*$c+$z*$s;
	    $a->[$j]->[$i] = $z*$c-$y*$s;
	  }
       	}
      }
      $z = $w->[$k];
      if ($l == $k) {		# Convergence.
	if ($z < 0.0) {		# Singular value is made nonnegative.
	  $w->[$k] = -$z;
	    for ($j=0; $j<$n; $j++) {
	      $v->[$j]->[$k] = -$v->[$j]->[$k];
	    }
       	}
	last;
      }
      if ($its == 30) {
	return undef; # nrerror("no convergence in 30 svdcmp iterations");
      }
      $x = $w->[$l];		# Shift from bottom 2-by-2 minor.
      $nm = $k-1;
      $y = $w->[$nm];
      $g = @rv1[$nm];
      $h = @rv1[$k];
      $f = (($y-$z)*($y+$z)+($g-$h)*($g+$h))/(2.0*$h*$y);
      $g = EMC::Matrix::pythag($f,1.0);
      $f = (($x-$z)*($x+$z)+$h*(($y/($f+EMC::Matrix::SIGN($g,$f)))-$h))/$x;
      $c = $s =1.0;		# Next QR transformation:
      for ($j=$l; $j<=$nm; $j++) {
	$i = $j+1;
	$g = @rv1[$i];
	$y = $w->[$i];
	$h = $s*$g;
	$g = $c*$g;
	$z = EMC::Matrix::pythag($f,$h);
	@rv1[$j] = $z;
	$c = $f/$z;
	$s = $h/$z;
	$f = $x*$c+$g*$s;
	$g = $g*$c-$x*$s;
	$h = $y*$s;
	$y *= $c;
	for ($jj=0; $jj<$n; $jj++) {
	  $x = $v->[$jj]->[$j];
	  $z = $v->[$jj]->[$i];
	  $v->[$jj]->[$j] = $x*$c+$z*$s;
	  $v->[$jj]->[$i] = $z*$c-$x*$s;
	}
	$z = EMC::Matrix::pythag($f,$h);
       	$w->[$j] = $z;		# Rotation can be arbitrary if z = 0.
	if ($z) {
	  $z = 1.0/$z;
	  $c = $f*$z;
	  $s = $h*$z;
	}
       	$f = $c*$g+$s*$y;
       	$x = $c*$y-$s*$g;
	for ($jj=0; $jj<$m; $jj++) {
	  $y = $a->[$jj]->[$j];
	  $z = $a->[$jj]->[$i];
	  $a->[$jj]->[$j] = $y*$c+$z*$s;
	  $a->[$jj]->[$i] = $z*$c-$y*$s;
	} }
      @rv1[$l] = 0.0;
      @rv1[$k] = $f;
      $w->[$k] = $x;
    }
  }
  return $#{$w}+1;
}


# Solves A·X = B for a vector X, where A is specified by the arrays
#   u[1..m][1..n], w[1..n], v[1..n][1..n] as returned by svdcmp.
#   m and n are the dimensions of a, and will be equal for square matrices.
#   b[1..m] is the input right-hand side.
#   x[1..n] is the output solution vector.
# No input quantities are destroyed, so the routine may be called sequentially
#   with different b’s. 

sub msvdsol {
  my ($u, $w, $v, $m, $n, $b, $x) = @_[0,1,2,3,4,5,6];
  my ($jj, $j, $i);
  my ($s, @tmp);

  for ($j=0; $j<$n; $j++) {	# Calculate UT B.
    $s = 0.0;
    if ($w->[$j]) {		# Nonzero result only if wj is nonzero. 
      for ($i=0; $i<$m; $i++) {
	$s += $u->[$i]->[$j]*$b->[$i];
      }
      $s /= $w->[$j];		# This is the divide by wj .
    }
    @tmp[$j] = $s; 
  }
  for ($j=0; $j<$n; $j++) {	# Matrix multiply by V to get answer.
    $s = 0.0;
    for ($jj=0; $jj<$n; $jj++) {
      $s += $v->[$j]->[$jj]*@tmp[$jj];
    }
    $x->[$j] = $s;
  }
}


# test SVD with singular matrix for bond increments of a ring structure

sub mtest {
  my $N = 0;
  my ($wmax, $wmin);
  my $a = [
    [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    [0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]];
  my ($m, $n) = ($#{$a}+1, $#{$a->[0]}+1);
  my $b = [
    0.34, -0.07, 0.510 - 0.470, -0.57 + 0.39, 0, -0.49 + 0.36, 
    0, 0, 0, 0, 0, 0, 0];
  my ($u, $w, $v, $x) = ([], [], [], []);
  my ($i, $j);

  for($i=0; $i<$m; $i++) {	# Copy a into u if you don’t want it to be
    for ($j=0; $j<$n; $j++) {	# destroyed
      $u->[$i]->[$j] = $a->[$i]->[$j];
    }
  }
  msvd($u,$m,$n,$w,$v);		# SVD the square matrix a.
  $wmax = 0.0;			# Will be the maximum singular value obtained.
  for($j=0; $j<$n; $j++) {
    if ($w->[$j] > $wmax) {
      $wmax = $w->[$j];
    }
  }
  
  # This is where we set the threshold for singular values allowed to be
  # nonzero. The constant is typical, but not universal. You have to
  # experiment with your own application.

  $wmin = $wmax*1.0e-6;
  for($j=0; $j<$n; $j++) {
    if ($w->[$j] < $wmin) {
      $w->[$j] = 0.0;
    }
  }
  msvdsol($u,$w,$v,$m,$n,$b,$x);# Now we can backsubstitute.
  dprint("x", $x);
}

