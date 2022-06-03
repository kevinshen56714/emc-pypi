/*
    program:	script_sample_template.c
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	ScriptSampleTemplate descriptors

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#define __SCRIPT_SAMPLE_TEMPLATE_MODULE
#include "template.h"

// struct modifiers

struct script_sample_template *ScriptSampleTemplateAssign(
    struct script_sample_template *ptr, long n)
{
  struct script_sample_template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);

  memset(ptr, 0, abs(n)*sizeof(struct script_sample_template));
  for (; iptr<nptr; ++iptr) SamplesTemplateFactory(iptr);
  return ptr;
}


struct script_sample_template *ScriptSampleTemplateConstruct(long n)
{
  struct script_sample_template
    *ptr		= malloc(abs(n)*sizeof(struct script_sample_template));
  
  if (!ptr)
    Error(MODULE"::ScriptSampleTemplateConstruct: calloc error.\n");
  return ScriptSampleTemplateAssign(ptr, n);
}


// struct size

// struct operators

// struct i/o

long ScriptSampleTemplateRead(
    struct format *format, struct script_sample_template *ptr, long i)
{
  ptr			+= i;

  void
    **ivar, **istore,
    *store[]		= PARSE_IGNORE(ptr[0]),
    *var[]		= PARSE_IGNORE(ptr[0]);
  long
    ndists		= ptr->ndists;

  ivar			= var;
  istore		= store;
  while (*ivar)
  {
    *(istore++)		= **((void ***) ivar);
    **((void ***)ivar++) = NULL;
  }
  ptr->ndists	= 0;
  i			= SamplesTemplateRead(format, ptr, i);
  ivar			= var;
  istore		= store;
  while (*ivar)
    **((void ***)ivar++) = *(istore++);
  ptr->ndists		= ndists;
  return i;
}


long ScriptSampleTemplateWrite(
    struct format *format, struct script_sample_template *ptr, long i)
{
  ptr			+= i;

  void
    **ivar, **istore,
    *store[]		= PARSE_IGNORE(ptr[0]),
    *var[]		= PARSE_IGNORE(ptr[0]);
  
  ivar			= var;
  istore		= store;
  while (*ivar)
  {
    *(istore++)		= **((void ***) ivar);
    **((void ***)ivar++) = NULL;
  }
  i			= SamplesTemplateWrite(format, ptr, i);
  ivar			= var;
  istore		= store;
  while (*ivar)
    **((void ***)ivar++) = *(istore++);
  return i;
}


// struct initialization

void ScriptSampleTemplateInit(
    struct simulation *simulation, struct script_sample_template *script_template)
{
  struct samples_template
    *template		= simulation->samples->template;

  template->active	= script_template->active;
  template->frequency	= script_template->frequency;
}

