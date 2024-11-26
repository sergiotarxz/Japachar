package JapaChar::Schema::Result::Kanji;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Core';

use Encode qw/decode/;

__PACKAGE__->table('kanji');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'INTEGER',
        is_auto_increment => 1,
    },
    kanji => {
        data_type   => 'TEXT',
        is_nullable => 0,
        accessor    => '_kanji',
    },
    grade => {
        data_type   => 'INTEGER',
    },
    started => {
        data_type   => 'BOOLEAN',
    },
    score => {
        data_type   => 'INTEGER',
    },
    consecutive_success => {
        data_type   => 'INTEGER',
    },
    consecutive_failures => {
        data_type   => 'INTEGER',
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(meanings => 'JapaChar::Schema::Result::KanjiMeanings', 'id_kanji');
__PACKAGE__->has_many(on_readings => 'JapaChar::Schema::Result::KanjiOnReadings', 'id_kanji');
__PACKAGE__->has_many(kun_readings => 'JapaChar::Schema::Result::KanjiKunReadings', 'id_kanji');

sub kanji( $self, $kanji = undef ) {
    if ( defined $kanji ) {
        $self->_kanji($kanji);
    }
    return decode 'utf-8', $self->_kanji;
}

sub fail($self) {
    my $score                = $self->score;
    my $consecutive_success  = 0;
    my $consecutive_failures = $self->consecutive_failures + 1;
    $score -= 25;
    if ( $score < 0 ) {
        $score = 0;
    }
    $self->update(
        {
            score                => $score,
            consecutive_failures => $consecutive_failures,
            consecutive_success  => 0,
        }
    );
}

sub get( $self, $what ) {
    if ( $what eq 'kana' ) {
        return $self->value;
    }
    if ( $what eq 'romanji' ) {
        return $self->romanji;
    }
    return;
}

sub success($self) {
    my $score                = $self->score;
    my $consecutive_success  = $self->consecutive_success + 1;
    my $consecutive_failures = 0;
    $score += 5 + 10 * $consecutive_success;
    if ( $score > 300 ) {
        $score = 300;
    }
    $self->update(
        {
            score                => $score,
            consecutive_success  => $consecutive_success,
            consecutive_failures => $consecutive_failures,
        }
    );
}
1;
