package JapaChar::Schema::Result::WordRepresentationClassification;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Core';

use Encode qw/decode/;

__PACKAGE__->table('word_representation_classifications');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'INTEGER',
        is_auto_increment => 1,
    },
    id_classification => {
        data_type   => 'INTEGER',
        is_nullable => 0,
    },
    id_representation => {
        data_type   => 'INTEGER',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(classification => 'JapaChar::Schema::Result::WordClassification', 'id_classification');
__PACKAGE__->belongs_to(representation => 'JapaChar::Schema::Result::WordRepresentation', 'id_representation');
1;
