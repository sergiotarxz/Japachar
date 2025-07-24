#!/usr/bin/env perl

use v5.38.2;

use strict;
use warnings;

use Mojo::DOM;
use Path::Tiny;

my $input = shift @ARGV or die 'No input file';
my $output = shift @ARGV or die 'No output file';
my $dom = Mojo::DOM->with_roles('+PrettyPrinter')->new(path($input)->slurp_utf8);
path($output)->spew_utf8($dom->to_pretty_string);
