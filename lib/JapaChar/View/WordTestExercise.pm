package JapaChar::View::WordTestExercise;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use Encode qw/decode/;

use Moo;
use Path::Tiny;
use Glib::Object::Introspection;
use YAML::PP;
use JapaChar::DB;
use JapaChar::Words;
use Pango;
use JapaChar::Random;
use JapaChar::Score;

use Glib;
use Glib::IO;

use constant PANGO_SCALE => 1024;

Glib::Object::Introspection->setup(
    basename => 'Gtk',
    version  => '4.0',
    package  => 'Gtk',
);

Glib::Object::Introspection->setup(
    basename => 'Gdk',
    version  => '4.0',
    package  => 'Gtk::Gdk',
);

Glib::Object::Introspection->setup(
    basename => 'Gsk',
    version  => '4.0',
    package  => 'Gtk::Gsk',
);

Glib::Object::Introspection->setup(
    basename => 'Adw',
    version  => '1',
    package  => 'Adw',
);

has lesson                => ( is => 'rw' );
has _type                 => ( is => 'lazy' );
has _app                  => ( is => 'lazy' );
has _buttons              => ( is => 'rw' );
has _buttons_box          => ( is => 'rw' );
has _first_press_continue => ( is => 'rw', default => sub { 1 } );
has _continue_button      => ( is => 'rw' );
has _final_answer         => ( is => 'rw' );

sub _counter($self) {
    return $self->lesson->counter;
}

sub _build__type($self) {
    return $self->lesson->type;
}

sub _build__app($self) {
    return $self->lesson->app;
}

sub run($self) {
    $self->lesson->counter( $self->_counter - 1 );
    if ( $self->_counter < 1 ) {
        $self->lesson->finish_lesson_screen();
        return;
    }
    my $word =
      $self->_app->words->next_word( $self->_app->accessibility, $self->_type );
    my @available_guessses = (
        $word->representations->search( { type => 'hirakana' } ),
        $word->meanings,
    );
    my $rng = 0;
    if ( @available_guessses > 1 ) {
        $rng = JapaChar::Random->new->get( 0, scalar(@available_guessses) - 1 );
    }
    $self->_create_challenge( $word, $available_guessses[$rng] );
}

sub guess_to_string( $self, $guess ) {
    return $guess->meaning
      if $guess->isa('JapaChar::Schema::Result::WordMeaning');
    return $guess->value;
}

sub _create_challenge( $self, $word, $guess ) {
    my $scroll = Gtk::ScrolledWindow->new;
    my $grid = $self->_create_grid_challenge;
    $scroll->set_child($grid);
    my @kanji_representations =
      $word->representations->search( { type => 'kanji' } );
    my $rng = 0;
    if ( @kanji_representations > 1 ) {
        $rng =
          JapaChar::Random->new->get( 0, scalar(@kanji_representations) - 1 );
    }
    my $word_label =
      $self->_get_label_featured_word( $kanji_representations[$rng]->value );
    $word_label->set_halign('center');
    $word_label->set_valign('center');
    my $exercise_type;
    my $exercise_type_class;
    if ( $guess->isa('JapaChar::Schema::Result::WordMeaning') ) {
        $exercise_type       = 'Meaning';
        $exercise_type_class = 'meaning';
    }
    if ( $guess->isa('JapaChar::Schema::Result::WordRepresentation') ) {
        $exercise_type       = 'Reading';
        $exercise_type_class = 'reading';
    }
    my $exercise_label = Gtk::Label->new($exercise_type);
    $exercise_label->add_css_class('exercise_type');
    $exercise_label->add_css_class($exercise_type_class);
    $exercise_label->set_halign('center');
    my $box_word = Gtk::Box->new( 'vertical', 10 );
    $box_word->append( $self->_new_exercise_number_label );
    $box_word->append($word_label);
    $box_word->append($exercise_label);
    $grid->attach( $box_word, 0, 0, 12, 4 );
    $self->_app->window_set_child($scroll);
    my $back_button = $self->lesson->create_exit_lesson_back_button(
        sub {
        }
    );
    $self->_app->headerbar->pack_start($back_button);
    my $incorrect_answers =
      $self->_app->words->get_4_incorrect_answers( $word, $guess );
    my @buttons;
    my $continue_button = $self->lesson->create_continue_lesson_button(
        sub {
            $self->_on_click_continue_button( $grid, $word, $guess );
        }
    );
    $self->_continue_button($continue_button);
    my $on_answer = sub ($correct) {
        $continue_button->set_sensitive(1);
    };
    my $correct_answer_button =
      Gtk::ToggleButton->new_with_label( $self->guess_to_string($guess) );
    $correct_answer_button->signal_connect(
        'clicked',
        sub {
            $self->_final_answer( $self->guess_to_string($guess) );
            $on_answer->(1);
        }
    );
    push @buttons, $correct_answer_button;
    $self->_buttons( \@buttons );
    for my $bad_answer (@$incorrect_answers) {
        my $incorrect_button = Gtk::ToggleButton->new_with_label($bad_answer);
        $incorrect_button->set_group($correct_answer_button);
        $incorrect_button->signal_connect(
            'clicked',
            sub {
                $self->_final_answer($bad_answer);
                $on_answer->(0);
            }
        );
        push @buttons, $incorrect_button;
    }
    @buttons = sort { rand() <=> rand() } @buttons;
    my $box = Gtk::Box->new( 'horizontal', 10 );
    $box->set_valign('center');
    $box->set_halign('center');
    if ($guess->isa('JapaChar::Schema::Result::WordMeaning')) {
        $box->set_orientation('vertical');
        $box->set_halign('fill');
        $box->set_valign('start');
    }

    for my $button (@buttons) {
        $button->add_css_class('kanji-button');
        $box->append($button);
    }
    my $scroll_buttons = Gtk::ScrolledWindow->new;
    $scroll_buttons->set_policy( 'automatic', 'never' );
    $self->_buttons_box($box);
    $scroll_buttons->set_child($box);
    $grid->attach( $scroll_buttons,          0, 2, 12, 1 );
    $grid->attach( $continue_button, 6, 3, 5,  1 );
}

