package JapaChar::DB::Migrations;

use v5.34.1;

use strict;
use warnings;
use utf8;

use feature 'signatures';

sub MIGRATIONS {
    return (
        'CREATE TABLE options (
            name TEXT PRIMARY KEY,
            value TEXT
        )',
        'CREATE TABLE basic_characters (
            id INTEGER PRIMARY KEY,
            value TEXT NOT NULL UNIQUE,
            romanji TEXT NOT NULL,
            type TEXT NOT NULL,
            started BOOLEAN NOT NULL DEFAULT 0,
            score INTEGER NOT NULL DEFAULT 0,
            consecutive_success INTEGER NOT NULL DEFAULT 0
        );',
        'INSERT INTO options (name, value) VALUES (\'user_score\', \'0\');',
    );
}
1;
