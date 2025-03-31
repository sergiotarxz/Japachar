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
use JapaChar::View::SelectKanjiLesson;

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
    my $button_start_kanji_lesson = Gtk::Button->new_with_label('Kanji (BETA)');
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
    for my $button (
        $button_start_basic_lesson,    $button_start_hiragana_lesson,
        $button_start_katakana_lesson, $button_start_kanji_lesson
      )
    {
        my $attr_list = Pango::AttrList->new;
        my $size      = Pango::AttrSize->new( 25 * PANGO_SCALE );
        $attr_list->insert($size);
        $button->get_child->set_attributes($attr_list);
    }
    $button_start_kanji_lesson->signal_connect(
        clicked => sub {
            JapaChar::View::SelectKanjiLesson->new( app => $self->app, )->run;
        }
    );
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
    $button_start_kanji_lesson->set_halign('center');
    $button_start_kanji_lesson->set_valign('center');
    $box->set_valign('start');
    $box->set_halign('center');
    $grid->attach( $box,                       0, 1, 5, 1 );
    $grid->attach( $button_start_kanji_lesson, 0, 2, 5, 1 );
    $grid->attach( $button_assisted_mode,      0, 3, 5, 1 );
    $button_assisted_mode->signal_connect(
        'clicked',
        sub {
            $self->app->accessibility->show_assisted_mode_selection;
        }
    );
    $button_assisted_mode->set_vexpand(1);
    $button_assisted_mode->set_hexpand(1);
    $button_assisted_mode->set_valign('center');
    $button_assisted_mode->set_halign('center');
    my $button_discord_community =
      Gtk::Button->new_with_label('Join the discord community');
    $button_discord_community->set_vexpand(1);
    $button_discord_community->set_hexpand(1);
    $button_discord_community->set_valign('center');
    $button_discord_community->set_halign('center');
    $button_discord_community->signal_connect(
        clicked => sub {
            $self->app->launch_discord;
        }
    );
    $grid->attach( $button_discord_community, 0, 4, 5, 1 );
    $self->app->window_set_child($grid);
    my $hamburger_menu = Gtk::Button->new_from_icon_name('open-menu-symbolic');
    $hamburger_menu->signal_connect(
        'clicked',
        sub {
            $self->show_settings;
        }
    );
    $self->app->headerbar->pack_end($hamburger_menu);
}