sub _create_grid_challenge($self) {
    my $grid = Gtk::Grid->new;
    $grid->set_column_homogeneous(1);
    $grid->set_row_homogeneous(1);
    return $grid;
}

sub _get_label_featured_word( $self, $text ) {
    my $label     = Gtk::Label->new($text);
    my $attr_list = Pango::AttrList->new;
    my $size      = Pango::AttrSize->new( 20 * PANGO_SCALE );
    my $color     = Pango::Color->new;

    $attr_list->insert($size);
    my $fore_attr = $self->_app->characters->get_color_attr($text);

    $label->set_attributes($attr_list);
    $label->set_halign('center');
    return $label;
}

sub _new_exercise_number_label($self) {
    my $exercise_number = abs( $self->_counter - 31 );
    my $return          = Gtk::Label->new( 'Exercise: ' . $exercise_number );
    $return->set_halign('start');
    return $return;
}

sub _on_exit($self) {
}

sub _on_click_continue_button( $self, $grid, $word, $guess ) {
    my $continue_button = $self->_continue_button;
    if ( defined $self->_buttons ) {
        for my $button ( $self->_buttons->@* ) {
            $button->set_sensitive(0);
        }
    }
    if ( !$self->_first_press_continue ) {
        $self->_on_exit;
        $continue_button->set_sensitive(0);
        $self->new( lesson => $self->lesson )->run;
        return;
    }
    $self->_first_press_continue(0);
    my $label_feedback;
    {
        if ( $self->_final_answer eq $self->guess_to_string($guess) ) {
            $label_feedback = Gtk::Label->new('You are doing it great.');
            $label_feedback->add_css_class('success');
            $self->lesson->add_one_success;
            $word->success;
            next;
        }
        $label_feedback = Gtk::Label->new(
            'Meck!! The correct answer is ' . $self->guess_to_string($guess) );
        $label_feedback->add_css_class('error');
        $word->fail;
        $continue_button->set_sensitive(0);
        Glib::Timeout->add_seconds(
            1,
            sub {
                $continue_button->set_sensitive(1);
                return 0;
            }
        );
    }

    my $attr_list = Pango::AttrList->new;
    my $size      = Pango::AttrSize->new( 15 * $self->_app->get_width );
    $attr_list->insert($size);
    $label_feedback->set_halign('center');
    $label_feedback->set_attributes($attr_list);
    $grid->attach( $label_feedback, 0, 3, 7, 1 );
}
1;
