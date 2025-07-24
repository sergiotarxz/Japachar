package JapaChar::View::SelectWordLesson;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use Moo;

use JapaChar;
use JapaChar::Words;
use JapaChar::View::WordLesson;

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
has _words => ( is => 'lazy' );

sub _build__words($self) {
    return JapaChar::Words->new( app => JapaChar->new );
}
sub _build__word_classifications($self) {
}

sub run($self) {
    if ( !$self->_words->migrated ) {
        $self->_migrate_words;
        return;
    }
    $self->_select_words;
}

sub _migrate_words($self) {
    my $box          = Gtk::Box->new( 'vertical', 10 );
    my $label        = Gtk::Label->new('Populating Words database...');
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
    if ( $^O eq 'MSWin32' ) {
        if ( -e 'ipc' ) {
            system 'del', 'ipc' and die 'Unable to remove ipc';
        }
        open $write, '>', 'ipc';
        open $read,  '<', 'ipc';
        close $write;
    }
    my $pid        = fork;
    if ( !$pid ) {
        open $write, '>', 'ipc' if $^O eq 'MSWin32';
        $self->_words->populate_words( $parent_pid, $write );
        exit;
    }
    my $n_words;
    use IO::Select;
    my $read_line_generator = sub {
        my $read_newline = 0;
        my $line         = '';
        return sub {
            my $select = IO::Select->new;
            $select->add($read);
            my $check_can_read = sub {
                if ( $^O eq 'MSWin32' ) {
                    seek $read, 0, 1;
                    return !$read->eof;
                }
                return $select->can_read(0.01);
            };
            while ( $check_can_read->() ) {
                read $read, my $char, 1;
                $line .= $char;
                if ( $char eq "\n" ) {
                    $read_newline = 1;
                    last;
                }
            }
            if ( !$read_newline ) {
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
            if ( !defined $read_line ) {
                $read_line = $read_line_generator->();
            }
            my $n_words = $read_line->();
            if ( !defined $n_words ) {
                return 1;
            }
            undef $read_line;
            say 'Copying ' . $n_words . ' words';
            Glib::Timeout->add(
                100,
                sub {
                    my $last_number;
                    if ( !defined $read_line ) {
                        $read_line = $read_line_generator->();
                    }
                    $last_number = $read_line->();
                    if ( !defined $last_number ) {
                        return 1;
                    }
                    say $last_number;
                    $progress_bar->set_fraction( $last_number / $n_words );
                    $read_line = undef;
                    if ( $last_number < $n_words && 0 == waitpid $pid,
                        WNOHANG )
                    {
                        return 1;
                    }
                    $self->_select_words;
                    return 0;
                }
            );
            return 0;
        }
    );
}

sub _select_words($self) {
    my $back_button = Gtk::Button->new_from_icon_name('go-previous-symbolic');
    $back_button->signal_connect(
        'clicked',
        sub {
            require JapaChar::View::MainMenu;
            JapaChar::View::MainMenu->new( app => $self->app )->run;
        }
    );
    my $classifications = $self->_words->classifications;
    my $scroll = Gtk::ScrolledWindow->new;
    my $box    = Gtk::Box->new( 'vertical', 10 );

    my $xmpp = Gtk::Button->new_with_label('Report bugs and share feedback in XMPP');

    $xmpp->signal_connect(
        clicked => sub {
            $self->app->launch_xmpp;
        }
    );

    $xmpp->add_css_class('destructive-action');
    $xmpp->set_halign('center');

    my $discord = Gtk::Button->new_with_label('Report bugs and share feedback in Discord');

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
      Gtk::Button->new_with_label("Study everything ordered by classification");
    $button->signal_connect(
        clicked => sub {
            JapaChar::View::WordLesson->new( app => $self->app )->run;
        }
    );
    $button->set_margin_top(20);
    $button->add_css_class('accent');
    $button->set_halign('center');
    $box->append($button);
    for my $classification (@$classifications) {
        my $button = Gtk::Button->new_with_label("Study words classification $classification");
        $button->signal_connect(
            clicked => sub {
                JapaChar::View::WordLesson->new(
                    app  => $self->app,
                    type => $classification,
                )->run;
            }
        );
        $button->set_halign('center');
        $box->append($button);
    }
    $button = Gtk::Button->new_with_label("Study unclassified words");
    $button->signal_connect(
        clicked => sub {
            JapaChar::View::WordLesson->new(
                app  => $self->app,
                type => undef
            )->run;
        }
    );
    $button->set_halign('center');
    $box->append($button);
    $box->append($xmpp);
    $box->append($discord);
    $scroll->set_child($box);
    $self->app->window_set_child($scroll);
    $self->app->headerbar->pack_start($back_button);
}
1;
