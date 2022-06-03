/*
    program:	template.h
    author:	Pieter J. in 't Veld
    date:	October 31, 2007.
    purpose:	Header file for template.c

    notes:	Copyrights (2020) by author.  This software is distributed
		under the GNU General Public License.  See README in top-level
		EMC directory.
*/
#ifdef __SAMPLES_ID
SamplesID(TEMPLATE, Template, template)
#elif	defined(__SAMPLES_DEFINE)

#define	MODULE		TEMPLATE
#define Module		Template
#define module		template

#include "list.h"
#include "scripts.h"

#undef	__SAMPLES_DEFINE

#elif 	!defined(__SAMPLES_TEMPLATE_HEADER)
#define __SAMPLES_TEMPLATE_HEADER

#include "core/default.h"

// module-independent type definitions

#define SAMPLES_TEMPLATE_NBINSIZES	1
  
typedef
  struct samples_template {
    long		id, active, frequency;		// external
    double		binsize[SAMPLES_TEMPLATE_NBINSIZES],
			cutoff;
    long		ndists;
    struct distribution	*dist;
    long		skip, defined, initialized;	// internal
    struct focus	*focus;
    void_function_1	init, uninit;
    void_function_2	units;
    size_t		size;				// memory usage
  } __samples_template;

#define	__SAMPLES_LIST_STRUCT
#include "list.h"

#define samples_list_template	samples_list

#include "core/parse.h"
#include "core/format.h"
#include "core/simulation.h"
#include "core/units.h"

#ifdef __SAMPLES_TEMPLATE_MODULE

#include "core/cluster.h"
#include "core/clusters.h"
#include "core/distribution.h"
#include "core/distributions.h"
#include "core/focus.h"
#include "core/map.hh"
#include "core/message.h"
#include "core/site.h"
#include "core/sites.h"
#include "core/sample.h"
#include "core/samples.h"
#include "core/system.h"
#include "core/systems.h"
#include "core/types.h"

#define __SAMPLES_DEFINE
#include "template.h"

#undef	EXTERN
#define	EXTERN
#include "list.h"
#include "script.h"

#define IDENTITY	__macro2str(module)

// parse transcriptions

enum{
  PARSE_ID, PARSE_ACTIVE, PARSE_FREQUENCY, PARSE_FOCUS, PARSE_CUTOFF,
  PARSE_BINSIZE, PARSE_NDISTRIBUTIONS, PARSE_DISTRIBUTIONS, PARSE_NVARS};

#define PARSE_NS	{1, 1, 1, 1, 1, 1, 1, -1}
#define PARSE_NAME	{"id", "active", "frequency", "focus", "cutoff", \
			 "binsize", "ndistributions", "distributions"}
#define PARSE_VAR(x)	{&x.id, &x.active, &x.frequency, x.focus, &x.cutoff, \
			 x.binsize, &x.ndists, x.dist}
#define PARSE_READ	{LongRead, BooleanRead, LongRead, FocusRead, \
			 DoubleRead, DoubleRead, (fparse)SamplesTemplateNRead,\
			 DistributionRead}
#define PARSE_WRITE	{LongWrite, BooleanWrite, LongWrite, FocusWrite, \
			 DoubleWrite, DoubleWrite, LongWrite, \
			 DistributionWrite}

// core/script/sample selections

#define PARSE_IGNORE(x)	{&x.dist, NULL}

#define	PARSE_COPY(x)	{&x.id, &x.active, &x.frequency, &x.focus, NULL}
#define	PARSE_F_COPY	{(fcopy)LongCopy, (fcopy)LongCopy, (fcopy)LongCopy, \
			 (fcopy)FocusPtrCopy}

#define PARSE_CMP(x)	{&x.cutoff, &x.focus, NULL}
#define	PARSE_F_CMP	{(fcmp)DoubleCmp, (fcmp)FocusPtrCmp}

// module-specific variable and type definitions

#define TEMPLATE_BINSIZE	{0.01}
#define TEMPLATE_ONE		{1.0}

struct samples_template		*SamplesTemplate = NULL;

#else

#define __SAMPLES_DEFINE
#include "template.h"
#include "list.h"
#include "script.h"
#include "undef.h"

// shared variables

// struct modifiers

extern struct samples_template
  *SamplesTemplateConstruct(long n);
extern struct samples_template
  *SamplesTemplateDestruct(struct samples_template *template, long n);
extern struct samples_template
  *SamplesTemplateEntryDestruct(struct samples_template *template);

// struct size

extern size_t
  SamplesTemplateSize(struct samples_template *template, long n);

// struct operators

extern struct samples_template
  *SamplesTemplateCopy(
      struct samples_template *dest, struct samples_template *src);
extern struct samples_template
  *SamplesTemplateAdd(
      struct samples_template *dest, struct samples_template *src);
extern struct samples_template
  *SamplesTemplateSubtr(
      struct samples_template *dest, struct samples_template *src);

// struct initialization

extern struct samples_template
  *SamplesTemplateCreate(struct samples_template *template, long n);
extern struct samples_template
  *SamplesTemplateReset(struct samples_template *template);
extern struct samples_template
  *SamplesTemplateFactory(struct samples_template *template);
extern void
  SamplesTemplateUnits(struct samples_template *template, struct units *units);

// struct i/o

extern char
  *SamplesTemplateHeader(long version);
extern long
  SamplesTemplateRead(struct format *format, const void *template, long i);
extern long
  SamplesTemplateWrite(struct format *format, const void *template, long i);
extern long
  SamplesTemplateExport(FILE *stream, const void *template, long i);

// struct global init

extern void
  SamplesTemplateInit(
      struct simulation *simulation, struct samples_template *template);
extern void
  SamplesTemplateUnInit(
      struct simulation *simulation, struct samples_template *template);

#endif	// __SAMPLES_TEMPLATE_MODULE

#endif	// __SAMPLES_ID

