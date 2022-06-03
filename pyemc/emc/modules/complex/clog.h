/*
Cephes Math Library Release 2.7:  March, 1998
Copyright 1984, 1998 Stephen L. Moshier
*/
#ifndef __CLOG_HEADER
#define __CLOG_HEADER

#ifdef __CLOG_MODULE

#include "complex.h"
#include "mconf.h"

#ifdef ANSIPROT
static void cchsh ( double x, double *c, double *s );
static double redupi ( double x );
static double ctans ( double complex z );
#else
static void cchsh();
static double redupi();
static double ctans();
double cabs(), fabs(), sqrt();
double log(), exp(), atan2(), cosh(), sinh();
double asin(), sin(), cos();
#endif

extern double MAXNUM, MACHEP, PI, PIO2;

#endif

#endif

