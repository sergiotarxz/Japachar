#!/usr/bin/env perl

use v5.38.2;

use strict;
use warnings;

use Test::Most tests => 3;
use Test::MockModule;
use Path::Tiny;

use File::Basename;

use lib dirname(dirname(__FILE__)).'/lib';

use JapaChar::DB;
use JapaChar::Random;

BEGIN {
    use_ok 'JapaChar::Characters';
};

{
    my $mock_db = Test::MockModule->new('JapaChar::DB');
    $mock_db->mock(_db_path => sub {
        return path(__FILE__)->parent->child('all-learned-basic-characters.db');
    });
    my $mock_random = Test::MockModule->new('JapaChar::Random');
    $mock_random->mock(get => sub {
        return 100;
    });
    my $mock_characters = Test::MockModule->new('JapaChar::Characters');
    my $next_review_char = undef;
    $mock_characters->mock(_next_review_char => sub {
        $next_review_char = $mock_characters->original('_next_review_char')->(@_);
        return $next_review_char;
    });
    my $next_char = JapaChar::Characters->new->next_char;
    ok defined($next_char), 'The next char is defined.';
    is_deeply $next_review_char, $next_char, 'The next char is a review one.';
}
