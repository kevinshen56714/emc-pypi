/*
    program:	script_template.h
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	Header file for script_template.c

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#ifdef __SCRIPT_ID
ScriptID(ScriptTemplate, script_template, template)
#else
#ifndef __SCRIPT_TEMPLATE_HEADER
#define __SCRIPT_TEMPLATE_HEADER

// module-independent type definitions
  
typedef
  struct script_template {
#define __SCRIPT_TEMPLATE_ID
#define ScriptTemplateID(MODULE, Module, module) \
    struct script_template_##module	*module;
#include "template/header.h"
#undef	ScriptTemplateID
#undef	__SCRIPT_TEMPLATE_ID
    long		style, dependencies;
    long		defined;
  } __script_template;

#ifdef __SCRIPT_TEMPLATE_MODULE

#include "core/default.h"
#include "core/message.h"
#include "core/parse.h"
#include "core/script.h"

#define MODULE		"script_template"

// parse transcriptions

#define PARSE_NVARS	2
#define PARSE_N		{1, 1}
#define PARSE_NAME	{"style", "dependencies"}
#define PARSE_VAR(x)	{&x.style, &x.dependencies}
#define PARSE_READ	{(fparse)ScriptTemplateStyleRead, LongRead}
#define PARSE_WRITE	{(fparse)ScriptTemplateStyleWrite, LongWrite}

// module-specific variable definitions

enum{SCRIPT_TEMPLATE_CONST, NCONSTANTS};

#define CONSTANTS	{ \
  {"const", 5, SCRIPT_TEMPLATE_CONST}}

#else

#include "core/format.h"
#include "core/simulation.h"

// shared variables

// struct modifiers

extern struct script_template
  *ScriptTemplateConstruct(long n);
extern struct script_template
  *ScriptTemplateDestruct(struct script_template *script_template, long n);
extern struct script_template
  *ScriptTemplateAssign(struct script_template *script_template, long n);

// struct size

extern size_t
  ScriptTemplateSize(struct script_template *script_template, long n);

// struct operators

extern struct script_template
  *ScriptTemplateCopy(
      struct script_template *dest, struct script_template *src);

// struct i/o

extern long
  ScriptTemplateRead(
      struct format *format, const void *script_template, long i);
extern long
  ScriptTemplateWrite(
      struct format *format, const void *script_template, long i);

// struct application

extern struct simulation
  *ScriptTemplate(
      struct simulation *simulation, struct script_template *script_template,
      struct script *script);

#endif

#endif

#endif

