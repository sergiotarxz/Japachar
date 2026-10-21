package JapaChar::View::SelectHiraganaKatakanaLesson;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use Moo;

use JapaChar;
use JapaChar::Kanji;
use JapaChar::View::KanjiLesson;

use POSIX qw/:sys_wait_h/;

has app    => ( is => 'ro' );
has mark       => ( is => 'ro' );
has type       => ( is => 'ro' );

sub run($self) {
    $self->_select_mark;
}

sub _select_mark($self) {
    my $back_button = Gtk::Button->new_from_icon_name('go-previous-symbolic');
    $back_button->connect(
        'clicked',
        sub {
            require JapaChar::View::MainMenu;
            JapaChar::View::MainMenu->new( app => $self->app )->run;
        }
    );
    my $scroll = Gtk::ScrolledWindow->new;
    my $const        = AlgaGTK::Constants->new;
    my $box    = Gtk::Box->new( $const->GTK_ORIENTATION_VERTICAL, 10 );

    my $label = Gtk::Label->new(
'This feature is BETA and incomplete will remain free for a long time, we cannot ensure that time is forever though.'
    );
    $label->set_wrap(1);

    $label->set_margin_top(20);
    $box->append($label);

    my $button =
      Gtk::Button->new("Study everything ordered by grade");
    $button->connect(
        clicked => sub {
            JapaChar::View::KanjiLesson->new( app => $self->app )->run;
        }
    );
    $button->set_margin_top(20);
    $button->add_css_class('accent');
    $button->set_halign($const->GTK_ALIGN_CENTER);
    $box->append($button);
    my @marks_to_study = ('Study All', qw/None Dakuten Handakuten/);
    my %translate = (
        'Study All'  => undef,
        'None'       => 'none',
        'Dakuten'    => 'dakuten',
        'Handakuten' => 'handakuten',
    );
    for my $mark (@marks_to_study) {
        my $button = Gtk::Button->new($mark);
        $button->connect(
            clicked => sub {
                JapaChar::View::HiraganaKatakanaLesson->new(
                    app  => $self->app,
                    type => $self->type,
                    mark => $translate{$mark},
                )->run;
            }
        );
        $button->set_halign($const->GTK_ALIGN_CENTER);
        $box->append($button);
    }
    $button->set_halign($const->GTK_ALIGN_CENTER);
    $scroll->set_child($box);
    $self->app->window_set_child($scroll);
    $self->app->headerbar->pack_start($back_button);
}
1;
