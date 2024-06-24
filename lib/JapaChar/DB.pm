package JapaChar::DB;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use DBI;
use DBD::SQLite;

use JapaChar::DB::Migrations;
use Path::Tiny;
use Data::Dumper;

my $dbh;

sub connect {
    if ( defined $dbh ) {
        return $dbh;
    }
    my $class    = shift;
    require JapaChar;
    my $app      = JapaChar->new;
    my $config   = $app->config;
    my $db_path = $class->_db_path;
    $dbh = DBI->connect(
        'dbi:SQLite:dbname='.$db_path,
        undef, undef,
        {
            RaiseError => 1,
        },
    );
    $class->_migrate($dbh);
    return $dbh;
}

sub _db_path($class) {
    my $home = $ENV{HOME};
    my $db_path = '';
    $db_path = $home . '/' if $home; 
    $db_path .= '.japachar/db.sqlite';
    path($db_path)->parent->mkpath;
    return $db_path;
}

sub _migrate {
    my $class = shift;
    my $dbh   = shift;
    local $dbh->{RaiseError} = 0;
    local $dbh->{PrintError} = 0;
    my @migrations = JapaChar::DB::Migrations::MIGRATIONS();
    if ( $class->get_current_migration($dbh) > @migrations ) {
        warn "Something happened there, wrong migration number.";
    }
    if ( $class->get_current_migration($dbh) >= @migrations ) {
        say STDERR "Migrations already applied.";
        return;
    }
    $class->_apply_migrations( $dbh, \@migrations );
}

sub _apply_migrations {
    my $class      = shift;
    my $dbh        = shift;
    my $migrations = shift;
    for (
        my $i = $class->get_current_migration($dbh) ;
        $i < @$migrations ;
        $i++
      )
    {
        local $dbh->{RaiseError} = 1;
        my $current_migration = $migrations->[$i];
        my $migration_number  = $i + 1;
        $class->_apply_migration( $dbh, $current_migration, $migration_number );
    }
}

sub _apply_migration {
    my $class             = shift;
    my $dbh               = shift;
    my $current_migration = shift;
    my $migration_number  = shift;
    {
        if (ref $current_migration eq 'CODE') {
            $current_migration->($dbh);
            next;
        }
        $dbh->do($current_migration);
    }
    $dbh->do( <<'EOF', undef, 'current_migration', $migration_number );
INSERT INTO options
VALUES ($1, $2) 
ON CONFLICT (name) DO 
UPDATE SET value = $2;
EOF
}

sub get_current_migration {
    my $class  = shift;
    my $dbh    = shift;
    my $result = $dbh->selectrow_hashref( <<'EOF', undef, 'current_migration' );
select value from options where name = ?;
EOF
    return int( $result->{value} // 0 );
}
1;
