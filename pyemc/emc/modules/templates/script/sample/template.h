/*
    program:	script_sample_template.h
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	Header file for script_sample_template.c

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#ifdef	__SCRIPT_SAMPLE_ID
ScriptSampleID(TEMPLATE, Template, template)
#else
#ifndef __SCRIPT_SAMPLE_TEMPLATE_HEADER
#define __SCRIPT_SAMPLE_TEMPLATE_HEADER

#include <unistd.h>

// module-independent type definitions
  
#define	script_sample_template samples_template

#define	ScriptSampleTemplateDestruct	SamplesTemplateDestruct
#define	ScriptSampleTemplateSize		SamplesTemplateSize
#define	ScriptSampleTemplateCopy		SamplesTemplateCopy

#ifdef __SCRIPT_SAMPLE_TEMPLATE_MODULE

#include "core/message.h"
#include "core/samples.h"
#include "core/samples/template.h"

#define MODULE		"script_sample_template"

#define PARSE_IGNORE(x)	{&x.dist, NULL}

// parse transcriptions

// module-specific variable definitions

#else

#include "core/format.h"
#include "core/simulation.h"

// shared variables

// struct modifiers

extern struct script_sample_template
  *ScriptSampleTemplateConstruct(long n);

// struct size

// struct operators

// struct i/o

extern long 
  ScriptSampleTemplateRead(struct format *format, const void *template, long i);
extern long 
  ScriptSampleTemplateWrite(struct format *format, const void *template, long i);

// struct initialization

extern void
  ScriptSampleTemplateInit(
      struct simulation *simulation, struct script_sample_template *template);

#endif

#endif

#endif

