/*
Cephes Math Library Release 2.7:  March, 1998
Copyright 1984, 1998 Stephen L. Moshier
*/
#ifndef __STUBS_HEADER
#define __STUBS_HEADER

#ifdef __STUBS_MODULE

#include <stdio.h>
#include "mconf.h"

int dprec() {return 0;}
int ldprec() {return 0;}

double MINLOG = -170.0;
double MAXLOG = +170.0;
double PI = 3.14159265358979323846;
double PIO2 = 1.570796326794896619;
double MAXNUM = 1.0e308;
double MACHEP = 1.1e-16;
double INFINITY = 1.0/0.0;
long double PIL = 3.141592653589793238462643383279502884197169L;
long double PIO2L = 1.570796326794896619231321691639751442098585L;

#if 1
/* For Intel x86 or Motorola 68881 */
/* almost 2^16384 */
long double MAXNUML = 1.189731495357231765021263853E4932L;
/* 2^-64 */
long double MACHEPL = 5.42101086242752217003726400434970855712890625E-20L;
#else
/* For IEEE quad precision */
/* (1 - 2^-113) 2^16384 */
long double MAXNUML = 1.189731495357231765085759326628007016196469e4932L;
/* 2^-113 */
long double MACHEPL = 9.629649721936179265279889712924636592690508e-35L;
#endif

int sprec() {return 0;}
float PIF = 3.14159265358979323846F;
float PIO2F =  1.570796326794896619F;
float MAXNUMF = 1.0e38F;
float MACHEPF = 3.0e-8F;

#endif

#endif

