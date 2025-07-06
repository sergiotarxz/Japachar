#!/usr/bin/env perl

use v5.38.2;

use File::Basename;

BEGIN {
#    open my $fh, '>&', \*STDERR;
#    open STDERR, '>', '/dev/null';
    system 'perl', 'Build.PL';
    system 'perl', 'Build', 'build';
#    open STDERR, '>&', $fh;
};

use blib;

use JapaChar;

JapaChar->new->start;
