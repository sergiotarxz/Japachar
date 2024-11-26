package JapaChar::Schema::Result::KanjiMeanings;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Core';

use Encode qw/decode/;

__PACKAGE__->table('kanji_meanings');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'INTEGER',
        is_auto_increment => 1,
    },
    id_kanji => {
        data_type   => 'INTEGER',
        is_nullable => 0,
    },
    meaning => {
        data_type   => 'TEXT',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(kanji => 'JapaChar::Schema::Result::Kanji', 'id_kanji');
1;
