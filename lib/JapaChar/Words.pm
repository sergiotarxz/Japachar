package JapaChar::Words;

use v5.38.2;

use strict;
use warnings;
use utf8;

use Data::Dumper;

use Mojo::DOM;

use JapaChar::Schema;

use Moo;

use Encode qw/decode/;

has app             => ( is => 'ro', required => 1 );
has _words_schema   => ( is => 'lazy' );
has _options_schema => ( is => 'lazy' );
has _schema         => ( is => 'lazy' );

sub _build__schema($self) {
    return JapaChar::Schema->Schema;
}

sub _build__words_schema($self) {
    return $self->_schema->resultset('Word');
}

sub _build__options_schema($self) {
    return $self->_schema->resultset('Option');
}

sub grades($self) {
    my @grades =
      grep { defined $_ }
      map  { $_->grade }
      $self->_words_schema->search( {},
        { columns => ['grade'], distinct => 1 } );
    return \@grades;
}

sub get_4_incorrect_answers( $self, $word, $guess ) {
    if ( $guess->isa('JapaChar::Schema::Result::WordMeaning') ) {
        my %already_present_guesses;
        my $invalid_results    = [ map { $_->meaning } $word->meanings ];
        my $meanings_resultset = $self->_schema->resultset('WordMeaning');
        my @possible_meanings =
          map { $_->meaning } $meanings_resultset->search(
            {
                -bool   => 'word.started',
                meaning => { -not_in => $invalid_results },
            },
            {
                order_by => { -asc => \'RANDOM()' },
                rows     => 4,
                join     => 'word',
            }
          );
        return \@possible_meanings;
    }
    if ( $guess->isa('JapaChar::Schema::Result::WordRepresentation') ) {
        my %already_present_guesses;
        my $invalid_results = [ map { $_->value } $word->representations ];
        my $readings_resultset =
          $self->_schema->resultset('WordRepresentation');
        my @possible_readings =
          map { $_->value } $readings_resultset->search(
            {
                -bool => 'word.started',
                value => { -not_in => $invalid_results },
                type  => 'hirakana',
            },
            {
                order_by => { -asc => \'RANDOM()' },
                rows     => 4,
                join     => 'word',
            }
          );
        return \@possible_readings;
    }
}

sub migrated($self) {
    my ($option_want_words_version) =
      $self->_options_schema->search( { name => 'want_words_version' } );
    my ($option_words_version) =
      $self->_options_schema->search( { name => 'words_version' } );
    if ( $option_words_version->value >= $option_want_words_version->value ) {
        return 1;
    }
    return 0;
}

{
    my $next = '';
    my $dom  = Mojo::DOM->new->xml(1);

    sub _try_to_find_entry( $self, $fh ) {
        my $buffer      = '';
        my $found_entry = 0;
        while (1) {
            my $return;
            my $char;
            {
                if ( !$next ) {
                    $return = $fh->read( $char, 1000 );
                    $buffer .= $char;
                }
                else {
                    $return = length $next;
                    $buffer .= $next;
                    $next = '';
                }
                if ( !$found_entry ) {
                    my $index = index $buffer, '<entry>';
                    if ( $index == -1 ) {
                        next;
                    }
                    $buffer      = substr $buffer, $index;
                    $found_entry = 1;
                    next;
                }
                my $index = index $buffer, '</entry>';
                if ( $index == -1 ) {
                    next;
                }
                $next   = substr $buffer, $index;
                $buffer = substr $buffer, 0, $index;
                $buffer .= '</entry>';
                my $dom = $dom->parse($buffer);
                return $dom;
            }
            if ( !$return ) {
                return;
            }
        }
    }
}

