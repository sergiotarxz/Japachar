package JapaChar::View::MainMenu;

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
use JapaChar::View::HiraganaKatakanaLesson;

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

has app => ( is => 'ro' );

sub run($self) {
    my $grid = Gtk::Grid->new;
    my $button_start_basic_lesson =
      Gtk::Button->new_with_label('Basic Characters');
    $button_start_basic_lesson->signal_connect(
        'clicked',
        sub {
            my $lesson =
              JapaChar::View::HiraganaKatakanaLesson->new( app => $self->app );
            $lesson->run;
        }
    );
    $grid->set_column_homogeneous(1);
    $grid->set_row_homogeneous(1);
    my $button_start_hiragana_lesson = Gtk::Button->new_with_label('Hiragana');
    $button_start_hiragana_lesson->signal_connect(
        'clicked',
        sub {
            my $lesson = JapaChar::View::HiraganaKatakanaLesson->new(
                app  => $self->app,
                type => 'hiragana'
            );
            $lesson->run;
        }
    );
    my $button_start_katakana_lesson = Gtk::Button->new_with_label('Katakana');
    $button_start_katakana_lesson->signal_connect(
        'clicked',
        sub {
            my $lesson = JapaChar::View::HiraganaKatakanaLesson->new(
                app  => $self->app,
                type => 'katakana'
            );
            $lesson->run;
        }
    );
    for my $button ( $button_start_basic_lesson, $button_start_hiragana_lesson,
        $button_start_katakana_lesson )
    {
        my $attr_list = Pango::AttrList->new;
        my $size      = Pango::AttrSize->new( 25 * PANGO_SCALE );
        $attr_list->insert($size);
        $button->get_child->set_attributes($attr_list);
    }
    my $box                    = Gtk::Box->new( 'horizontal', 10 );
    my $box_score_basic_lesson = Gtk::Box->new( 'vertical',   10 );
    my $score_label =
      Gtk::Label->new("Total Score: @{[JapaChar::Score->new->get]}");
    $box_score_basic_lesson->append($score_label);
    $box_score_basic_lesson->append($button_start_basic_lesson);
    $score_label->set_halign('start');
    $score_label->set_valign('start');
    $box_score_basic_lesson->set_vexpand(1);
    $button_start_basic_lesson->set_vexpand(1);
    $button_start_basic_lesson->set_valign('end');
    $grid->attach( $box_score_basic_lesson, 0, 0, 5, 1 );
    $button_start_basic_lesson->set_valign('end');
    $button_start_basic_lesson->set_halign('center');
    my $button_assisted_mode = Gtk::Button->new_with_label('Assisted Mode');
    $box->set_margin_top(40);
    $box->append($button_start_hiragana_lesson);
    $box->append($button_start_katakana_lesson);
    $box->set_valign('start');
    $box->set_halign('center');
    $grid->attach( $box, 0, 1, 5, 1 );
    $grid->attach( $button_assisted_mode, 0, 2, 5, 1 );
    $button_assisted_mode->signal_connect('clicked', sub {
        $self->app->accessibility->show_assisted_mode_selection;
    });
    $button_assisted_mode->set_vexpand(1);
    $button_assisted_mode->set_hexpand(1);
    $button_assisted_mode->set_valign('center');
    $button_assisted_mode->set_halign('center');
    $self->app->window_set_child($grid);
}
1;
