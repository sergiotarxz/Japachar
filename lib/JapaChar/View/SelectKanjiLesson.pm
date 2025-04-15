package JapaChar::View::SelectKanjiLesson;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';
use Forks::Super;

use Moo;

use JapaChar;
use JapaChar::Kanji;
use JapaChar::View::KanjiLesson;

use Glib::Object::Introspection;
use Glib::IO;
use POSIX qw/:sys_wait_h/;

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

has app    => ( is => 'ro' );
has _kanji => ( is => 'lazy' );

sub _build__kanji($self) {
    return JapaChar::Kanji->new( app => JapaChar->new );
}

sub run($self) {
    if ( !$self->_kanji->migrated ) {
        $self->_migrate_kanji;
        return;
    }
    $self->_select_kanji;
}

sub _migrate_kanji($self) {
    my $box          = Gtk::Box->new( 'vertical', 10 );
    my $label        = Gtk::Label->new('Populating Kanji database...');
    my $progress_bar = Gtk::ProgressBar->new;
    $progress_bar->set_halign('center');
    $box->set_vexpand(1);
    $box->set_valign('center');
    $label->set_valign('center');
    $box->append($label);
    $box->append($progress_bar);
    $self->app->window_set_child($box);
    my ( $read, $write );
    pipe $read, $write;
    my $parent_pid = $$;
    my $pid        = fork;

    if ( !$pid ) {
        $self->_kanji->populate_kanji( $parent_pid, $write );
        exit;
    }
    my $n_characters;
    use IO::Select;
    my $select = IO::Select->new;
    $select->add($read);
    my $read_line_generator = sub {
        my $read_newline = 0;
        my $line = '';
        return sub {
            while ($select->can_read(0.01)) {
                read $read, my $char, 1;
                $line .= $char;
                if ($char eq "\n") {
                    $read_newline = 1;
                    last;
                }
            }
            if (!$read_newline) {
                return undef;
            }
            chomp $line;
            return $line + 0;
        };
    };
    my $read_line;
    Glib::Timeout->add(
        1_000,
        sub {
            if (!defined $read_line) {
                $read_line = $read_line_generator->();
            }
            my $n_characters = $read_line->();
            if (!defined $n_characters) {
                return 1;
            }
            undef $read_line; 
            say 'Copying ' . $n_characters . ' kanji';
            Glib::Timeout->add(
                100,
                sub {
                    my $last_number;
                    if (!defined $read_line) {
                        $read_line = $read_line_generator->();
                    }
                    $last_number = $read_line->();
                    if (!defined $last_number) {
                        return 1;
                    }
                    say $last_number;
                    $progress_bar->set_fraction(
                        $last_number / $n_characters );
                    $read_line = undef;
                    if ( 0 == waitpid $pid, WNOHANG ) {
                        return 1;
                    }
                    $self->_select_kanji;
                    return 0;
                }
            );
            return 0;
        }
    );
}

sub _select_kanji($self) {
    my $back_button = Gtk::Button->new_from_icon_name('go-previous-symbolic');
    $back_button->signal_connect(
        'clicked',
        sub {
            require JapaChar::View::MainMenu;
            JapaChar::View::MainMenu->new( app => $self->app )->run;
        }
    );
    my $grades = $self->_kanji->grades;
    my $scroll = Gtk::ScrolledWindow->new;
    my $box    = Gtk::Box->new( 'vertical', 10 );

    my $discord = Gtk::Button->new_with_label('Report bugs and share feedback');

    $discord->signal_connect(
        clicked => sub {
            $self->app->launch_discord;
        }
    );

    $discord->add_css_class('destructive-action');
    $discord->set_halign('center');

    my $label = Gtk::Label->new(
        'This feature is BETA and incomplete will remain free for a long time, we cannot ensure that time is forever though.'
    );
    $label->set_wrap(1);

    $label->set_margin_top(20);
    $box->append($label);

    my $button =
      Gtk::Button->new_with_label("Study everything ordered by grade");
    $button->signal_connect(
        clicked => sub {
            JapaChar::View::KanjiLesson->new( app => $self->app )->run;
        }
    );
    $button->set_margin_top(20);
    $button->add_css_class('accent');
    $button->set_halign('center');
    $button->set_property( 'width-request', 330 );
    $box->append($button);
    for my $grade (@$grades) {
        my $button = Gtk::Button->new_with_label("Study kanji grade $grade");
        $button->signal_connect(
            clicked => sub {
                JapaChar::View::KanjiLesson->new(
                    app  => $self->app,
                    type => $grade
                )->run;
            }
        );
        $button->set_halign('center');
        $button->set_property( 'width-request', 330 );
        $box->append($button);
    }
    $button = Gtk::Button->new_with_label("Study unclassified kanjis");
    $button->signal_connect(
        clicked => sub {
            JapaChar::View::KanjiLesson->new(
                app  => $self->app,
                type => undef
            )->run;
        }
    );
    $button->set_property( 'width-request', 330 );
    $button->set_halign('center');
    $box->append($button);
    $box->append($discord);
    $scroll->set_child($box);
    $self->app->window_set_child($scroll);
    $self->app->headerbar->pack_start($back_button);
}
1;
