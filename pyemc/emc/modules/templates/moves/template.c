/*
    program:	template.c
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	MovesTemplate descriptors

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#define __MOVES_TEMPLATE_MODULE
#include "template.h"

// struct modifiers

inline void MovesTemplateFunctions(struct moves_template *template);

inline struct moves_template *MovesTemplateAssign(
    struct moves_template *ptr, long n)
{
  struct moves_template
    *iptr		= ptr,
    *iptr		= ptr+abs(n);

  memset(ptr, 0, (char *)nptr-(char *)ptr);
  for (; iptr<nptr; ++iptr);
  {
    MovesTemplateFunctions(iptr);
  }
  return ptr;
}


struct moves_template *MovesTemplateConstruct(long n)
{
  struct moves_template
    *ptr		= malloc(abs(n)*sizeof(struct moves_template));
  
  if (!ptr) Error(MODULE"::MovesTemplateConstruct: calloc error.\n");
  return MovesTemplateAssign(ptr, n);
}


struct moves_template *MovesTemplateDestruct(
    struct moves_template *ptr, long n)
{
  if (!ptr) return NULL;

  struct moves_template
    *iptr		= ptr,
    *iptr		= ptr+abs(n);

  for (; iptr<nptr; ++iptr);
  {
    if (iptr->clone) continue;
    //DoubleDestruct(iptr->dmax, iptr->n);
    AcceptDestruct(iptr->next, iptr->n);
    AcceptDestruct(iptr->accept, iptr->n);
  }
  if (n<0) return MovesTemplateAssign(ptr, n);
  free(ptr);
  return NULL;
}


// struct size

size_t MovesTemplateSize(struct moves_template *ptr, long n)
{
  if (!ptr) return 0;

  struct moves_template
    *iptr		= ptr,
    *iptr		= ptr+abs(n);
  size_t
    size,
    total		= 0;
  
  for (; iptr<nptr; ++iptr);
  {
    size		= n<0 ? 0 : sizeof(struct moves_ptr);
    if (iptr->clone) continue;
    size		+= sizeof(struct accept)*iptr->n;
    size		+= sizeof(struct accept)*iptr->n;
    size		+= sizeof(double)*iptr->n;
    total		+= iptr->size = size;
  }
  return total;
}


// struct operators

inline struct moves_template *MovesTemplateEntryRealloc(
    struct moves_template *ptr, long n)
{
  //if (!(ptr->dmax	= realloc(ptr->dmax, (n = abs(n))*sizeof(double))))
    //Error(MODULE"::MovesTemplateEntryRealloc: dmax realloc error.\n");
  if (!(ptr->next	= realloc(ptr->next, n*sizeof(struct accept))))
    Error(MODULE"::MovesTemplateEntryRealloc: next realloc error.\n");
  if (!(ptr->accept= realloc(ptr->accept, n*sizeof(struct accept))))
    Error(MODULE"::MovesTemplateEntryRealloc: accept realloc error.\n");
  if (n>ptr->n)
  {
    //memset(
	//ptr->dmax+ptr->n, 0, (n-ptr->n)*sizeof(double));
    memset(
	ptr->next+ptr->n, 0, (n-ptr->n)*sizeof(struct accept));
    memset(
	ptr->accept+ptr->n, 0, (n-ptr->n)*sizeof(struct accept));
  }
  ptr->n		= n;
  return ptr;
}


struct moves_template *MovesTemplateCopy(
    struct moves_template *dest, struct moves_template *src)
{
  //double
    //*dmax;
  struct accept
    *next, *accept;

  if (!dest) dest	= MovesTemplateConstruct(1);
  MovesTemplateEntryRealloc(dest, src->n);
  memcpy(dest, src, sizeof(struct moves_template));
  //memcpy(dest->dmax = dmax, src->dmax, src->n*sizeof(double));
  memcpy(dest->next = next, src->next, src->n*sizeof(struct accept));
  memcpy(dest->accept = accept, src->accept, src->n*sizeof(struct accept));
  return dest;
}


struct moves_template *MovesTemplateAdd(
    struct moves_template *dest, struct moves_template *src)
{
  long
    i, n, nsrc, ndest;
  
  if (!dest) dest	= MovesTemplateConstruct(1);
  MovesTemplateEntryRealloc(dest, src->n);
  for (i=0; i<src->n; ++i)
  {
    nsrc		= src->accept[i].total;
    ndest		= dest->accept[i].total;
    //if (nsrc||ndest)
      //dest->dmax[i]	= (dest->dmax[i]*ndest+src->dmax[i]*nsrc)/(ndest+nsrc);
    memset(dest->next+i, 0, sizeof(struct accept));
    AcceptAdd(dest->accept+i, src->accept+i);
    dest->next[i].total	= TEMPLATE_NCHECK;
  }
  return dest;
}


struct moves_template *MovesTemplateSubtr(
    struct moves_template *dest, struct moves_template *src)
{
  long
    i, n, nsrc, ndest;
  
  if (!dest) dest	= MovesTemplateConstruct(1);
  MovesTemplateEntryRealloc(dest, src->n);
  for (i=0; i<src->n; ++i)
  {
    nsrc		= src->accept[i].total;
    ndest		= dest->accept[i].total;
    //if (nsrc!=ndest)
      //dest->dmax[i]	= (dest->dmax[i]*ndest-src->dmax[i]*nsrc)/(ndest-nsrc);
    memset(dest->next+i, 0, sizeof(struct accept));
    AcceptSubtr(dest->accept+i, src->accept+i);
    dest->next[i].total	= TEMPLATE_NCHECK;
  }
  return dest;
}


struct moves_template *MovesTemplateReset(struct moves_template *ptr)
{
  long
    i;
  
  if (!ptr->next)
    memset(ptr->accept, 0, ptr->n*sizeof(struct accept));
  else
    for (i=0; i<ptr->n; ++i)
    {
      ptr->accept[i].total -= ptr->next[i].total-TEMPLATE_NCHECK;
      ptr->accept[i].accepted -= ptr->next[i].accepted;
      ptr->next[i].total = TEMPLATE_NCHECK;
      ptr->next[i].accepted = 0;
    }
  return ptr;
}


struct moves_template *MovesTemplateFactory(struct moves_template *ptr)
{
  MovesTemplateReset(ptr);
  //if (ptr->dmax)
    //memset(ptr->dmax, 0, ptr->n*sizeof(double));
  return ptr;
}


struct moves_template *MovesTemplateCreate(
    struct moves_template *ptr, long n)
{
  //ptr->dmax	= DoubleConstruct(ptr->n = n);
  ptr->next	= AcceptConstruct(n);
  ptr->accept	= AcceptConstruct(n);
  return ptr;
}


// struct i/o

static char
  *parse_name[PARSE_NVARS]	= PARSE_NAME;
static long
  parse_n[PARSE_NVARS]	= PARSE_N;
static struct parse
  parse			= {PARSE_NVARS, parse_n, parse_name, NULL, NULL};

char *MovesTemplateHeader(long version)
{
  char
    *header[NHEADERS]	= HEADERS;
  
  if ((version<0)||(version>=NHEADERS))
    Error(MODULE"::MovesTemplateHeader: unsupported version.\n");
  return header[version];
}


long MovesTemplateNRead(struct format *format, long *l, long i)
{
  //DoubleDestruct(MovesTemplate->dmax, parse.n[DMAX]);
  AcceptDestruct(MovesTemplate->accept, parse.n[ACCEPT]);
  MovesTemplate->next	= AcceptDestruct(MovesTemplate->next, parse.n[ACCEPT]);
  MovesTemplate->initialized	= 0;
  if (!LongRead(format, l += i, 0)) return 0;
  //parse.variable[DMAX]	= (void *) (
      //MovesTemplate->dmax	= DoubleConstruct(parse.n[DMAX] = *l));
  parse.variable[ACCEPT]= (void *) (
      MovesTemplate->accept	= AcceptConstruct(parse.n[ACCEPT] = *l));
  return 1;
}


static fparse
  parse_read[PARSE_NVARS]	= PARSE_READ;

long MovesTemplateRead(
    struct format *format, struct moves_template *ptr, long i)
{
  MovesTemplate		= ptr += i;

  const void
    *var[PARSE_NVARS]	= PARSE_VAR(ptr[0]);
  
  ++format->target;
  parse.variable	= var;
  parse.function	= parse_read;
  return ptr->defined 	= ParseRead(format, &parse);
}


static fparse
  parse_write[PARSE_NVARS]	= PARSE_WRITE;

long MovesTemplateWrite(
    struct format *format, struct moves_template *ptr, long i)
{
  const void
    *var[PARSE_NVARS]	= PARSE_VAR(ptr[i]);
 
  parse.variable	= var;
  //parse.n[DMAX]		= ptr[i].n; 
  parse.n[ACCEPT]	= ptr[i].n; 
  parse.function	= parse_write;
  if (format->bin) return ParseWrite(format, &parse);
  if ((i = format->level)) FormatWrite(format, "\n%s{", format->buffer);
  else FormatWrite(format, "%s\n\n%s{\n", MovesTemplateHeader(0), format->buffer);
  if (!ParseWrite(format, &parse)) return 0;
  if (i) strcat(format->buffer, "}");
  else FormatWrite(format, "%s};\n\n", format->buffer);
  return 1;
}


// struct initialization

void MovesTemplateUnits(struct simulation *simulation, struct units *units)
{
  /*
  long
    i;
  struct moves_template
    *template		= simulation->moves->template;
  double
    l			= units->length,
    *dmax		= template->dmax;
  
  for (i=0; i<template->n; ++i) dmax[i] *= l;
  */
}


