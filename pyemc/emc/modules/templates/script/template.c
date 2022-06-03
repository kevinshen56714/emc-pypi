/*
    program:	script_template.c
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	ScriptTemplate descriptors

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#define __SCRIPT_TEMPLATE_MODULE
#include "template.h"

#define	__SCRIPT_TEMPLATE_ID

// struct modifiers

struct script_template
  *ScriptTemplateAssign(struct script_template *ptr, long n)
{
  struct script_template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);

  memset(ptr, 0, abs(n)*sizeof(struct script_template));
  for (; iptr<nptr; ++iptr)
  {
#define	ScriptTemplateID(MODULE, Module, module) \
    iptr->module	= ScriptTemplate##Module##Construct(1);
#include "template/header.h"
#undef	ScriptTemplateID

    // insert dependents here

    iptr->defined	= 1;
  }
  return ptr;
}


struct script_template *ScriptTemplateConstruct(long n)
{
  struct script_template
    *ptr		= malloc(abs(n)*sizeof(struct script_template));
  
  if (!ptr) Error(MODULE"::ScriptTemplateConstruct: calloc error.\n");
  return ScriptTemplateAssign(ptr, n);
}


struct script_template
  *ScriptTemplateDestruct(struct script_template *ptr, long n)
{
  if (!ptr) return NULL;

  struct script_template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);

  for (; iptr<nptr; ++iptr)
  {
#define	ScriptTemplateID(MODULE, Module, module) \
    iptr->module	= ScriptTemplate##Module##Destruct(iptr->module, 1);
#include "template/header.h"
#undef	ScriptTemplateID

    // insert dependents here

  }
  if (n<0) return ScriptTemplateAssign(ptr, n);
  free(ptr);
  return NULL;
}


// struct size

size_t ScriptTemplateSize(struct script_template *ptr, long n)
{
  struct script_template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);
  size_t
    size		= 0;
  
  if (!ptr) return 0;
  for (; iptr<nptr; ++iptr)
  {
#define	ScriptTemplateID(MODULE, Module, module) \
    size		+= ScriptTemplate##Module##Size(iptr->module, 1);
#include "template/header.h"
#undef	ScriptTemplateID

    // insert dependents here

  }
  if (n>0) size		+= sizeof(struct script_template)*abs(n);
  return size;
}


// struct operators

struct script_template *ScriptTemplateCopy(
    struct script_template *dest, struct script_template *src)
{
  if (!dest) dest	= ScriptTemplateConstruct(1);
  else dest		= ScriptTemplateDestruct(dest, -1);
#define	ScriptTemplateID(MODULE, Module, module) \
  void *module		= dest->module;
#include "template/header.h"
#undef	ScriptTemplateID

  // insert dependents here

  memcpy(dest, src, sizeof(struct script_dendrimer));

#define	ScriptTemplateID(MODULE, Module, module) \
  if (src->module) \
    dest->module	= ScriptTemplate##Module##Copy(module, src->module);
#include "template/header.h"
#undef	ScriptTemplateID

  // insert dependents here

  return dest;
}


// struct i/o

#include "core/constant.hh"

CONSTANT_IO(static, ScriptTemplateStyle, CONSTANTS, NCONSTANTS)

static char
  *parse_name[PARSE_NVARS]	= PARSE_NAME;
static long
  parse_n[PARSE_NVARS]		= PARSE_N;
static struct parse 
  parse 			= {PARSE_NVARS,parse_n,parse_name,NULL,NULL};

static parse_function
  parse_read[PARSE_NVARS]	= PARSE_READ;

long ScriptTemplateRead(
    struct format *format, struct script_template *ptr, long i)
{
  if (!(ptr			+= i)->defined)
    ScriptTemplateAssign(template, 1);

  const void
    *var[PARSE_NVARS]		= PARSE_VAR(ptr[0]);
  
  ++format->target;
  parse.variable		= var;
  parse.function		= parse_read;
  return ParseRead(format, &parse);
}


static parse_function
  parse_write[PARSE_NVARS]	= PARSE_WRITE;

long ScriptTemplateWrite(
    struct format *format, struct script_template *ptr, long i)
{
  ptr				+= i;

  const void
    *var[PARSE_NVARS]		= PARSE_VAR(ptr[0]);
  
  parse.variable		= var;
  parse.function		= parse_write;
  if (format->bin) return ParseWrite(format, &parse);
  FormatWrite(format, "%s{", format->buffer);
  if (!ParseWrite(format, &parse)) return 0;
  strcat(format->buffer, "}");
  return 1;
}


// struct application

struct simulation *ScriptTemplate(
    struct simulation *simulation, struct script_template *ptr,
    struct script *script)
{
  if (!simulation) return NULL;
  ScriptInfo(script);
  //while (script->parent) script = script->parent;
  //ScriptCopy(simulation->script, script);
  return simulation;
}

#undef	__SCRIPT_TEMPLATE_ID

