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

#ifdef __TEMPLATE_MODULE

#include "core/default.h"
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

// struct initialization

// struct application

#endif

#endif

