package JapaChar::View::HiraganaKatakanaTestExercise;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use Moo;
use Path::Tiny;
use Glib::Object::Introspection;
use YAML::PP;
use JapaChar::DB;
use JapaChar::Characters;
use Pango;
use JapaChar::Random;
use JapaChar::Score;

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

has lesson                     => ( is => 'rw' );
has _type                      => ( is => 'lazy' );
has _app                       => ( is => 'lazy' );
has _buttons                   => ( is => 'rw' );
has _buttons_box               => ( is => 'rw' );
has _first_press_continue      => ( is => 'rw', default => sub { 1 } );
has _continue_button           => ( is => 'rw' );
has _on_resize_continue_button => ( is => 'lazy' );
has _final_answer              => ( is => 'rw' );
has _on_resize_buttons         => ( is => 'lazy' );

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
    my $rng = JapaChar::Random->new->get( 1, 100 );
    if ( $rng > 50 ) {
        $self->_new_challenge_romanji();
        return;
    }
    $self->_new_challenge_kana();
}

sub _new_challenge_kana($self) {
    my $show  = 'kana';
    my $guess = 'romanji';
    $self->_new_challenge_generic_code( $show, $guess, 1 );
}

sub _new_challenge_romanji($self) {
    my $show  = 'romanji';
    my $guess = 'kana';
    $self->_new_challenge_generic_code( $show, $guess );
}

sub _new_challenge_generic_code( $self, $show, $guess, $can_be_typed = 0 ) {
    my $type = $self->_type;
    my $grid = $self->_create_grid_challenge;
    my $char =
      $self->_app->characters->next_char( $self->_app->accessibility, $type );
    my $kana_label = $self->_get_label_featured_character( $char->get($show) );
    my $rng        = JapaChar::Random->new->get( 1, 100 );

    if ( $char->score > 60 && $can_be_typed && $rng > 30 ) {
        $self->_new_typing_romanji_challenge($char);
        return;

    }
    $kana_label->set_halign('center');
    $kana_label->set_valign('center');
    my $box_kana = Gtk::Box->new( 'vertical', 10 );
    $box_kana->append( $self->_new_exercise_number_label );
    $box_kana->append($kana_label);
    $grid->attach( $box_kana, 0, 0, 12, 1 );
    $self->_app->window_set_child($grid);
    my $back_button = $self->lesson->create_exit_lesson_back_button(
        sub {
            $self->_app->delete_on_resize( $self->_on_resize_continue_button );
        }
    );
    $self->_app->headerbar->pack_start($back_button);
    my $incorrect_chars =
      JapaChar::Characters->new->get_4_incorrect_answers($char);
    $self->_app->on_resize( $self->_on_resize_continue_button );
    my @buttons;
    my $continue_button = $self->lesson->create_continue_lesson_button(
        sub {
            $self->_on_click_continue_button( $grid, $char, $guess );
        }
    );
    $self->_continue_button($continue_button);
    $self->_on_resize_continue_button->();
    my $on_answer = sub {
        $continue_button->set_sensitive(1);
    };
    my $correct_answer_button =
      Gtk::ToggleButton->new_with_label( $char->get($guess) );
    $correct_answer_button->signal_connect(
        'clicked',
        sub {
            $self->_final_answer( $char->get($guess) );
            $on_answer->();
        }
    );
    push @buttons, $correct_answer_button;
    $self->_buttons( \@buttons );
    for my $char (@$incorrect_chars) {
        my $incorrect_button =
          Gtk::ToggleButton->new_with_label( $char->get($guess) );
        $incorrect_button->set_group($correct_answer_button);
        $incorrect_button->signal_connect(
            'clicked',
            sub {
                $self->_final_answer( $char->get($guess) );
                $on_answer->();
            }
        );
        push @buttons, $incorrect_button;
    }
    @buttons = sort { rand() <=> rand() } @buttons;
    my $box = Gtk::Box->new( 'horizontal', 10 );
    $box->set_valign('center');
    $box->set_halign('center');

    for my $button (@buttons) {
        $box->append($button);
    }
    $self->_buttons_box($box);
    $self->_on_resize_buttons->();
    $self->_app->on_resize($self->_on_resize_buttons);
    $grid->attach( $box,             0, 2, 12, 1 );
    $grid->attach( $continue_button, 6, 3, 5,  1 );
}

sub _build__on_resize_buttons($self) {
    return sub {
        return if !defined $self->_buttons_box;
        my @buttons     = $self->_buttons->@*;
        my $window_size = $self->_app->get_width;
        for my $button (@buttons) {
            my $attr_list         = Pango::AttrList->new;
            my $size_number       = 45 * $window_size;
            my $size_pango_number = PANGO_SCALE * 60;
            my $size              = Pango::AttrSize->new($size_number);
            if ( $size_pango_number < $size_number ) {
                $size = Pango::AttrSize->new($size_pango_number);
            }
            if ($self->_app->accessibility->is_dyslexia) {
                my $fore_attr = $self->_app->characters->get_color_attr($button->get_child->get_text);
                $attr_list->insert($fore_attr);
            }
            $attr_list->insert($size);
            $button->get_child->set_attributes($attr_list);
        }
    };
}

