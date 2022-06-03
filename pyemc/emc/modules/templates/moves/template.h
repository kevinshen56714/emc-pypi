/*
    program:	template.h
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	Header file for template.c

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#ifdef __MOVE_ID
MoveID(TEMPLATE, MovesTemplate, template)
#else
#ifndef __MOVES_TEMPLATE_HEADER
#define __MOVES_TEMPLATE_HEADER

#include "core/accept.h"
#include "core/default.h"

// module-independent type definitions
  
typedef
  struct moves_template {
    long		frequency;
    long		n;				// storage
    //double		*dmax;
    struct accept	*accept, *next;			// acceptance
    long		defined, initialized, clone;	// internal 
    move_function	check;				// mandatory
    void_function_2	units;
    size_t		size;				// memory usage
  } __moves_template;

#ifdef __MOVES_TEMPLATE_MODULE

#include "core/default.h"
#include "core/message.h"
#include "core/parse.h"

#define MODULE		"template"
#define MOVES_TEMPLATE_MAGIC	0.5
#define MOVES_TEMPLATE_NCHECK	10000

// parse transcriptions

#define NHEADERS	1
#define HEADERS		{"(* MovesTemplate *)"}

/*
#define PARSE_NVARS	4
#define PARSE_N		{1, 1, -1, -1}
#define PARSE_NAME	{"frequency", "n", "dmax", "accept"}
#define PARSE_VAR(x)	{&x.frequency, &x.n, x.dmax, x.accept}
#define PARSE_READ	{LongRead,(fparse)MovesTemplateNRead,DoubleRead,AcceptRead}
#define PARSE_WRITE	{LongWrite, LongWrite, DoubleWrite, AcceptWrite}
#define ACCEPT		PARSE_NVARS-1
#define DMAX		ACCEPT-1
*/

#define PARSE_NVARS	3
#define PARSE_N		{1, 1, -1}
#define PARSE_NAME	{"frequency", "n", "accept"}
#define PARSE_VAR(x)	{&x.frequency, &x.n, x.accept}
#define PARSE_READ	{LongRead, (fparse)MovesTemplateNRead, AcceptRead}
#define PARSE_WRITE	{LongWrite, LongWrite, AcceptWrite}
#define ACCEPT		PARSE_NVARS-1

// module-specific variable and type definitions

struct moves_template	*MovesTemplate;

#else

#include "core/parse.h"
#include "core/format.h"
#include "core/simulation.h"
#include "core/units.h"

// shared variables

// struct modifiers

extern struct moves_template
  *MovesTemplateConstruct(long n);
extern struct moves_template
  *MovesTemplateDestruct(struct moves_template *template, long n);

// struct size

extern size_t
  MovesTemplateSize(struct moves_template *template, long n);

// struct operators

extern struct moves_template
  *MovesTemplateCopy(struct moves_template *dest, struct moves_template *src);
extern struct moves_template
  *MovesTemplateAdd(struct moves_template *dest, struct moves_template *src);
extern struct moves_template
  *MovesTemplateSubtr(struct moves_template *dest, struct moves_template *src);

// struct initialization

extern struct moves_template
  *MovesTemplateCreate(struct moves_template *template, long n);
extern struct moves_template
  *MovesTemplateReset(struct moves_template *template);
extern struct moves_template
  *MovesTemplateFactory(struct moves_template *template);
extern void
  MovesTemplateInit(struct simulation *simulation);

// struct i/o

extern char
  *MovesTemplateHeader(long version);
extern long
  MovesTemplateRead(struct format *format, const void *template, long i);
extern long
  MovesTemplateWrite(struct format *format, const void *template, long i);

// struct move

extern void
  MovesTemplateMove(struct simulation *simulation);

#endif

#endif

#endif

