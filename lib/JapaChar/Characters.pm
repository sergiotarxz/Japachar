package JapaChar::Characters;

use v5.38.2;

use strict;
use warnings;

use Moo;
use Path::Tiny;
use JSON;
use Data::Dumper;
use Encode      qw(encode);
use Digest::SHA qw(sha1_hex);

use JapaChar::Random;

my $option_populated = 'populated_basic_characters';
require JapaChar::DB;
require JapaChar::Schema;

has is_repeated => ( is => 'rw', default => sub { 0 } );
has _times_repeated => ( is => 'rw', default => sub { 0 });

sub populate_basic_characters($self) {
    my $dbh    = JapaChar::DB->connect;
    my $result = $dbh->selectrow_hashref(
        'SELECT value
FROM options 
WHERE name = ?', {}, $option_populated
    );
    if ( defined $result && $result->{value} ) {
        return;
    }
    $self->_populate_type('hiragana');
    $self->_populate_type('katakana');
    $dbh->do( 'INSERT INTO options (name, value) VALUES (?, ?);',
        undef, $option_populated, 1 );
}

sub _populate_type( $self, $type ) {
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    my @array_for_insertion;
    for my $char ( @{ $self->_get_characters_of_type($type) } ) {
        my $kana    = $char->{kana};
        my $romanji = $char->{roumaji};
        next if $romanji =~ /pause/i;
        push @array_for_insertion,
          { value => $kana, romanji => $romanji, type => $type };
    }
    $basic_character_resultset->populate( [@array_for_insertion] );
}

sub _get_characters_of_type( $self, $type ) {
    my $current_file = path __FILE__;
    require JapaChar;
    my $array =
      from_json( JapaChar->root->child("$type.json")
          ->slurp_utf8 );
    return $array;
}

sub get_4_incorrect_answers( $self, $char ) {
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    my @bad_answers = $basic_character_resultset->search(
        {
            type    => $char->type,
            value   => { '!=', $char->value },
            romanji => { '!=', $char->romanji },
            -bool   => 'started',
        },
        {
            order_by => { -asc => \'RANDOM()' },
            rows     => 4,
        }
    );
    return \@bad_answers;
}

sub _next_review_char( $self, $type = undef ) {
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    my @chars = $basic_character_resultset->search(
        {
            score => { '>=' => 100 },
            ( ( defined $type ) ? ( type => $type, ) : () )
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

sub _try_next_char_dyslexia($self, $type = undef) {
    my $next_repeated_character = $self->_next_repeated_character($type);
    if ( !defined $next_repeated_character ) {
        return;
    }
    $self->is_repeated(1);
    $self->_times_repeated($self->_times_repeated + 1);
    if ($self->_times_repeated > 4) {
        $self->is_repeated(0);
        $self->_times_repeated(0);
        return;
    }
    return $next_repeated_character;
}

sub last_repeated($self) {
    return $self->_times_repeated >= 4;
}

sub next_char( $self, $accesibility, $type = undef ) {
    if ( $accesibility->is_dyslexia ) {
        my $dyslexia_char = $self->_try_next_char_dyslexia;
        return $dyslexia_char if defined $dyslexia_char;
    }
    $self->is_repeated(0);
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

sub _next_repeated_character( $self, $type = undef ) {
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    my ($char) = $basic_character_resultset->search(
        {
            consecutive_failures => { '>=' => 3 },
        },
        {
            order_by => { -asc => 'id' },
        }
    );
    return $char;
}

sub _next_learning_char( $self, $type = undef ) {
    $self->populate_basic_characters;
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    my @candidate_chars = $self->_retrieve_started_chars_not_finished($type);
    if ( @candidate_chars < 5 ) {
        my @new_chars = $basic_character_resultset->search(
            {
                -not_bool => 'started',
                ( ( defined $type ) ? ( type => $type, ) : () )
            },
            {
                order_by => { -asc => 'id' },
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
    my $basic_character_resultset =
      JapaChar::Schema->Schema->resultset('BasicCharacter');
    return $basic_character_resultset->search(
        {
            ( ( defined $type ) ? ( type => $type, ) : () ),
            score => { '<' => 100 },
            -bool => 'started',
        }
    );
}

sub get_color_attr($self, $text) {
    my $style_manager = Adw::StyleManager::get_default();
    my $hex_color     = sha1_hex( encode 'utf-8', $text);
    my @foreground =
      map { $_ & 0xffff }
      map { int($_ * ( $style_manager->get_dark ? 2 : 0.5 )) }
      map { ( $_ << 8 ) | $_ }
      map { $_ = hex $_; } $hex_color =~ /(..)(..)(..)/;
    my $fore_attr = Pango::AttrForeground->new(@foreground);
    return $fore_attr;
}
1;
