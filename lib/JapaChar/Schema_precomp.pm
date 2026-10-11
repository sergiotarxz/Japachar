package JapaChar::Schema_precomp;

use v5.36.0;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces(
    result_namespace => '+JapaChar::Schema::Result',
);

my $schema;

sub Schema ($class) {
    if ( !defined $schema ) {
        require JapaChar::DB_precomp;
        JapaChar::DB_precomp->connect;
        my $db_path = JapaChar::DB_precomp->_db_path;
        my $user = undef;
        my $password = undef;
        # Undef is perfectly fine for username and password.
        $schema = $class->connect(
            'dbi:SQLite:dbname='.$db_path, $user, $password,
            {
            }
        );
    }
    return $schema;
}

sub reset_schema {
    undef $schema;
}
1;
