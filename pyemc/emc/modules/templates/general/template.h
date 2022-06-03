/*
    program:	template.h
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	Header file for template.c

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#ifndef __TEMPLATE_HEADER
#define __TEMPLATE_HEADER

#include <unistd.h>

// module-independent type definitions
  
typedef
  struct template {
    long		dependents;
    struct list_long	*list;
    long		defined, initialized;
    size_t		size;
  } __template;

#include "core/format.h"
#include "core/simulation.h"

#ifdef __TEMPLATE_MODULE

#include "core/default.h"
#include "core/list/long.h"
#include "core/message.h"
#include "core/parse.h"

#define MODULE		"template"
#define	IDENTIFIER	"template::Template"

#define PTR_OPER_LIST \
  PTR_OPER(ListLong, struct list_long, LIST, list, 1)

// parse transcriptions

#define NHEADERS	1
#define HEADERS		{"(* Template *)"}

#define PARSE_OPER_LIST \
  PARSE_OPER(Long, DEPENDENTS, dependents, dependents, 1, &)

#define	PARSE_OPER(Oper, VAR, var, string, nvars, ampersand) PARSE_##VAR,
enum{PARSE_OPER_LIST PARSE_NVARS};
#undef	PARSE_OPER

#define	PARSE_OPER(Oper, VAR, var, string, nvars, ampersand) nvars,
static long parse_n[] = {PARSE_OPER_LIST 0};
#undef	PARSE_OPER

#define PARSE_OPER(Oper, VAR, var, string, nvars, ampersand) #var,
static char *parse_name[] = {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER

#define PARSE_OPER(Oper, VAR, var, string, nvars, ampersand) Oper##Read,
static fparse parse_read[] = {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER

#define PARSE_OPER(Oper, VAR, var, string, nvars, ampersand) Oper##Write,
static fparse parse_write[] = {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER

static struct parse
  parse			= {PARSE_NVARS, parse_n, parse_name, NULL, NULL};

// module-specific variable definitions

#else

// shared variables

// struct modifiers

extern struct template
  *TemplateConstruct(long n);
extern struct template
  *TemplateDestruct(struct template *ptr, long n);
extern struct template
  *TemplateAssign(struct template *ptr, long n);

// struct size

extern size_t
  TemplateSize(struct template *ptr, long n);

// struct operators

extern struct template
  *TemplateCopy(
      struct template *dest, struct template *src);
extern struct template
  *TemplateAdd(
      struct template *dest, struct template *src);
extern struct template
  *TemplateSubtr(
      struct template *dest, struct template *src);

// struct i/o

extern long
  TemplateRead(
      struct format *format, const void *ptr, long i);
extern long
  TemplateWrite(
      struct format *format, const void *ptr, long i);

// struct initialization

extern void
  TemplateUnits(
      struct template *template, struct units *units);
extern void
  TemplateInit(struct simulation *simulation);

#endif

#endif

