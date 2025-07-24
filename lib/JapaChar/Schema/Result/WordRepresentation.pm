package JapaChar::Schema::Result::WordRepresentation;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Core';

use Encode qw/decode/;

__PACKAGE__->table('word_representations');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'INTEGER',
        is_auto_increment => 1,
    },
    id_word => {
        data_type   => 'INTEGER',
        is_nullable => 0,
    },
    type => {
        data_type   => 'TEXT',
        is_nullable => 0,
    },
    value => {
        data_type   => 'TEXT',
        is_nullable => 0,
        accessor => '_value',
    },
);

sub value($self) {
    return decode 'utf-8', $self->_value;
}

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(word => 'JapaChar::Schema::Result::Word', 'id_word');
__PACKAGE__->has_many( representation_classifications => 'JapaChar::Schema::Result::WordRepresentationClassification', 'id_representation' );
__PACKAGE__->many_to_many( classifications => 'representation_classifications', 'classification');
1;
