/*
    program:	template.c
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	Template descriptors

    notes:	Copyrights (2021) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#define TEMPLATE_MODULE
#include "split.h"

// struct modifiers

struct template *TemplateAssign(
    struct template *ptr, long n)
{
  struct template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);

  memset(ptr, 0, abs(n)*sizeof(struct template));
  for (; iptr<nptr; ++iptr)
  {
#define	PTR_OPER(Oper, VAR, type, var, nvars) \
    iptr->var		= Oper##Construct(nvars);
    PTR_OPER_LIST;
#undef	PTR_OPER
  }
  return ptr;
}


struct template *TemplateConstruct(long n)
{
  struct template
    *ptr		= malloc(abs(n)*sizeof(struct template));
  
  if (!ptr) Error(MODULE"::TemplateConstruct: calloc error.\n");
  return TemplateAssign(ptr, n);
}


struct template *TemplateDestruct(
    struct template *ptr, long n)
{
  if (!ptr) return NULL;

  struct template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);

  for (; iptr<nptr; ++iptr)
  {
#define	PTR_OPER(Oper, VAR, type, var, nvars) \
    iptr->var		= Oper##Destruct(iptr->var, nvars);
    PTR_OPER_LIST;
#undef	PTR_OPER
  }
  if (n<0) return TemplateAssign(ptr, n);
  free(ptr);
  return NULL;
}


// struct size

size_t TemplateSize(struct template *ptr, long n)
{
  if (!(ptr&&n)) return 0;

  size_t
    size		= 0;
  struct template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);

  for (; iptr<nptr; ++iptr)
  {
#define	PTR_OPER(Oper, VAR, type, var, nvars) \
    size		+= Oper##Size(iptr->var, nvars);
    PTR_OPER_LIST;
#undef	PTR_OPER
  }
  return n<0 ? size-n*sizeof(struct template) : size;
}


// struct operators

struct template *TemplateCopy(
    struct template *dest, struct template *src)
{
  long
    i;

  if (!dest) dest	= TemplateConstruct(1);
  else dest		= TemplateDestruct(dest, -1);
#define	PTR_OPER(Oper, VAR, type, var, nvars) \
  type *var		= dest->var;
  PTR_OPER_LIST;
#undef	PTR_OPER
  memcpy(dest, src, sizeof(struct template));
#define	PTR_OPER(Oper, VAR, type, var, nvars) \
  dest->var		= var; \
  for (i=0; i<nvars; ++i) Oper##Copy(dest->var+i, src->var+i);
  PTR_OPER_LIST;
#undef	PTR_OPER
  return dest;
}


// struct i/o

long TemplateRead(
    struct format *format, struct template *ptr, long i)
{
  ptr			+= i;
#define	PARSE_OPER(Oper, VAR, var, string, nvars, ampersand) ampersand ptr->var,
  const void
    *var[]		= {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER
  
  ++format->target;
  parse.variable	= var;
  parse.function	= parse_read;
  return ptr->defined	= ParseRead(format, &parse);
}


long TemplateWrite(
    struct format *format, struct template *ptr, long i)
{
  ptr			+= i;
#define	PARSE_OPER(Oper, VAR, var, string, nvars, ampersand) ampersand ptr->var,
  const void
    *var[]		= {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER

  parse.variable	= var;
  parse.function	= parse_write;
  if (format->bin) return ParseWrite(format, &parse);
  FormatWrite(format, "\n%s{", format->buffer);
  if (!ParseWrite(format, &parse)) return 0;
  strcat(format->buffer, "}");
  return 1;
}


// struct initialization

void TemplateUnits(
    struct template *template, struct units *units)
{
}


void TemplateInit(struct simulation *simulation)
{
}


// struct application

void Template(
    struct simulation *simulation, struct template *template)
{
}

