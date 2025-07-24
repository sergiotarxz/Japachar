package JapaChar::Schema::Result::Word;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Core';

use Encode qw/decode/;

__PACKAGE__->table('words');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'INTEGER',
        is_auto_increment => 1,
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

__PACKAGE__->has_many(representations => 'JapaChar::Schema::Result::WordRepresentation', 'id_word');
__PACKAGE__->has_many(meanings => 'JapaChar::Schema::Result::WordMeaning', 'id_word');

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