sub show_settings($self) {
    my $grid = Gtk::Grid->new;
    $grid->set_column_homogeneous(1);
    $self->_create_option(
        $grid,
        'REVIEW_INSTEAD_OF_LEARNING_CHANCE_BASIC',
        sub( $onget, $entry_buffer ) {
            my $text = $entry_buffer->get_text;
            $text = undef if $text =~ /^\s*$/;
            return $onget->() if defined $text && $text !~ /^\d+$/;

            my ($result) =
              JapaChar::Schema->Schema->resultset('Option')->update_or_create(
                {
                    name => JapaChar::Schema::Result::Option
                      ->REVIEW_INSTEAD_OF_LEARNING_CHANCE_BASIC,
                    value => $text,
                }
              );
            return $onget->();
        },
        \&JapaChar::Schema::Result::Option::get_review_instead_of_learning_chance_basic
    );
    $self->_create_option(
        $grid,
        'MAX_NUMBER_SIMULTANEOUS_LEARNING_BASIC_CHARACTERS',
        sub( $onget, $entry_buffer ) {
            my $text = $entry_buffer->get_text;
            $text = undef if $text =~ /^\s*$/;
            return $onget->() if defined $text && $text !~ /^\d+$/;

            my ($result) =
              JapaChar::Schema->Schema->resultset('Option')->update_or_create(
                {
                    name => JapaChar::Schema::Result::Option
                      ->MAX_NUMBER_SIMULTANEOUS_LEARNING_BASIC_CHARACTERS,
                    value => $text,
                }
              );
            return $onget->();
        },
        \&JapaChar::Schema::Result::Option::get_max_number_simultaneous_learning_basic_characters
    );
    $self->_create_option(
        $grid,
        'NEW_CHARACTER_THREESHOLD_BASIC_CHARACTER_INNER_SCORE',
        sub( $onget, $entry_buffer ) {
            my $text = $entry_buffer->get_text;
            $text = undef if $text =~ /^\s*$/;
            return $onget->() if defined $text && $text !~ /^\d+$/;

            my ($result) =
              JapaChar::Schema->Schema->resultset('Option')->update_or_create(
                {
                    name => JapaChar::Schema::Result::Option
                      ->NEW_CHARACTER_THREESHOLD_BASIC_CHARACTER_INNER_SCORE,
                    value => $text,
                }
              );
            return $onget->();
        },
        \&JapaChar::Schema::Result::Option::get_new_character_threeshold_basic_character_inner_score
    );
    $self->_create_option(
        $grid,
        'MAX_INNER_SCORE_BASIC_CHAR',
        sub( $onget, $entry_buffer ) {
            my $text = $entry_buffer->get_text;
            $text = undef if $text =~ /^\s*$/;
            return $onget->() if defined $text && $text !~ /^\d+$/;
            my ($result) =
              JapaChar::Schema->Schema->resultset('Option')->update_or_create(
                {
                    name => JapaChar::Schema::Result::Option
                      ->MAX_INNER_SCORE_BASIC_CHAR,
                    value => $text,
                }
              );
            return $onget->();
        },
        \&JapaChar::Schema::Result::Option::get_max_inner_score_basic_char
    );
    $self->_create_option(
        $grid,
        'SUCCESS_REWARD_BASIC_CHARACTER',
        sub( $onget, $entry_buffer ) {
            my $text = $entry_buffer->get_text;
            $text = undef if $text =~ /^\s*$/;
            return $onget->() if defined $text && $text !~ /^\d+$/;

            my ($result) =
              JapaChar::Schema->Schema->resultset('Option')->update_or_create(
                {
                    name => JapaChar::Schema::Result::Option
                      ->SUCCESS_REWARD_BASIC_CHARACTER,
                    value => $text,
                }
              );
            return $onget->();
        },
        \&JapaChar::Schema::Result::Option::get_success_reward_basic_character
    );
    $self->_create_option(
        $grid,
        'CONSECUTIVE_SUCCESS_REWARD_BASIC_CHARACTER',
        sub( $onget, $entry_buffer ) {
            my $text = $entry_buffer->get_text;
            $text = undef if $text =~ /^\s*$/;
            return $onget->() if defined $text && $text !~ /^\d+$/;

            my ($result) =
              JapaChar::Schema->Schema->resultset('Option')->update_or_create(
                {
                    name => JapaChar::Schema::Result::Option
                      ->CONSECUTIVE_SUCCESS_REWARD_BASIC_CHARACTER,
                    value => $text
                }
              );
            return $onget->();
        },
        \&JapaChar::Schema::Result::Option::get_consecutive_success_reward_basic_character
    );
    $self->app->window_set_child($grid);
    my $back_button = Gtk::Button->new_from_icon_name('go-previous-symbolic');
    $back_button->signal_connect(
        'clicked',
        sub {
            __PACKAGE__->new( app => $self->app )->run;
        }
    );
    $self->app->headerbar->pack_start($back_button);
}

sub _create_option( $self, $grid, $label, $onchange, $onget ) {
    state $row = 0;
    $row++;
    $label = Gtk::Label->new($label);
    $grid->attach( $label, 0, $row, 1, 1 );
    my $inital_text = $onget->();
    my $entry_buffer =
      Gtk::EntryBuffer->new( $inital_text, length $inital_text );
    my $entry = Gtk::Entry->new_with_buffer($entry_buffer);
    require JapaChar::Schema::Result::Option;
    $entry->signal_connect(
        'activate',
        sub {
            my $result = $onchange->( $onget, $entry_buffer );
            if ( defined $result ) {
                $entry_buffer->set_text( $result, length $result );
            }
        }
    );
    $grid->attach( $entry, 1, $row, 1, 1 );
}
1;
