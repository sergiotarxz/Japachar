#!/usr/bin/env perl

use v5.38.2;

use File::Basename;

use lib dirname(dirname(__FILE__)).'/lib';

use JapaChar;

JapaChar->new->start;