sub _create_grid_challenge($self) {
    my $grid = Gtk::Grid->new;
    $grid->set_column_homogeneous(1);
    $grid->set_row_homogeneous(1);
    return $grid;
}

sub _get_label_featured_character( $self, $text ) {
    my $label     = Gtk::Label->new($text);
    my $attr_list = Pango::AttrList->new;
    my $size      = Pango::AttrSize->new( 72 * PANGO_SCALE );
    my $color     = Pango::Color->new;

    $attr_list->insert($size);
    my $fore_attr = $self->_app->characters->get_color_attr($text);

    if ( $self->_app->accessibility->is_dyslexia ) {
        $attr_list->insert($fore_attr);
    }
    $label->set_attributes($attr_list);
    $label->set_halign('center');
    return $label;
}

sub _new_typing_romanji_challenge( $self, $char ) {
    my $grid       = $self->_create_grid_challenge;
    my $kana_label = $self->_get_label_featured_character( $char->get('kana') );
    $kana_label->set_halign('center');
    $kana_label->set_valign('center');
    my $box_kana = Gtk::Box->new( 'vertical', 10 );
    $box_kana->append( $self->_new_exercise_number_label );
    $box_kana->append($kana_label);
    $grid->attach( $box_kana, 0, 0, 12, 1 );
    $self->_app->window_set_child($grid);
    my $back_button = $self->lesson->create_exit_lesson_back_button(
        sub {
            $self->_on_exit;
        }
    );
    $self->_app->headerbar->pack_start($back_button);
    my $romanji_entry     = Gtk::Entry->new;
    my $attr_list         = Pango::AttrList->new;
    my $size_number       = 60 * $self->_app->get_width;
    my $size_pango_number = PANGO_SCALE * 60;
    my $size              = Pango::AttrSize->new($size_number);

    if ( $size_pango_number < $size_number ) {
        $size = Pango::AttrSize->new($size_pango_number);
    }
    $attr_list->insert($size);
    $romanji_entry->set_attributes($attr_list);
    my $buffer = $romanji_entry->get_buffer;
    $self->_app->on_resize( $self->_on_resize_continue_button );
    my $continue_button = $self->lesson->create_continue_lesson_button(
        sub {
            $self->_on_click_continue_button( $grid, $char, 'romanji' );
        }
    );
    $self->_continue_button($continue_button);
    $self->_on_resize_continue_button->();
    my $on_change_buffer = sub {
        my $text = $buffer->get_text;
        if ( !$text ) {
            $continue_button->set_sensitive(0);
            return;
        }
        $self->_final_answer( lc($text) );
        $continue_button->set_sensitive(1);
    };
    $buffer->signal_connect(
        'inserted-text',
        sub {
            $on_change_buffer->();
        }
    );
    $buffer->signal_connect(
        'deleted-text',
        sub {
            $on_change_buffer->();
        }
    );

    $romanji_entry->set_valign('center');
    $romanji_entry->set_halign('center');
    $grid->attach( $romanji_entry, 2, 1, 8, 1 );

    $grid->attach( $continue_button, 6, 3, 5, 1 );
}

sub _new_exercise_number_label($self) {
    my $exercise_number = abs( $self->_counter - 11 );
    my $return          = Gtk::Label->new( 'Exercise: ' . $exercise_number );
    $return->set_halign('start');
    return $return;
}

sub _build__on_resize_continue_button($self) {
    return sub {
        my $continue_button = $self->_continue_button;
        my $attr_list       = Pango::AttrList->new;
        my $size = Pango::AttrSize->new( 40 * $self->_app->get_width );

        $attr_list->insert($size);
        $continue_button->get_child->set_attributes($attr_list);
    };
}

sub _on_exit($self) {
    $self->_app->delete_on_resize( $self->_on_resize_buttons );
    $self->_app->delete_on_resize( $self->_on_resize_continue_button );
}

sub _on_click_continue_button( $self, $grid, $char, $guess ) {
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
    my $is_repeating = $self->_app->characters->is_repeated;
    {
        if ( $self->_final_answer eq $char->get($guess) ) {
            $label_feedback = Gtk::Label->new('You are doing it great.');
            $label_feedback->add_css_class('success');
            $self->lesson->add_one_success;
            $char->success if !$is_repeating;
            next;
        }
        $label_feedback = Gtk::Label->new(
            'Meck!! The correct answer is ' . $char->get($guess) );
        $label_feedback->add_css_class('error');
        $char->fail if !$is_repeating;
    }
    if ( $is_repeating && $self->_app->characters->last_repeated ) {

        # TODO This is not ideal.
        $self->success;
    }
    my $attr_list = Pango::AttrList->new;
    my $size      = Pango::AttrSize->new( 23 * $self->_app->get_width );
    $attr_list->insert($size);
    $label_feedback->set_halign('center');
    $label_feedback->set_attributes($attr_list);
    $grid->attach( $label_feedback, 0, 3, 7, 1 );
}
1;
