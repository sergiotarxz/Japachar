package JapaChar::Kanji;

use v5.40.0;

use strict;
use warnings;
use utf8;

use Data::Dumper;

use Mojo::DOM;

use JapaChar::Schema;

use Moo;

use List::MoreUtils qw(uniq);

use Encode qw/decode/;

has app             => ( is => 'ro', required => 1 );
has _kanji_schema   => ( is => 'lazy' );
has _options_schema => ( is => 'lazy' );
has _schema         => ( is => 'lazy' );

sub _build__schema($self) {
    return JapaChar::Schema->Schema;
}

sub _build__kanji_schema($self) {
    return $self->_schema->resultset('Kanji');
}

sub _build__options_schema($self) {
    return $self->_schema->resultset('Option');
}

sub grades($self) {
    my @grades =
      grep { defined $_ }
      map  { $_->grade }
      $self->_kanji_schema->search( {},
        { columns => ['grade'], distinct => 1 } );
    return \@grades;
}

sub get_4_incorrect_answers( $self, $char, $guess ) {
    if ( $guess->isa('JapaChar::Schema::Result::KanjiMeanings') ) {
        my %already_present_guesses;
        my $invalid_results    = [ map { $_->meaning } $char->meanings ];
        my $meanings_resultset = $self->_schema->resultset('KanjiMeanings');
        my @possible_meanings =
          map { $_->meaning } $meanings_resultset->search(
            {
                -bool   => 'kanji.started',
                meaning => { -not_in => $invalid_results },
            },
            {
                order_by => { -asc => \'RANDOM()' },
                rows     => 4,
                join     => 'kanji',
            }
          );
        return \@possible_meanings;
    }
    if ( $guess->isa('JapaChar::Schema::Result::KanjiOnReadings') ) {
        my %already_present_guesses;
        my $invalid_results    = [ map { $_->reading } $char->on_readings ];
        my $readings_resultset = $self->_schema->resultset('KanjiOnReadings');
        my @possible_readings =
          map { decode 'utf-8', $_->reading } $readings_resultset->search(
            {
                -bool   => 'kanji.started',
                reading => { -not_in => $invalid_results },
            },
            {
                order_by => { -asc => \'RANDOM()' },
                rows     => 4,
                join     => 'kanji',
            }
          );
        return \@possible_readings;
    }
    if ( $guess->isa('JapaChar::Schema::Result::KanjiKunReadings') ) {
        my %already_present_guesses;
        my $invalid_results    = [ map { $_->reading } $char->kun_readings ];
        my $readings_resultset = $self->_schema->resultset('KanjiOnReadings');
        my @possible_readings =
          map { decode 'utf-8', $_->reading } $readings_resultset->search(
            {
                -bool   => 'kanji.started',
                reading => { -not_in => $invalid_results },
            },
            {
                order_by => { -asc => \'RANDOM()' },
                rows     => 4,
                join     => 'kanji',
            }
          );
        return \@possible_readings;
    }
}

sub migrated($self) {
    my ($option_want_kanji_version) =
      $self->_options_schema->search( { name => 'want_kanji_version' } );
    my ($option_kanji_version) =
      $self->_options_schema->search( { name => 'kanji_version' } );
    if ( $option_kanji_version->value >= $option_want_kanji_version->value ) {
        return 1;
    }
    return 0;
}

