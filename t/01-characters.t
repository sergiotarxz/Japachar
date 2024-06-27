#!/usr/bin/env perl

use v5.38.2;

use strict;
use warnings;

use Test::Most tests => 2;
use Test::MockModule;
use Path::Tiny;

use File::Basename;

use lib dirname(dirname(__FILE__)).'/lib';

use JapaChar::DB;

BEGIN {
    use_ok 'JapaChar::Characters';
};

{
    my $mock_db = Test::MockModule->new('JapaChar::DB');
    $mock_db->mock(_db_path => sub {
        return path(__FILE__)->parent->child('all-learned-basic-characters.db');
    });
    ok defined(JapaChar::Characters->new->next_char), 'The next char is defined.';
}
