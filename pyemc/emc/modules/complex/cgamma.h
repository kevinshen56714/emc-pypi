/*
Cephes Math Library Release 2.7:  March, 1998
Copyright 1984, 1998 Stephen L. Moshier
*/
#ifndef __CGAMMA_HEADER
#define __CGAMMA_HEADER

#ifdef __CGAMMA_MODULE

#include "complex.h"
#include "mconf.h"

#define MAXGAM 171.624376956302725
static double LOGPI = 1.14472988584940017414;

/* Stirling's formula for the gamma function */
#define NSTIR 7
static double STIR[ NSTIR ] = {
#if 0
 7.20489541602001055909E-5,
 8.39498720672087279993E-4,
-5.17179090826059219337E-5,
#endif
-5.92166437353693882865E-4,
 6.97281375836585777429E-5,
 7.84039221720066627474E-4,
-2.29472093621399176955E-4,
-2.68132716049382716049E-3,
 3.47222222222222222222E-3,
 8.33333333333333333333E-2
};
#define MAXSTIR 143.01608

/* Asymptotic expansion of log gamma  */
static double A[] = {
#if 0
-1.3924322169059011164274322169059011164274E0,
 1.7964437236883057316493849001588939669435E-1,
-2.9550653594771241830065359477124183006536E-2,
 6.4102564102564102564102564102564102564103E-3,
#endif
-1.9175269175269175269175269175269175269175E-3,
 8.4175084175084175084175084175084175084175E-4,
-5.9523809523809523809523809523809523809524E-4,
 7.9365079365079365079365079365079365079365E-4,
-2.7777777777777777777777777777777777777778E-3,
 8.3333333333333333333333333333333333333333E-2
};
/* log( sqrt( 2*pi ) ) */
static double LS2PI  =  0.91893853320467274178;
#define MAXLGM 2.556348e305

static double SQTPI = 2.50662827463100050242E0;

extern double MAXLOG, MAXNUM, PI;
#ifdef ANSIPROT
extern double sinh (double);
extern double cosh (double);
extern double sin (double);
extern double cos (double);
extern double fabs (double);
extern double cabs (double complex);
#else
double log(), sin(), polevl(), p1evl(), floor(), fabs();
double sinh(), cosh(), cos();
double complex cpow(), cexp(), cabs();
#endif

#endif

#endif

