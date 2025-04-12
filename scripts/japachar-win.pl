#!/usr/bin/env perl

use v5.38.2;

use File::Basename;

BEGIN {
    open my $fh, '>&', \*STDERR;
    open STDERR, '>', '/dev/null';
    system 'perl', 'Build.PL';
    system 'perl', 'Build', 'build';
    open STDERR, '>&', $fh;
    $ENV{PATH} = 'c\bin;perl\bin'.$ENV{PATH};
};

use blib 'japachar';

use JapaChar;

JapaChar->new->start;
