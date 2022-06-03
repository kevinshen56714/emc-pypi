/*
Cephes Math Library Release 2.3:  March, 1995
Copyright 1984, 1995 by Stephen L. Moshier
*/
#ifndef __CMPLX_HEADER
#define __CMPLX_HEADER

#ifdef __CMPLX_MODULE

#include "complex.h"
#include "mconf.h"

#ifndef ANSIPROT
double fabs(), cabs(), sqrt(), atan2(), cos(), sin();
double sqrt(), frexp(), ldexp();
#endif

int isnan();

extern double MAXNUM, MACHEP, PI, PIO2, INFINITY;
double complex czero = 0.0;
double complex cone = 1.0;

#ifdef UNK
#define PREC 27
#define MAXEXPD 1024
#define MINEXPD -1077
#endif
#ifdef DEC
#define PREC 29
#define MAXEXPD 128
#define MINEXPD -128
#endif
#ifdef IBMPC
#define PREC 27
#define MAXEXPD 1024
#define MINEXPD -1077
#endif
#ifdef MIEEE
#define PREC 27
#define MAXEXPD 1024
#define MINEXPD -1077
#endif

#endif

#endif

