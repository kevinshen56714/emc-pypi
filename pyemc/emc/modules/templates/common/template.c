/*
    program:	template.c
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	Template descriptors

    notes:	Copyrights (2011) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#define __TEMPLATE_MODULE
#include "template.h"

// struct modifiers

struct template *TemplateAssign(
    struct template *list, long n)
{
  struct template
    *ilist		= list,
    *nlist		= list+abs(n);
  struct function
    function		= ListFunction();

  memset(list, 0, abs(n)*sizeof(struct template));
  for (; ilist<nlist; ++ilist)
  {
    ilist->size		= sizeof(struct list);
    ilist->function	= function;
  }
  return list;
}


struct template *TemplateConstruct(long n)
{
  struct template
    *ptr		= malloc(abs(n)*sizeof(struct template));

  if (!ptr) Error(IDENTIFIER"Construct: malloc error.\n");
  return TemplateAssign(ptr, n);
}


// struct size

// struct operators

// struct i/o

// struct initialization

