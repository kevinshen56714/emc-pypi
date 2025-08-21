#!/usr/bin/env perl
#
#  module:	EMC::Test.pm
#  author:	Pieter J. in 't Veld
#  date:	December 2, 2024.
#  purpose:	Test structure routines; part of EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMCroot
#  directory
#
#  members
#    increment
#      entry	TYPE	description
#
#    test	HASH	above structure
#
#  notes:
#    20241202	Inception of v1.0
#

package EMC::Test;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

#use vars qw($Pi);

use EMC::Message;

# functions

