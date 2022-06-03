/*							cgamma
 *
 *	Complex gamma function
 *
 *
 *
 * SYNOPSIS:
 *
 * #include <complex.h>
 * double complex x, y, cgamma();
 *
 * y = cgamma( x );
 *
 *
 *
 * DESCRIPTION:
 *
 * Returns complex-valued gamma function of the complex argument.
 * This variable is also filled in by the logarithmic gamma
 * function clgam().
 *
 * Arguments |x| < 18 are increased by recurrence.
 * Large arguments are handled by Stirling's formula. Large negative
 * arguments are made positive using the reflection formula.  
 *
 *
 * ACCURACY:
 *
 *                      Relative error:
 * arithmetic   domain     # trials      peak         rms
 *    IEEE      -20,20      500000      2.0e-14     2.7e-15
 *    IEEE     -100,100     100000      1.4e-13     1.5e-14
 *
 * Error for arguments outside the test range will be larger
 * owing to error amplification by the exponential function.
 *
 */
/*							clgam
 *
 *	Natural logarithm of complex gamma function
 *
 *
 *
 * SYNOPSIS:
 *
 * #include <complex.h>
 * double complex x, y, clgam();
 *
 * y = clgam( x );
 *
 *
 *
 * DESCRIPTION:
 *
 * Returns the base e (2.718...) logarithm of the complex gamma
 * function of the argument.
 *
 * The logarithm of the gamma function is approximated by the
 * logarithmic version of Stirling's asymptotic formula.
 * Arguments of real part less than 14 are increased by recurrence.
 * The cosecant reflection formula is employed for arguments
 * having real part less than -14.
 *
 * Arguments greater than MAXLGM return MAXNUM and an error
 * message.  MAXLGM = 2.556348e305 for IEEE arithmetic.
 *
 *
 *
 * ACCURACY:
 *
 *
 * arithmetic   domain     # trials      peak         rms
 *    IEEE      -20,20      500000      1.4e-14     4.5e-16
 *    IEEE     -100,100     100000                  1.6e-16
 * The error criterion was relative when the function magnitude
 * was greater than one but absolute when it was less than one.
 */
/*
Cephes Math Library Release 2.7:  March, 1998
Copyright 1984, 1998 Stephen L. Moshier
*/
#define __CGAMMA_MODULE
#include "cgamma.h"

/* Gamma function computed by Stirling's formula.  */

/* static double complex cstirf(x) */
double complex cstirf(x)
double complex x;
{
double complex y, w;
int i;

w = 1.0/x;

y = STIR[0];
for (i = 1; i < NSTIR; i++)
  {
    y = y * w + STIR[i];
  }

w = 1.0 + w * y;
#if 1
y = cpow( x, x - 0.5 ) * cexp(-x);
#else
y = (x - 0.5) * clog(x) - x;
y = cexp(y);
#endif
y = SQTPI * y * w;
return( y );
}



double complex cgamma(x)
double complex x;
{
double p, q;
double complex c, u;
int k;

if (fabs(creal(x)) > 18.0)
	{
	if( creal(x) < 0.0 )
		{
		q = creal(x);
		p = floor(q);
		if((p == q) && (cimag(x) == 0.0))
			{
			mtherr( "cgamma", OVERFLOW );
			return( MAXNUM + I * MAXNUM);
			}
		/*		c = csin( PI * x ); */
		/* Compute sin(pi x)  */
		k = q - 2.0 * floor (0.5 * q);
		q = PI * (q - p);
		p = PI * cimag(x);
		c = sin(q) * cosh(p) + cos(q) * sinh(p) * I;
		if (k & 1)
		  c = -c;
		/* Reflection formula.  */
		c = PI/(c * cgamma(1.0 - x) );
		}
	else
		{
		c = cstirf(x);
		}
	return( c );
	}

c = 1.0;
p = 0.0;
u = x;
while( creal(u) < 18.0 )
	{
	if ((fabs(creal(u)) < 1.0e-9) && (fabs(cimag(u)) < 1.0e-9))
		goto small;
	c *= u;
	p += 1.0;
	u = x + p;
	}
u = cstirf(u);
return( u / c );


small:
if((creal(x) == 0.0) && (cimag(x) == 0.0))
	{
	mtherr( "cgamma", SING );
	return( MAXNUM + MAXNUM * I );
	}
else
	return( 1.0/(((1.0 + 0.5772156649015329 * u) * u)*c) );
}





/* Logarithm of gamma function */

double complex clgam(x)
double complex x;
{
double p, q, a;
double complex c, w, u, v;
int i, cj;

cj = 0;
if (cimag(x) < 0)
  {
    cj = 1;
    x = conj(x);
  }

/* Reflection formula -z gamma(-z) gamma(z) = pi / sin(pi z) */
if((creal(x) < -14.0) || (cimag(x) < -14.0))
	{
	q = creal(x);
	p = floor(q);
	if( p == q )
		goto loverf;
	if (fabs(cimag(x)) > 36.7)
	  {
	    /* sin z grows exponentially with Im(z).  Find ln sin(pi z)
	       from |sin z| = sqrt( sin^2 x + sinh^2 y),
               arg sin z = arctan(tanh y / tan x).  */
	    c = PI * cimag(x) - 0.6931471805599453094
	      + I * PI * (0.5 - q);
	    c = LOGPI - c - clgam(1.0 - x);
	  }
	else
	  {
	    /* Reduce sine arg mod pi.  */
	    u = csin( PI * (x - p) );
	    if( u == 0.0 )
	      goto loverf;
	    w = clgam(1.0 - x);
	    c = LOGPI - clog( u ) - w;
	    /* Adjust for reduced sine arg.  */
	    c += I * (PI * p);
	  }
	goto ldone;
	}
w = 0.0;
if(creal(x) < 14.0 )
	{
	  /* To satisfy Im {clgam(z)} = arg cgamma(z), accumulate
	     arg u during the recurrence.  */
	  a = 0.0;
	  w = 1.0;
	  p = 0.0;
	  u = x;
	  while( creal(u) < 14.0 )
		{
		if( u == 0.0 )
			goto loverf;
		w *= u;
		a += carg(u);
		p += 1.0;
		u = x + p;
		}
	x = u;
	w = -log(cabs(w)) - I * a;
	}

if( creal(x) > MAXLGM )
	{
loverf:
	mtherr( "clgam", OVERFLOW );
	c = MAXNUM + MAXNUM * I;
	goto ldone;
	}

c = ( x - 0.5 ) * clog(x) - x + LS2PI + w;

if( cabs(x) > 1.0e8 )
  goto ldone;

v = 1.0/(x*x);
u = A[0];
for (i = 1; i < 6; i++)
  {
    u = u * v + A[i];
  }
c = c + u / x;

ldone:
if (cj)
  c = conj(c);
return( c );
}
