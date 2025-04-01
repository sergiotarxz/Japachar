package JapaChar::Schema::Result::BasicCharacter;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Core';

use Encode qw/decode/;

__PACKAGE__->table('basic_characters');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'INTEGER',
        is_auto_increment => 1,
    },
    value => {
        data_type   => 'TEXT',
        is_nullable => 0,
        accessor    => '_value',
    },
    romanji => {
        data_type   => 'TEXT',
        is_nullable => 0,
    },
    type => {
        data_type   => 'TEXT',
        is_nullable => 0,
    },
    started => {
        data_type   => 'BOOLEAN',
        is_nullable => 1,
    },
    score => {
        data_type   => 'INTEGER',
        is_nullable => 1,
    },
    consecutive_success => {
        data_type   => 'INTEGER',
        is_nullable => 1,
    },
    consecutive_failures => {
        data_type   => 'INTEGER',
        is_nullable => 1,
    },
);

sub value( $self, $value = undef ) {
    if ( defined $value ) {
        $self->_value($value);
    }
    return decode 'utf-8', $self->_value;
}

__PACKAGE__->set_primary_key('id');

sub fail($self) {
    my $score                = $self->score;
    my $consecutive_success  = 0;
    my $consecutive_failures = $self->consecutive_failures + 1;

    $score -= JapaChar::Schema::Result::Option->get_fail_penalty_basic_character;
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
    $score +=
      JapaChar::Schema::Result::Option->get_success_reward_basic_character +
      JapaChar::Schema::Result::Option
      ->get_consecutive_success_reward_basic_character * $consecutive_success;
    if ( $score >
        JapaChar::Schema::Result::Option->get_max_inner_score_basic_char )
    {
        $score =
          JapaChar::Schema::Result::Option->get_max_inner_score_basic_char;
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
