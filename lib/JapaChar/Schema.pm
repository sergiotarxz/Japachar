package JapaChar::Schema;

use v5.36.0;

use strict;
use warnings;

use Unicode::Normalize qw(NFD);
use Encode qw/decode/;

use feature 'signatures';

use parent 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces();

my $schema;
sub Schema ($class) {
    return $schema if defined $schema;
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
    my $dbh = $schema->storage->dbh;
    state %mark_results;
    $dbh->sqlite_create_function(
        'mark',
        1,
        sub {
            my ($c) = @_;
            my $result = sub {
                return $mark_results{$c} if exists $mark_results{$c};

                return undef if !defined $c;

                $c = decode 'utf-8', $c;
                my $d = NFD($c);

                if ( $d =~ /\x{3099}/ ) {
                    $mark_results{$c} = 'dakuten';
                    return $mark_results{$c};
                }
                if ( $d =~ /\x{309A}/ ) {
                    $mark_results{$c} = 'handakuten';
                    return $mark_results{$c};
                }
                $mark_results{$c} = 'none';
                return $mark_results{$c};
              }
              ->();
            say $result;
            return $result;
        }
    );
    return $schema;
}

sub reset_schema {
    undef $schema;
}
1;
