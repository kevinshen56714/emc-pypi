/*
    program:	template.h
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	Header file for template.c

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#ifdef	__MODULE_SET
#undef	__MODULE_SET

#define	CONST_OPER_LIST \
  CONST_OPER(NAME, name, 4)

#elif	defined(__MODULE_UNSET)
#undef	__MODULE_UNSET

#undef	CONST_OPER_LIST
#undef	CONST_OPER

#elif	!defined(__TEMPLATE_HEADER)
#define __TEMPLATE_HEADER

#include <unistd.h>

// module-independent type definitions

#define	__MODULE_SET
#include "template.h"

#define	CONST_OPER(NAME, name, length)	TEMPLATE_##NAME,
enum{TEMPLATE_NONE = -1, CONST_OPER_LIST TEMPLATE_NCONSTANTS};
#undef	CONST_OPER_LIST
#undef	CONST_OPER

#define	__MODULE_UNSET
#include "template.h"

#ifdef __TEMPLATE_MODULE

#include "core/constant.hh"
#include "core/message.h"
#include "core/parse.h"

#define MODULE		"template"

// parse transcriptions

// module-specific variable definitions

#else

// shared variables

// struct modifiers

// struct size

// struct operators

// struct i/o

extern long
  TemplateRead(
      struct format *format, const void *ptr, long i);
extern long
  TemplateWrite(
      struct format *format, const void *ptr, long i);

// struct initialization

// struct application

#endif

#endif

