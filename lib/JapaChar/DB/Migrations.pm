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
        'ALTER TABLE basic_characters ADD consecutive_failures INTEGER NOT NULL DEFAULT 0',
        'CREATE TABLE kanji (
            id INTEGER PRIMARY KEY,
            kanji TEXT NOT NULL UNIQUE,
            grade INTEGER NOT NULL,
            started BOOLEAN NOT NULL DEFAULT 0,
            score INTEGER NOT NULL DEFAULT 0,
            consecutive_success INTEGER NOT NULL DEFAULT 0
        );',
        'CREATE TABLE kanji_meanings (
            id INTEGER PRIMARY KEY,
            id_kanji INTEGER NOT NULL,
            meaning TEXT NOT NULL,
            FOREIGN KEY (id_kanji) REFERENCES kanji(id)
        );',
        'CREATE TABLE kanji_on_readings (
            id INTEGER PRIMARY KEY,
            id_kanji INTEGER NOT NULL,
            reading TEXT NOT NULL,
            FOREIGN KEY (id_kanji) REFERENCES kanji(id)
        );',
        'CREATE TABLE kanji_kun_readings (
            id INTEGER PRIMARY KEY,
            id_kanji INTEGER NOT NULL,
            reading TEXT NOT NULL,
            FOREIGN KEY (id_kanji) REFERENCES kanji(id)
        );',
        'INSERT INTO options (name, value) VALUES (\'kanji_version\', \'0\');',
        'INSERT INTO options (name, value) VALUES (\'want_kanji_version\', \'1\');',
        'ALTER TABLE kanji ADD consecutive_failures INTEGER NOT NULL DEFAULT 0;',
        'CREATE TABLE kanji2 (
            id INTEGER PRIMARY KEY,
            kanji TEXT NOT NULL UNIQUE,
            grade INTEGER,
            started BOOLEAN NOT NULL DEFAULT 0,
            score INTEGER NOT NULL DEFAULT 0,
            consecutive_success INTEGER NOT NULL DEFAULT 0,
            consecutive_failures INTEGER NOT NULL DEFAULT 0
        );',
        'INSERT INTO kanji2 SELECT * FROM kanji;',
        'DROP TABLE kanji;',
        'ALTER TABLE kanji2 RENAME TO kanji;',
    );
}
1;
