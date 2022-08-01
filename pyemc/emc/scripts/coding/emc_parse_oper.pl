#!/usr/bin/env perl

# main

{
  my $i = 0;
  my $template = shift(@ARGV);
  my $command = shift(@ARGV);
  my @tmp; foreach (split("_", $template)) { push(@tmp, ucfirst(lc($_))); }
  my $Template = join("", @tmp);

  print("// parse transcriptions\n\n");
  print("#define\tPARSE_OPER_LIST \\\n");
  foreach (@ARGV) {
    printf("%s  PARSE_OPER($command, %s, %s, %s, 1, &)", $i++ ? " \\\n" : "", uc($_), lc($_), lc($_));
  }
  print("\n\n");
  print("#define\tPARSE_OPER(Oper, VAR, var, string, nvars, ampersand) PARSE_##VAR,\n");
  print("enum{PARSE_OPER_LIST PARSE_NVARS};\n");
  print("#undef\tPARSE_OPER\n\n");

  print("
// struct i/o

#define	PARSE_OPER(Oper, VAR, var, string, nvars, amp) nvars,
static long parse_n[]	= {PARSE_OPER_LIST 0};
#undef	PARSE_OPER

#define PARSE_OPER(Oper, VAR, var, string, nvars, amp) #string,
static char *parse_name[] = {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER

static struct parse
  parse			= {PARSE_NVARS, parse_n, parse_name, NULL, NULL};


// struct read

#define PARSE_OPER(Oper, VAR, var, string, nvars, amp) Oper##Read,
static fparse parse_read[] = {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER

long ".$Template."Read(struct format *format, struct $template *ptr, long i)
{
  ptr			+= i;
#define	PARSE_OPER(Oper, VAR, var, string, nvars, amp) amp ptr->var,
  const void
    *var[]		= {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER

  ++format->target;
  parse.variable	= var;
  parse.function	= parse_read;
  return ParseRead(format, &parse);
}


// struct write

#define PARSE_OPER(Oper, VAR, var, string, nvars, amp) Oper##Write,
static fparse parse_write[] = {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER

long ".$Template."Write(struct format *format, struct $template *ptr, long i)
{
  ptr			+= i;
#define	PARSE_OPER(Oper, VAR, var, string, nvars, amp) amp ptr->var,
  const void
    *var[]		= {PARSE_OPER_LIST NULL};
#undef	PARSE_OPER

  ++format->target;
  parse.variable	= var;
  parse.function	= parse_write;
  if (format->bin) return ParseWrite(format, &parse);
  FormatWrite(format, \"%s{\", format->buffer);
  i			= ParseWrite(format, &parse);
  strcat(format->buffer, \"}\");
  return i;
}
");
}
