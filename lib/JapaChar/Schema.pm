package JapaChar::Schema;

use v5.36.0;

use strict;
use warnings;

use Unicode::Normalize qw(NFD);
use Encode qw/decode/;

use feature 'signatures';

use parent 'DBIx::Class::Schema';

use JapaChar::Schema::Result::BasicCharacter;
use JapaChar::Schema::Result::KanjiKunReadings;
use JapaChar::Schema::Result::KanjiMeanings;
use JapaChar::Schema::Result::KanjiOnReadings;
use JapaChar::Schema::Result::Kanji;
use JapaChar::Schema::Result::Option;
use JapaChar::Schema::Result::WordClassification;
use JapaChar::Schema::Result::WordMeaning;
use JapaChar::Schema::Result::Word;
use JapaChar::Schema::Result::WordRepresentationClassification;
use JapaChar::Schema::Result::WordRepresentation;

__PACKAGE__->register_class(
    BasicCharacter => 'JapaChar::Schema::Result::BasicCharacter',
    KanjiKunReadings => 'JapaChar::Schema::Result::KanjiKunReadings',
    KanjiMeanings => 'JapaChar::Schema::Result::KanjiMeanings',
    KanjiOnReadings => 'JapaChar::Schema::Result::KanjiOnReadings',
    Kanji => 'JapaChar::Schema::Result::Kanji',
    Option => 'JapaChar::Schema::Result::Option',
    WordClassification => 'JapaChar::Schema::Result::WordClassification',
    WordMeaning => 'JapaChar::Schema::Result::WordMeaning',
    Word => 'JapaChar::Schema::Result::Word',
    WordRepresentationClassification => 'JapaChar::Schema::Result::WordRepresentationClassification',
    WordRepresentation => 'JapaChar::Schema::Result::WordRepresentation',
);

my $schema;
sub Schema ($class) {
    return $schema if defined $schema;
    require JapaChar::DB;
    JapaChar::DB->connect;
    require JapaChar;
    my $app = JapaChar->new;
    my $db_path = JapaChar::DB->_db_path($app);
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
            return $result;
        }
    );
    return $schema;
}

sub reset_schema {
    undef $schema;
}
1;