sub populate_kanji( $self, $parent_pid, $write ) {
    $self->_schema->txn_do(
        sub {
            my ($option_want_kanji_version) =
              $self->_options_schema->search(
                { name => 'want_kanji_version' } );
            my ($option_kanji_version) =
              $self->_options_schema->search( { name => 'kanji_version' } );
            if ( $self->migrated ) {
                say 'You already have the kanji database';
                return;
            }
            say 'Populating Kanji database, please wait...';
            my $schema = $self->_kanji_schema;
            my $root   = $self->app->root;
            my $dom =
              Mojo::DOM->new( $root->child('kanjidic2.xml')->slurp_raw );
            $dom->xml(1);
            my @characters;
            my $i = 0;

            my @characters_dom =
              grep { $_->type eq 'tag' && $_->tag eq 'character' }
              $dom->at('kanjidic2')->child_nodes->each;
            $write->syswrite( ( scalar @characters_dom ) . "\n" );
            $write->flush;
            for my $character_dom (@characters_dom) {
                if ( !kill 0, $parent_pid ) {
                    die 'Parent died';
                }
                my $literal = $character_dom->at('literal')->text;
                $literal = decode 'utf-8', $literal;
                my $grade;
                my $grade_dom = $character_dom->at('grade');
                if ( defined $grade_dom ) {
                    $grade = $grade_dom->text;
                }
                my @meanings;
                for my $meaning_dom ( $character_dom->find('meaning')->each ) {
                    next if scalar %{ $meaning_dom->attr };
                    push @meanings, { meaning => $meaning_dom->text, };
                }
                my @readings_on;
                my @readings_kun;
                my $die = 0;
                binmode STDOUT, ':utf8';
                for my $reading_dom ( $character_dom->find('reading')->each ) {
                    my $reading = $reading_dom->text;
                    $reading = decode 'utf-8', $reading;
                    $reading =~ s/\..*?$//;
                    $reading =~ s/-//g;
                    $reading =~ s/^\s*(.*?)\s*$/$1/;
                    if ( $reading_dom->attr('r_type') eq 'ja_on' ) {
                        push @readings_on, { reading => $reading, };
                    }
                    if ( $reading_dom->attr('r_type') eq 'ja_kun' ) {
                        push @readings_kun, { reading => $reading, };
                    }
                }
                my %readings_on  = map { $_->{reading} => $_ } @readings_on;
                my %readings_kun = map { $_->{reading} => $_ } @readings_kun;

                @readings_on = map { $readings_on{$_} }
                  sort { $a cmp $b } keys %readings_on;
                @readings_kun = map { $readings_kun{$_} }
                  sort { $a cmp $b } keys %readings_kun;

                push @characters,
                  {
                    id           => $i++,
                    kanji        => $literal,
                    grade        => $grade,
                    meanings     => \@meanings,
                    on_readings  => \@readings_on,
                    kun_readings => \@readings_kun,
                  };
                if ( $i % 300 == 0 ) {
                    $self->_kanji_schema->populate( \@characters );
                    $write->syswrite( $i . "\n" );
                    $write->flush;
                    @characters = ();
                }
            }
            $self->_kanji_schema->populate( \@characters );
            $write->syswrite( scalar @characters_dom . "\n" );
            $write->flush;
            $option_kanji_version->update(
                { value => $option_want_kanji_version->value } );
            say 'Populated kanji database';
        }
    );
}

sub next_char( $self, $accesibility, $type = undef ) {
    my $next_review   = $self->_next_review_char($type);
    my $next_learning = $self->_next_learning_char($type);
    if ( !defined $next_review ) {
        return $next_learning;
    }
    if ( !defined $next_learning ) {
        return $next_review;
    }
    my $rng = JapaChar::Random->new->get( 1, 100 );
    if ( $rng > 20 ) {
        return $next_learning;
    }
    return $next_review;
}

sub _next_review_char( $self, $type = undef ) {
    my $kanji_resultset = JapaChar::Schema->Schema->resultset('Kanji');
    my @chars           = $kanji_resultset->search(
        {
            score => { '>=' => 300 },
            ( ( $type ne 'all' ) ? ( grade => { is => $type } ) : () )
        },
        {
            order_by => { -asc => \'RANDOM()' },
            rows     => 1
        }
    );
    if ( !@chars ) {
        return;
    }
    return $chars[0];
}

sub _next_learning_char( $self, $type = undef ) {
    my $kanji_resultset = JapaChar::Schema->Schema->resultset('Kanji');
    my @candidate_chars = $self->_retrieve_started_chars_not_finished($type);
    if ( @candidate_chars < 5 ) {
        my @new_chars = $kanji_resultset->search(
            {
                -not_bool => 'started',
                ( ( $type ne 'all' ) ? ( grade => { is => $type } ) : () )
            },
            {
                order_by => { -asc => [ \'grade IS NULL', 'grade', 'id' ] },
                rows     => 5 - scalar @candidate_chars,
            }
        );
        for my $char (@new_chars) {
            $char->update( { started => 1 } );
        }
        @candidate_chars = $self->_retrieve_started_chars_not_finished($type);
    }
    my $char = $candidate_chars[ int( rand( scalar @candidate_chars ) ) ];
    return $char;
}

sub _retrieve_started_chars_not_finished( $self, $type ) {
    my $kanji_resultset = JapaChar::Schema->Schema->resultset('Kanji');
    return $kanji_resultset->search(
        {
            ( ( $type ne 'all' ) ? ( grade => { is => $type } ) : () ),
            score => { '<' => 100 },
            -bool => 'started',
        }
    );
}
1;
