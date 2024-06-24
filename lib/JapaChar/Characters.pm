package JapaChar::Characters;

use v5.38.2;

use strict;
use warnings;

use Moo;
use Path::Tiny;
use JSON;
use Data::Dumper;

my $option_populated = 'populated_basic_characters';
require JapaChar::DB;
require JapaChar::Schema;

sub populate_basic_characters($self) {
    my $dbh    = JapaChar::DB->connect;
    my $result = $dbh->selectrow_hashref(
        'SELECT value
FROM options 
WHERE name = ?', {}, $option_populated
    );
    if ( defined $result && $result->{value} ) {
        return;
    }
    $self->_populate_type('hiragana');
    $self->_populate_type('katakana');
    $dbh->do( 'INSERT INTO options (name, value) VALUES (?, ?);',
        undef, $option_populated, 1 );
}

sub _populate_type( $self, $type ) {
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    for my $char ( @{ $self->_get_characters_of_type($type) } ) {
        my $kana    = $char->{kana};
        my $romanji = $char->{roumaji};
        next if $romanji =~ /pause/i;
        $basic_character_resultset->new(
            { value => $kana, romanji => $romanji, type => $type, } )->insert;
    }
}

sub _get_characters_of_type( $self, $type ) {
    my $current_file = path __FILE__;
    my $array =
      from_json( $current_file->parent->parent->parent->child("$type.json")
          ->slurp_utf8 );
    return $array;
}

sub get_4_incorrect_answers( $self, $char ) {
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    my @bad_answers = $basic_character_resultset->search(
        {
            type => $char->type,
            value   => { '!=', $char->value },
            romanji => { '!=', $char->romanji },
            -bool   => 'started',
        },
        {
            order_by => { -asc => \'RANDOM()' },
            rows     => 4,
        }
    );
    return \@bad_answers;
}

sub next_review_char( $self, $type = undef ) {
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    my @chars = $basic_character_resultset->search(
        {
            score => { '>=' => 100 },
            (
                ( defined $type ) ? ( type => $type, ) : ()
            )
        },
        {
            order_by => { -asc => \'RANDOM()' },
            rows     => 1
        }
    );
    if ( !@chars ) {
        return;
    }
    return $chars[0];
}

sub next_char( $self, $type = undef ) {
    my $next_review   = $self->next_review_char($type);
    my $next_learning = $self->next_learning_char($type);
    if ( !defined $next_review ) {
        return $next_learning;
    }
    my $rng = int( rand(100) ) + 1;
    if ( $rng > 20 ) {
        return $next_learning;
    }
    return $next_review;
}

sub next_learning_char( $self, $type = undef ) {
    $self->populate_basic_characters;
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    my @candidate_chars = $self->_retrieve_started_chars_not_finished($type);
    if ( @candidate_chars < 5 ) {
        my @new_chars = $basic_character_resultset->search(
            {
                -not_bool => 'started',
                (
                    ( defined $type ) ? ( type => $type, ) : ()
                )
            },
            {
                order_by => { -asc => 'id' },
                rows     => 5 - scalar @candidate_chars,
            }
        );
        for my $char (@new_chars) {
            $char->update( { started => 1 } );
        }
        @candidate_chars = $self->_retrieve_started_chars_not_finished($type);
    }
    my $char = $candidate_chars[ int( rand( scalar @candidate_chars ) ) ];
    return $char;
}

sub _retrieve_started_chars_not_finished( $self, $type ) {
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    return $basic_character_resultset->search(
        {
            (
                ( defined $type ) ? ( type => $type, ) : ()
            ),
            score => { '<' => 100 },
            -bool => 'started',
        }
    );
}

1;