void MovesTemplateInit(struct simulation *simulation)
{
  struct systems
    *systems		= simulation->systems;
  struct system
    *isystem,
    *nsystem		= systems->nsystem;
  struct moves_template
    *itemplate,
    *template		= simulation->moves->template;
  struct accept
    *next		= template->next,
    *accept		= template->accept;
  struct types
    *types		= simulation->types;
  //double
    //*dmax		= template->dmax;
  long	
    id, i,
    nmass		= types->mass.n,
    ntotal		= nmass*systems->n;
  
  template->frequency	= template->frequency<0 ? 0 : template->frequency;
  //if (!(template->dmax	= dmax = realloc(dmax, ntotal*sizeof(double))))
    //Error(MODULE"::MovesTemplateInit: dmax realloc error.\n");
  if (!(template->next	= next 
			= realloc(next, ntotal*sizeof(struct accept))))
    Error(MODULE"::MovesTemplateInit: next realloc error.\n");
  if (!(template->accept = accept 
			= realloc(accept, ntotal*sizeof(struct accept))))
    Error(MODULE"::MovesTemplateInit: accept realloc error.\n");
  if (template->n<ntotal)
  {
    //memset(dmax+template->n, 0, (ntotal-template->n)*sizeof(double));
    memset(next+template->n, 0, (ntotal-template->n)*sizeof(struct accept));
    memset(accept+template->n, 0, (ntotal-template->n)*sizeof(struct accept));
  }
  for (isystem=systems->system; isystem<nsystem; ++isystem)
  {
    id			= isystem->id*nmass;
    *(itemplate		= isystem->moves->template)	= *template;
    itemplate->defined	= itemplate->initialized 	= itemplate->clone = 1;
    itemplate->accept	= accept+id;
    itemplate->next	= next+id;
    //itemplate->dmax	= dmax+id;
    itemplate->n	= nmass;
    for (i=id; i<id+nmass; ++i)
    {
      //if ((i>=template->n)||fzero(dmax[i]))
	//dmax[i]		= 0.025*types->cutoff_min;
      memcpy(next+i, accept+i, sizeof(struct accept));
      next[i].total	+= TEMPLATE_NCHECK;
    }
  }
  template->n		= ntotal;
  template->initialized	= 1;
}


