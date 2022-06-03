/*
    program:	template.c
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	SamplesTemplate descriptors

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#define __SAMPLES_TEMPLATE_MODULE
#include "template.h"

// struct modifiers

//#define	SAMPLES_TEMPLATE_DEBUG

void SamplesTemplateFunctions(struct samples_template *ptr);

struct samples_template *SamplesTemplateFactory(
    struct samples_template *ptr)
{
  double
    binsize[SAMPLES_TEMPLATE_NBINSIZES] = TEMPLATE_BINSIZE;
  long
    i			= 0;

  for (; i<SAMPLES_TEMPLATE_NBINSIZES; ++i)
    ptr->binsize[i]	= binsize[i];

  SamplesTemplateFunctions(ptr);
  ptr->frequency	= 1;
  return ptr;
}


struct samples_template *SamplesTemplateAssign(
    struct samples_template *ptr, long n)
{
  struct samples_template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);

  memset(ptr, 0, (char *)nptr-(char *)ptr);
  for (; iptr<nptr; ++iptr)
  {
    SamplesTemplateFactory(iptr);
    iptr->focus		= FocusConstruct(1);
#ifdef	SAMPLES_TEMPLATE_DEBUG
    MessageSpot("\tassign\t\t%p\n", iptr);
#endif
    iptr->defined	= 1;
  }
  return ptr;
}


struct samples_template *SamplesTemplateConstruct(long n)
{
  struct samples_template
    *ptr		= malloc(abs(n)*sizeof(struct samples_template));
  
  if (!ptr) Error(IDENTITY"::SamplesTemplateConstruct: calloc error.\n");
  return SamplesTemplateAssign(ptr, n);;
}


struct samples_template *SamplesTemplateEntryDestruct(
    struct samples_template *ptr)
{
  if (!ptr) return NULL;
#ifdef	SAMPLES_TEMPLATE_DEBUG
  MessageSpot("\tdestruct_dist\t%p\t%p\t%ld\n", ptr, ptr->dist, ptr->ndists);
  MessageSpot("\t%p\t%p\t%p\n", ptr->dist->binsize, ptr->dist->dist, ptr->dist->data);
  DistributionDestruct(ptr->dist, ptr->ndists);
  MessageSpot("\tdestruct_focus\t%p\t%p\n", ptr, ptr->focus);
  FocusDestruct(ptr->focus, 1);
  MessageSpot("\tdestruct\tdone\n");
#else
  DistributionDestruct(ptr->dist, ptr->ndists);
  FocusDestruct(ptr->focus, 1);
#endif
  return ptr;
}


struct samples_template *SamplesTemplateDestruct(
    struct samples_template *ptr, long n)
{
  if (!ptr) return NULL;

  struct samples_template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);

  for(; iptr<nptr; ++iptr)
    SamplesTemplateEntryDestruct(iptr);
  if (n<0) return SamplesTemplateAssign(ptr, n);
  free(ptr);
  return NULL;
}


// struct size

size_t SamplesTemplateSize(struct samples_template *ptr, long n)
{
  if (!ptr) return 0;

  struct samples_template
    *iptr		= ptr,
    *nptr		= ptr+abs(n);
  size_t
    size,
    total		= 0;

  for(; iptr<nptr; ++iptr)
  {
    size		= n<0 ? 0 : sizeof(struct samples_template);
    size		+= DistributionSize(iptr->dist, iptr->ndists);
    size		+= FocusSize(iptr->focus, 1);
    total		+= iptr->size = size;
  }
  return total;
}


// struct operators

struct samples_template *SamplesTemplateDistributionsAssign(
    struct samples_template *ptr, long n)
{
  long
    i;
  struct distribution
    *dist		= ptr->dist;
  
  if (n>=0) dist	= ptr->dist = DistributionConstruct(n);
  ptr->ndists		= n = abs(n);
#ifdef	SAMPLES_TEMPLATE_DEBUG
  MessageSpot("\tassign_dist\t%p\t%p\n", ptr, ptr->dist);
#endif
  for (i=0; i<n; ++i)
  {
    dist[i].type	= DIST_TYPE_FREQUENCY;
    dist[i].binsize	= ptr->binsize;
  }
  return ptr;
}


struct samples_template *SamplesTemplateCopy(
    struct samples_template *dest, struct samples_template *src)
{
  dest			= dest ? SamplesTemplateDestruct(dest, -1) :
				 SamplesTemplateConstruct(1);
  
#ifdef	SAMPLES_TEMPLATE_DEBUG
  MessageSpot("\tcopy\t\t%p\t%p\n", src, dest);
#endif
  void *focus		= dest->focus;
  memcpy(dest, src, sizeof(struct samples_template));
  dest->focus		= src->focus ? FocusCopy(focus, src->focus) : focus;
  if (src->dist)
  {
    SamplesTemplateDistributionsAssign(dest, src->ndists);
    long i=0; for (; i<src->ndists; ++i)
      DistributionCopy(dest->dist+i, src->dist+i);
  }
  return dest;
}


struct samples_template *SamplesTemplateAdd(
    struct samples_template *dest, struct samples_template *src)
{
  long
    i;

  if (!dest)
    dest		= SamplesTemplateConstruct(1);
  if (src->ndists)
  {
    if (!dest->dist)
      SamplesTemplateDistributionsAssign(dest, src->ndists);
    if (dest->ndists!=src->ndists)
      Error(IDENTITY"::SamplesTemplateAdd: "
	  "number of source and destination distributions differ.\n");
    for (i=0; i<src->ndists; ++i)
      DistributionAdd(dest->dist+i, src->dist+i);
  }
  return dest;
}


struct samples_template *SamplesTemplateSubtr(
    struct samples_template *dest, struct samples_template *src)
{
  long
    i;

  if (!dest)
    dest		= SamplesTemplateConstruct(1);
  if (src->ndists)
  {
    if (!dest->dist)
      SamplesTemplateDistributionsAssign(dest, src->ndists);
    if (dest->ndists!=src->ndists)
      Error(IDENTITY"::SamplesTemplateSubtr: "
	  "number of source and destination distributions differ.\n");
    for (i=0; i<src->ndists; ++i)
      DistributionSubtr(dest->dist+i, src->dist+i);
  }
  return dest;
}


struct samples_template *SamplesTemplateReset(
    struct samples_template *ptr)
{
  struct samples_template
    store;
  long
    n			= ptr->ndists;

  SamplesTemplateCopy(
      memset(&store, 0, sizeof(struct samples_template)), ptr);
  return 
    SamplesTemplateDistributionsAssign(
      SamplesTemplateCopy(
	SamplesTemplateDestruct(ptr, -1), &store), n);
}


struct samples_template *SamplesTemplateCreate(
    struct samples_template *ptr, long n)
{
  return SamplesTemplateDistributionsAssign(ptr ?
      SamplesTemplateDestruct(ptr, -1) : SamplesTemplateConstruct(1), n);
}


// struct i/o

static char
  *parse_name[PARSE_NVARS] = PARSE_NAME;
static long
  parse_n[PARSE_NVARS]	= PARSE_NS;
static struct parse
  parse			= {PARSE_NVARS, parse_n, parse_name, NULL, NULL};

long SamplesTemplateNRead(struct format *format, long *l, long i)
{
#ifdef	SAMPLES_TEMPLATE_DEBUG
  MessageSpot("\tnread\t\t%p\t%p\n", SamplesTemplate, SamplesTemplate->dist);
#endif
  SamplesTemplate->dist	= DistributionDestruct(
			      SamplesTemplate->dist, SamplesTemplate->ndists);
  if (!LongRead(format, l += i, 0)) return 0;
  if (*l<0) Error(IDENTITY"::SampleTemplateNRead: ndistributions < 0.\n");
  else if (*l>0) SamplesTemplateDistributionsAssign(SamplesTemplate, *l);
  parse.variable[PARSE_DISTRIBUTIONS] = SamplesTemplate->dist;
  parse.n[PARSE_DISTRIBUTIONS] = *l;
  return 1;
}


static fparse
  parse_read[PARSE_NVARS]	= PARSE_READ;

long SamplesTemplateRead(
    struct format *format, struct samples_template *ptr, long i)
{
  if (!(SamplesTemplate	= ptr += i)->defined)
    SamplesTemplateAssign(ptr, 1);

  const void
    *var[PARSE_NVARS]	= PARSE_VAR(ptr[0]);
  
  ++format->target;
  parse.variable	= var;
  parse.function	= parse_read;
  return ptr->defined = ParseRead(format, &parse);
}


static fparse
  parse_write[PARSE_NVARS]	= PARSE_WRITE;

long SamplesTemplateWrite(
    struct format *format, struct samples_template *ptr, long i)
{
  ptr				+= i;

  const void
    *var[PARSE_NVARS]		= PARSE_VAR(ptr[0]);
 
  parse.variable		= var;
  parse.function		= parse_write;
  if (format->bin) return ParseWrite(format, &parse);

  if (!ptr->focus->defined)
  {
    var[PARSE_FOCUS]		= NULL;
    parse_n[PARSE_BINSIZE]	= 1;
  }
  else
    parse_n[PARSE_BINSIZE]	= SAMPLES_TEMPLATE_NBINSIZES;
  if (!ptr->ndists)
    var[PARSE_DISTRIBUTIONS]	= var[PARSE_NDISTRIBUTIONS] = NULL;
  parse.n[PARSE_DISTRIBUTIONS]	= ptr->ndists;
  FormatWrite(format, "\n%s{", format->buffer);
  if (!ParseWrite(format, &parse)) return 0;
  strcat(format->buffer, "}");
  return 1;
}


long SamplesTemplateExport(
    FILE *stream, struct samples_template *ptr, long i)
{
  return DistributionsExport(stream, ptr->dist+i, 0);
}


// struct sampling

void SamplesTemplateSampleInit(
    struct simulation *simulation, struct samples_template *template)
{
  long
    i;
  double
    cutoff		= 0.0;
  struct types
    *types		= simulation->types;
  struct systems
    *systems		= simulation->systems;

  if (template->frequency<1)
    template->frequency	= 0;
  if (template->ndists!=systems->n)
    SamplesTemplateDistributionsAssign(template, systems->n)->skip = 0;
  else
    SamplesTemplateDistributionsAssign(template, -systems->n)->skip = 
      template->frequency-1;

  if ((cutoff		= template->cutoff)<=0.0)
    for (i=0; i<types->mass.n; ++i)
      if (cutoff<types->diameter[i])
	cutoff		= types->diameter[i];
  template->cutoff	= cutoff;
}


void SamplesTemplateSample(
    struct simulation *simulation, struct samples_template *template)
{
  if (!(template->active&&template->frequency)) return;
  if (template->skip) { --template->skip; return; }
  template->skip	= template->frequency-1;

  double
    result[SAMPLES_TEMPLATE_NBINSIZES],
    one[SAMPLES_TEMPLATE_NBINSIZES] = TEMPLATE_ONE;
  struct focus
    *focus		= template->focus;
  struct distribution
    *idist,
    *dist		= template->dist;
  struct system
    *isystem		= simulation->systems->system,
    *nsystem		= simulation->systems->nsystem;
  struct list
    *list		= NULL;

  for (; isystem<nsystem; ++isystem)
  {
    struct sites
      *sites		= isystem->sites;
    struct site
      *isite		= sites->site,
      *nsite		= sites->nsite;

    (idist		= dist+isystem->id)->nsamples++;
#ifdef	SAMPLES_TEMPLATE_DEBUG
    MessageSpot("\tsample\t\t%p\t%p\t%ld\n", template, idist, idist->level);
#endif
    for (; isite<nsite; ++isite)
      isite->flag.test	= focus ? FocusTest(focus, isite) : 1;

    struct clusters
      *clusters		= isystem->clusters;
    struct cluster
      *icluster		= clusters->cluster,
      *ncluster		= clusters->ncluster;

    for (; icluster<ncluster; ++icluster)
    {
      if (!icluster->head->flag.test) continue;
      ClusterUnwrap(list = 
	ClusterSites(list, NULL, icluster->head, CLUSTER_BIT_ALL), 0);

      struct site
	*site, **jsite,
	**isite		= (void *) list->entry,
	**nsite		= (void *) list->nentry;

      for (; isite<nsite-1; ++isite)
      {
	if (!(site	= isite[0])->flag.test) continue;
	struct vector p	= site->p;
	for (jsite=isite+1; jsite<nsite; ++jsite)
	{
	  if (!(site	= jsite[0])->flag.test) continue;
	  struct vector d = {p.x-site->p.x, p.y-site->p.y, p.z-site->p.z};
	  result[0]	= sqrt(0.5*(d.x*d.x+d.y*d.y+d.z*d.z));
	  DistributionSubmit(idist, result, one, one);
#ifdef	SAMPLES_TEMPLATE_DEBUG
	  MessageSpot("\tsample_result\t%p\t%g\n", idist, result[0]);
#endif
	}
      }
      ClusterUnwrap(list);
    }
    for (; isite<nsite; ++isite)
      isite->flag.test	= 0;
  }
  ListDestruct(list, 1, 0);
}


// struct initialization

void SamplesTemplateUnits(
    struct samples_template *template, struct units *units)
{
  long
    i			= 0;

  for (; i<SAMPLES_TEMPLATE_NBINSIZES; ++i)
    template->binsize[i] *= units->length;
}


void SamplesTemplateInit(
    struct simulation *simulation, struct samples_template *template)
{
  struct sample
    *sample		= simulation->sample;
  
  if (template->active&&(template->frequency>0))
    SampleRegister(
	sample, template, (sample_function) SamplesTemplateSample,
       	(sample_function) SamplesTemplateSampleInit);
  else
    SampleUnregister(sample, template);
  template->initialized	= 1;
}


void SamplesTemplateUnInit(
    struct simulation *simulation, struct samples_template *template)
{
  struct sample
    *sample		= simulation->sample;

  SampleUnregister(sample, template);
  SamplesTemplateReset(template);
  template->initialized	= 0;
}


inline void SamplesTemplateFunctions(struct samples_template *template)
{
  // set unit modification function

  template->init	= (void_function_1) SamplesTemplateInit;
  template->uninit	= (void_function_1) SamplesTemplateUnInit;
  template->units	= (void_function_2) SamplesTemplateUnits;
}


// include templates

#include "list.hh"

#include "script.hh"

