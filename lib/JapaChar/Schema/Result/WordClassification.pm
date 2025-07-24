package JapaChar::Schema::Result::WordClassification;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Core';

use Encode qw/decode/;

__PACKAGE__->table('word_classifications');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'INTEGER',
        is_auto_increment => 1,
    },
    value => {
        data_type   => 'TEXT',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many( representation_classifications => 'JapaChar::Schema::Result::WordRepresentationClassification', 'id_classification' );
__PACKAGE__->many_to_many( representations => 'representation_classifications', 'representation');
1;
