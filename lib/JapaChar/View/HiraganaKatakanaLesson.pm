package JapaChar::View::HiraganaKatakanaLesson;

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

has app        => ( is => 'ro' );
has type       => ( is => 'ro' );
has counter    => ( is => 'rw' );
has _successes => ( is => 'rw' );

sub run($self) {
    $self->counter(11);
    $self->_show_start_lesson;
}

sub _show_start_lesson($self) {
    my $type        = $self->type;
    my $box         = Gtk::Box->new( 'vertical', 0 );
    my $back_button = Gtk::Button->new_from_icon_name('go-previous-symbolic');
    my $intro       = Gtk::Label->new('This lesson has 10 exercises.');
    my $intro2      = Gtk::Label->new('10 points on completion.');
    my $intro3      = Gtk::Label->new('10 extra points if you do it very well');
    $intro->set_margin_top(50);
    $box->append($intro);
    $box->append($intro2);
    $box->append($intro3);
    my $continue_button = Gtk::Button->new_with_label('Continue');
    $continue_button->add_css_class('accent');
    my $resize = sub {
        my $attr_list         = Pango::AttrList->new;
        my $size_number       = 30 * $self->app->get_width;
        my $size_pango_number = PANGO_SCALE * 60;
        my $size              = Pango::AttrSize->new($size_number);

        if ( $size_pango_number < $size_number ) {
            $size = Pango::AttrSize->new($size_pango_number);
        }
        $attr_list->insert($size);
        $intro->set_attributes($attr_list);
        $intro2->set_attributes($attr_list);
        $intro3->set_attributes($attr_list);
        $continue_button->get_child->set_attributes($attr_list);
    };
    $resize->();
    $self->app->on_resize($resize);
    $continue_button->signal_connect(
        'clicked',
        sub {
            $self->app->delete_on_resize($resize);
            $continue_button->set_sensitive(0);
            $self->_successes(0);
            require JapaChar::View::HiraganaKatakanaTestExercise;
            JapaChar::View::HiraganaKatakanaTestExercise->new( lesson => $self )
              ->run;
        }
    );
    $box->append($continue_button);
    $continue_button->set_halign('end');
    $continue_button->set_valign('end');
    $continue_button->set_vexpand(1);
    $back_button->signal_connect(
        'clicked',
        sub {
            $self->app->delete_on_resize($resize);
            require JapaChar::View::MainMenu;
            JapaChar::View::MainMenu->new( app => $self->app )->run;
        }
    );
    $continue_button->set_margin_end(50);
    $continue_button->set_margin_bottom(50);
    $self->app->window_set_child($box);
    $self->app->headerbar->pack_start($back_button);
}

sub create_continue_lesson_button( $self, $on_click ) {
    my $type            = $self->type;
    my $continue_button = Gtk::Button->new_with_label('Continue');
    $continue_button->set_valign('center');
    $continue_button->set_halign('end');
    $continue_button->set_sensitive(0);
    $continue_button->add_css_class('accent');
    $continue_button->signal_connect( 'clicked', $on_click, );
    return $continue_button;
}

sub add_one_success($self) {
    $self->_successes( $self->_successes + 1 );
}

sub create_exit_lesson_back_button( $self, $on_exit ) {
    my $back_button = Gtk::Button->new_from_icon_name('go-previous-symbolic');
    $back_button->signal_connect(
        'clicked',
        sub {
            $back_button->set_sensitive(0);
            my $dialog = Adw::AlertDialog->new( 'Exit the lessson',
                'On exit you will lose your progress' );
            $dialog->add_response( 'close', 'Continue' );
            my $exit_the_lesson_id = 'exit-the-lesson';
            $dialog->add_response( $exit_the_lesson_id, 'Exit' );
            $dialog->set_response_appearance( $exit_the_lesson_id,
                'destructive' );
            $self->app->present_dialog($dialog);
            $dialog->signal_connect(
                'response',
                sub( $obj, $response ) {
                    if ( $response eq $exit_the_lesson_id ) {
                        $on_exit->();
                        require JapaChar::View::MainMenu;
                        JapaChar::View::MainMenu->new( app => $self )->run;
                        return;
                    }
                }
            );
        }
    );
    return $back_button;
}

sub finish_lesson_screen($self) {
    my $notable_lesson = $self->_successes >= 7;
    my $feedback_label;
    my $box = Gtk::Box->new( 'vertical', 10 );
    if ($notable_lesson) {
        $feedback_label =
          Gtk::Label->new('You did it great, here you have your 20 points.');
    }
    else {
        $feedback_label = Gtk::Label->new(
            'You need to continue improving, we have 10 points for you');
    }

    my $continue_button = Gtk::Button->new_with_label('Continue');
    $continue_button->add_css_class('accent');
    $continue_button->set_halign('end');
    $continue_button->set_valign('end');
    $continue_button->set_vexpand(1);
    $feedback_label->set_valign('center');
    $feedback_label->set_halign('center');
    $feedback_label->set_vexpand(1);
    my $resize = sub {
        my $attr_list         = Pango::AttrList->new;
        my $size_number       = 20 * $self->app->get_width;
        my $size_pango_number = PANGO_SCALE * 35;
        my $size              = Pango::AttrSize->new($size_number);

        if ( $size_pango_number < $size_number ) {
            $size = Pango::AttrSize->new($size_pango_number);
        }
        $attr_list->insert($size);
        $feedback_label->set_attributes($attr_list);
        $continue_button->get_child->set_attributes($attr_list);
    };
    $self->app->on_resize($resize);
    $continue_button->set_margin_end(50);
    $continue_button->set_margin_bottom(50);
    $resize->();
    $box->append($feedback_label);
    $box->append($continue_button);
    $continue_button->signal_connect(
        'clicked',
        sub {
            $self->app->delete_on_resize($resize);
            JapaChar::Score->sum( $notable_lesson ? 20 : 10 );
            $continue_button->set_sensitive(0);
            require JapaChar::View::MainMenu;
            JapaChar::View::MainMenu->new( app => $self->app )->run;
        }
    );
    $self->app->window_set_child($box);
}

1;