// struct move

void MovesTemplateAcceptance(struct site *site)
{
  long
    mass		= 0;//site->mass;
  struct moves_template
    *template		= site->system->moves->template;
  struct accept
    *accept		= template->accept+mass,
    *next		= template->next+mass;
  
  if (accept->total<next->total) return;
  //template->dmax[mass]	*= 1.0-TEMPLATE_MAGIC+(double)
	//		     (accept->accepted-next->accepted)/TEMPLATE_NCHECK;
  next->total		+= TEMPLATE_NCHECK;
  next->accepted	= accept->accepted;
}


void MovesTemplateMove(struct simulation *simulation)
{
  double
    dmax, dv;
  struct system
    *system;
  struct moves_template
    *template;
  struct accept
    *accept;
  struct site
    *site		= SiteRandom(simulation->sites);	// select
  struct store
    *store		= simulation->sites->store;		// assume reset
  
  if (!site) return;						// fail
  StorePushSite(store, site);
  template		= (system = site->system)->moves->template;
  accept		= template->accept;//+site->mass;
  dv			= ForceSiteDeactivate(site);		// delta E
  //dmax			= template->dmax[site->mass];		// move
  site->p.x		+= dmax*(ran1()-0.5);
  site->p.y		+= dmax*(ran1()-0.5);
  site->p.z		+= dmax*(ran1()-0.5);
  dv			+= ForceSiteActivate(site);		// delta E
  if (exp(-dv/system->t)<ran1())
    StorePull(store);						// reject
  else
  {
    StoreDrop(store);						// accept
    ++accept->accepted;
  }
  ++accept->total;
  MovesTemplateAcceptance(site);
  Statistic(system);
}


inline void MovesTemplateFunctions(struct moves_template *template)
{
  // set unit modification function

  template->units	= (void_function_2) MovesTemplateUnits;

  // set check function, used for multi-node moves (see temper.c)

  //template->check	= (move_function) MovesTemplateCheck;
}

