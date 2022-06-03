/*
    program:	template.c
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	Template descriptors

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#define __TEMPLATE_MODULE
#include "template.h"

// struct modifiers


// struct size


// struct operators


// struct i/o

#define	__MODULE_SET
#include "template.h"

#define CONST_OPER(NAME, name, length)	{#name, length, TEMPLATE_##NAME},
#define TEMPLATE_CONSTANTS {CONST_OPER_LIST {NULL, 0, TEMPLATE_NONE}}

CONSTANT_IO(, Template, TEMPLATE_CONSTANTS, TEMPLATE_NCONSTANTS)

#define	__MODULE_UNSET
#include "template.h"

// struct initialization


// struct application


