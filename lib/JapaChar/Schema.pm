package JapaChar::Schema;

use v5.36.0;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces();

my $schema;

sub Schema ($class) {
    if ( !defined $schema ) {
        require JapaChar::DB;
        JapaChar::DB->connect;
        my $db_path = JapaChar::DB->_db_path;
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
