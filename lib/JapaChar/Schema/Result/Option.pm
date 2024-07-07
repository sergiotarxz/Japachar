package JapaChar::Schema::Result::Option;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Core';

use Encode qw/decode/;

__PACKAGE__->table('options');

__PACKAGE__->add_columns(
    name => {
        data_type   => 'TEXT',
        is_nullable => 0,
    },
    value => {
        data_type   => 'TEXT',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('name');
1;