sub populate_words( $self, $parent_pid, $write ) {
    $self->_schema->txn_do(
        sub {
            my ($option_want_words_version) =
              $self->_options_schema->search(
                { name => 'want_words_version' } );
            my ($option_words_version) =
              $self->_options_schema->search( { name => 'words_version' } );
            if ( $self->migrated ) {
                say 'You already have the words database';
                return;
            }
            say 'Populating Words database, please wait...';
            my $schema = $self->_words_schema;
            my $root   = $self->app->root;
            open my $fh, '<', $root->child('JMdict_e.xml');
            my @words;
            my $word_index                          = 0;
            my $representation_index                = 0;
            my $meaning_index                       = 0;
            my $classification_index                = 0;
            my $representation_classification_index = 0;
            my %classifications;

            $write->print( 213000 . "\n" );
            $write->flush;
            my $tries      = 5;
            my $chunk_size = 1;
            my @times;
            my $time_1 = time;
            my $last_time;
            my $decided_optimal = 0;
            use List::Util qw/sum/;

            while ( my $entry_dom = $self->_try_to_find_entry($fh) ) {
                if ( !kill 0, $parent_pid ) {
                    warn 'Parent died';
                    exit 1;
                }
                my @representations;
                for my $representation ( $entry_dom->find('k_ele,r_ele')->each )
                {
                    if ( my $kanji = $representation->at('keb') ) {
                        my @classifications =
                          $representation->find('ke_pri')->each;
                        @classifications = map { $_->text } @classifications;
                        $kanji           = $kanji->text;
                        push @representations,
                          {
                            id              => $representation_index++,
                            type            => 'kanji',
                            value           => $kanji,
                            classifications => \@classifications,
                          };
                    }
                    if ( my $pronunciation = $representation->at('reb') ) {
                        my @classifications =
                          $representation->find('re_pri')->each;
                        @classifications = map { $_->text } @classifications;
                        $pronunciation   = $pronunciation->text;
                        push @representations,
                          {
                            id              => $representation_index++,
                            type            => 'hirakana',
                            value           => $pronunciation,
                            classifications => \@classifications,
                          };
                    }
                }
                my @meanings;
                for my $meaning ( $entry_dom->find('gloss')->each ) {
                    push @meanings,
                      {
                        id      => $meaning_index++,
                        meaning => $meaning->text
                      };
                }
                my $classifications_resultset =
                  JapaChar::Schema->Schema->resultset('WordClassification');

                for my $representation (@representations) {
                    my $classifications =
                      delete $representation->{classifications};
                    for my $classification (@$classifications) {
                        if ( defined $classifications{$classification} ) {
                            next;
                        }
                        $classifications{$classification} =
                          $classification_index;
                        $classifications_resultset->create(
                            {
                                id    => $classification_index++,
                                value => $classification,
                            },
                        );
                    }
                    if ( scalar @$classifications ) {
                        $representation->{representation_classifications} = [
                            map {
                                {
                                    id =>
                                      $representation_classification_index++,
                                    id_classification => $_,
                                    id_representation => $representation->{id},
                                }
                            } @classifications{@$classifications}
                        ];
                    }
                }
                push @words,
                  {
                    id              => $word_index++,
                    representations => \@representations,
                    meanings        => \@meanings,
                  };
                if ( $word_index % ($word_index > 500 ? $chunk_size : 25) == 0 ) {
                    $self->_words_schema->populate( \@words );
                    $write->syswrite( $word_index . "\n" );
                    $write->flush;
                    @words = ();
                    if ($word_index > 500 && !$decided_optimal ) {
                        next if $tries-- == 5;
                        push @times, ( scalar time ) - $time_1;
                        if ( $tries == 0 ) {
                            my $median_time = sum(@times) / 5;
                            if ( defined $last_time && $last_time < $median_time ) {
                                warn "Optimal chunk size: $chunk_size";
                                $decided_optimal = 1;
                                next;
                            }
                            $tries = 5;
                            $last_time = $median_time;
                            $chunk_size++;
                        }
                        $time_1 = time;
                    }
                }
            }
            $self->_words_schema->populate( \@words );
            $option_words_version->update(
                { value => $option_want_words_version->value } );
            say 'Populated Words database';
        }
    );
    $write->print( 213000 . "\n" );
    $write->flush;
}

sub next_word( $self, $accesibility, $type = undef ) {
    my $next_review   = $self->_next_review_word($type);
    my $next_learning = $self->_next_learning_word($type);
    if ( !defined $next_review ) {
        if ( !defined $next_learning ) {
            die 'Could not find any character';
        }
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

sub _next_review_word( $self, $type = undef ) {
    my $words_resultset = JapaChar::Schema->Schema->resultset('Word');
    my $grade           = $type;
    if ( !defined $type ) {
        $grade = { is => undef };
    }
    my @words = $words_resultset->search(
        {
            score => { '>=' => 300 },
            ( ( $type ne 'all' ) ? ( 'classification.value' => $grade ) : () ),
            'representations.type' => 'kanji',
        },
        {
            order_by => { -asc => \'RANDOM()' },
            rows     => 1,
            join     => {
                representations =>
                  { representation_classifications => 'classification' },
            },
        }
    );
    if ( !@words ) {
        return;
    }
    return $words[0];
}

sub _next_learning_word( $self, $type = undef ) {
    my $words_resultset = JapaChar::Schema->Schema->resultset('Word');
    my @candidate_words = $self->_retrieve_started_words_not_finished($type);
    my $grade           = $type;
    say $grade;
    if ( !defined $type ) {
        $grade = { is => undef };
    }
    if ( @candidate_words < 3 ) {
        my @new_words = $words_resultset->search(
            {
                -not_bool              => 'started',
                'representations.type' => 'kanji',
                (
                    (
                          ( $type ne 'all' )
                        ? ( 'classification.value' => $grade )
                        : ()
                    )
                )
            },
            {
                order_by => {
                    -asc => [
                        \'classification.value IS NULL',
                        'classification.value',
                        'me.id'
                    ]
                },
                rows => 3 - scalar @candidate_words,
                join => {
                    representations =>
                      { representation_classifications => 'classification' },
                },
            }
        );
        for my $word (@new_words) {
            $word->update( { started => 1 } );
        }
        @candidate_words = $self->_retrieve_started_words_not_finished($type);
    }
    my $word = $candidate_words[ int( rand( scalar @candidate_words ) ) ];
    return $word;
}

sub _retrieve_started_words_not_finished( $self, $type ) {
    my $words_resultset = JapaChar::Schema->Schema->resultset('Word');
    my $grade           = $type;
    if ( !defined $type ) {
        $grade = { is => undef };
    }
    return $words_resultset->search(
        {
            (
                  ( $type ne 'all' )
                ? ( 'classification.value' => $grade )
                : (),
                'representations.type' => 'kanji',
            ),
            score => { '<' => 300 },
            -bool => 'started',
        },
        {
            join => {
                representations =>
                  { representation_classifications => 'classification' },
            },
        }
    );
}

sub classifications($self) {
    my $classifications_resultset =
      JapaChar::Schema->Schema->resultset('WordClassification');
    my @classifications = $classifications_resultset->search( {} );
    return [ sort { $a cmp $b } map { $_->value } @classifications ];
}
1;
