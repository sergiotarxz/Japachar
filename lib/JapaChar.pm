package JapaChar;

use v5.38.2;

use strict;
use warnings;
use utf8;

use feature 'signatures';

use Moo;
use Path::Tiny;
use YAML::PP;
use File::Basename qw/dirname basename/;
use JapaChar::DB;
use JapaChar::Characters;
use JapaChar::Random;
use JapaChar::Score;
use JapaChar::View::MainMenu;
use JapaChar::Fontconfig;
use Data::Dumper;
use Mojo::Util qw/url_unescape/;
use JSON       qw/from_json/;
use AlgaGTK;
use JapaChar::Score;

use constant PANGO_SCALE => 1024;

has headerbar => ( is => 'rw', );

has _gresources_path => ( is => 'lazy', );
has _window          => ( is => 'rw' );
has accessibility    => ( is => 'lazy' );
has characters       => ( is => 'lazy' );
has kanji            => ( is => 'lazy' );
has words            => ( is => 'lazy' );
has started          => ( is => 'rw', default => sub { 0 } );
has app              => ( is => 'rw' );
has split_view       => ( is => 'rw' );
has callbacks_menu   => ( is => 'rw' );
has destructive      => ( is => 'rw' );
has breakpoint       => ( is => 'rw' );

sub _build_words($self) {
    return JapaChar::Words->new( app => $self );
}

sub _build_kanji($self) {
    return JapaChar::Kanji->new( app => $self );
}

sub _build_characters($self) {
    require JapaChar::Characters;
    return JapaChar::Characters->new;
}

sub _build_accessibility($self) {
    require JapaChar::Accessibility;
    return JapaChar::Accessibility->new( app => $self );
}

sub is_android {
    return -d '/data' && -d '/system';
}

sub android_package($self) {
    return $self->config->{android_package};
}

sub root($self) {
    return path(__FILE__)->parent if $self->is_android;
    return path(__FILE__)->parent->parent->parent;
}

sub _build__gresources_path($self) {
    my $root       = $self->root;
    my $gresources = $root->child('resources.gresource');
    0 == system( 'which',                  'glib-compile-resources' )
      && system( 'glib-compile-resources', $root->child('resources.xml') );
    if ( !-e $gresources ) {
        {
            die 'No gresources';
        }
    }
    return $gresources;
}

sub launch_website($self) {
    my $launcher = Gtk::UriLauncher->new('https://japachar.algaos.com');
    $launcher->launch( $self->_window, undef, undef );
}

sub launch_xmpp($self) {
    my $launcher = Gtk::UriLauncher->new(
        'https://xmpp.link/#japachar@conference.cyberdelia.com.ar%3Fjoin%3Fjoin'
    );
    $launcher->launch( $self->_window, undef, undef );
}

sub launch_discord($self) {
    my $launcher = Gtk::UriLauncher->new('https://discord.gg/CXUqrwtzu2');
    $launcher->launch( $self->_window, undef, undef );
}

sub get_width($self) {
    return $self->_window->get_property('default-width');
}

sub config($class) {
    my $ypp = YAML::PP->new;
    $ypp->load_file( '' . $class->root->child('config.yml') );
}

sub present_dialog( $self, $dialog ) {
    $dialog->present( $self->_window );
}

sub request_sidebar($self) {
    my $split_view = $self->split_view;
    my $const      = AlgaGTK::Constants->new;

    # Nothing to protect: navigate immediately.
    if ( !$self->destructive ) {
        $split_view->set_show_content(0);
        return;
    }

    my $dialog = Adw::AlertDialog->new( 'Unsaved changes',
        'Are you sure you want to leave this page? Your changes may be lost.' );

    $dialog->add_response( 'cancel',  'Stay' );
    $dialog->add_response( 'discard', 'Discard changes' );

    $dialog->set_response_appearance( 'discard',
        $const->ADW_RESPONSE_DESTRUCTIVE,
    );

    $dialog->connect(
        'response' => sub {
            my ( $dialog, $response ) = @_;

            if ( $response eq 'discard' ) {
                $self->destructive(0);
                $split_view->set_show_content(0);
            }

        }
    );

    $dialog->present( $self->_window );
}

sub window_set_child(
    $self, $child,
    $destructive = undef,
    $title       = undef,
    $id          = undef
  )
{
    if ( !( defined $destructive ) || !( defined $title ) || !( defined $id ) )
    {
        warn 'Not all parameters sent to window_set_child';
    }
    my $window = $self->_window;
    my $const  = AlgaGTK::Constants->new;
    my $box    = Gtk::Box->new( $const->GTK_ORIENTATION_VERTICAL, 0 );
    my $header = Adw::HeaderBar->new;
    $header->set_property( 'show_back_button', !!0 );
    my $button = Gtk::Button->new_from_icon_name('go-previous-symbolic');

    $button->connect(
        'clicked' => sub {
            $self->request_sidebar;
        }
    );

    $header->pack_start($button);
    $button->set_property(visible => !!0);
    $self->breakpoint->add_setter( $button, 'visible', !!1 );
    $box->append($header);
    $box->append($child);
    $window->set_title('Learn with Japachar');
    $child->set_vexpand(1);
    $self->headerbar( Adw::HeaderBar->new );
    if ( defined $destructive ) {
        $self->destructive($destructive);
    }
    else {
        $self->destructive(1);
    }
    my $content =
      Adw::NavigationPage->new( $box, $title // 'Japachar', $id // 'japachar' );
    $self->split_view->set_content($content);
    $self->split_view->set_show_content(1);
}

sub _application_start( $self, $app ) {
    my $const = AlgaGTK::Constants->new;
    return if $self->started;
    $self->started(1);
    my $main_window = Adw::ApplicationWindow->new($app);
    $main_window->set_default_size( 320, 640 );
    my $split_view = Adw::NavigationSplitView->new;
    $self->split_view($split_view);
    my $sidebar = $self->build_sidebar;
    $split_view->set_sidebar($sidebar);
    $split_view->set_sidebar_width_fraction(0.25);
    $split_view->set_min_sidebar_width(320);
    my $break =
      Adw::Breakpoint->new_length( $const->ADW_BREAKPOINT_CONDITION_MAX_WIDTH,
        1000, $const->ADW_LENGTH_UNIT_PX );
    $self->breakpoint($break);
    $break->add_setter( $split_view, 'collapsed', !!1 );
    $self->_window($main_window);
    $self->build_content;

    #    $main_window->set_default_size( 300, 800 );
    my $settings = Gtk::Settings::get_default();
    $settings->set_property( 'gtk-font-name', 'Noto Sans CJK JP 12' );

    #    JapaChar::View::MainMenu->new( app => $self )->run;
    $main_window->present;
    $main_window->add_breakpoint($break);
    $main_window->set_content($split_view);
    $self->split_view->set_show_content(1);
    $main_window->present;
}

sub append_to_sidebar_list_box( $self, $list_box, $widget, $callback ) {
    $list_box->append($widget);
    push @{ $self->callbacks_menu }, $callback;
}

sub build_content($self) {
    $self->build_welcome;
}

sub build_welcome($self) {
    my $const = AlgaGTK::Constants->new;
    my $child = Gtk::Box->new( $const->GTK_ORIENTATION_VERTICAL, 10 );
    my $score_label= Gtk::Label->new("Total Score: @{[JapaChar::Score->new->get]}");
    $score_label->set_halign($const->GTK_ALIGN_START);
    $child->append($score_label);
    my @texts = (
        'Welcome to Japachar',
        '© Sergiotarxz & Algaos Project',
        'Special thanks to Lucidraws for the logo',
'The algorithm is gradual, you are expected to fail in the first exercises, only memorize the correct answer and keep trying',
'We have Android (Play Store & F-Droid) and Linux (Flathub) apps, check out other platforms we support in our website in the sidebar',
    );
    for my $text (@texts) {
        my $label = Gtk::Label->new($text);
        $label->set_wrap(1);
        $label->set_halign($const->GTK_ALIGN_START);
        $label->set_margin_start(10);
        $label->set_margin_end(10);
        $child->append($label);
    }
    $self->window_set_child( $child, 0, 'Japachar', 'japachar' );
}

sub build_sidebar($self) {
    my $child = Adw::ToolbarView->new;
    $child->add_top_bar( Adw::HeaderBar->new() );
    my $scrolled = Gtk::ScrolledWindow->new;
    my $list_box = Gtk::ListBox->new;
    my $const    = AlgaGTK::Constants->new;
    $self->callbacks_menu( [] );
    $self->append_to_sidebar_list_box(
        $list_box,
        Gtk::Label->new('Welcome'),
        sub {
            $self->build_welcome;
        }
    );
    $self->append_to_sidebar_list_box(
        $list_box,
        Gtk::Label->new('Hiragana'),
        sub {
            JapaChar::View::SelectHiraganaKatakanaLesson->new(
                app  => $self,
                type => 'hiragana'
            )->run;
        }
    );
    $self->append_to_sidebar_list_box(
        $list_box,
        Gtk::Label->new('Katakana'),
        sub {
            JapaChar::View::SelectHiraganaKatakanaLesson->new(
                app  => $self,
                type => 'katakana'
            )->run;
        }
    );
    $self->append_to_sidebar_list_box(
        $list_box,
        Gtk::Label->new('Kanji'),
        sub {
            if ( $self->config->{android_gratis} ) {
                return $self->paywall;
            }
            JapaChar::View::SelectKanjiLesson->new( app => $self, )->run;
        }
    );
    $self->append_to_sidebar_list_box(
        $list_box,
        Gtk::Label->new('Words'),
        sub {
            if ( $self->config->{android_gratis} ) {
                return $self->paywall;
            }
            JapaChar::View::SelectWordLesson->new( app => $self, )->run;
        }
    );
    $self->append_to_sidebar_list_box(
        $list_box,
        Gtk::Label->new('Join our Discord Community'),
        sub {
            $self->launch_discord;
        }
    );
    $self->append_to_sidebar_list_box(
        $list_box,
        Gtk::Label->new('Visit Website'),
        sub {
            $self->launch_website;
        }
    );
    $self->append_to_sidebar_list_box(
        $list_box,
        Gtk::Label->new('Backup save'),
        sub {
            my $db = JapaChar::DB->_db_path($self);
            my $save = dirname($db).'/save.japasave';
            system 'cp', $db, $save;
            if ($self->is_android) {
                Android->share_file($self->_window, $save, 'application/vnd.japa.save');
            } else {
                my $dialog = Gtk::FileDialog->new;
                $dialog->set_title('Save as');
                $dialog->set_initial_name(basename($save));
                $dialog->save($self->_window, sub($path) {
                    path($path)->spew_raw(path($save)->slurp_raw);
                });
            }
        }
    );
    my $label_open = Gtk::Label->new('Load a save
(The app will
close, your
progress will
be lost)');
    $label_open->set_wrap(1);
    $self->append_to_sidebar_list_box(
        $list_box,
        $label_open,
        sub {
            my $db = JapaChar::DB->_db_path($self);
            my $save = dirname($db).'/save.japasave';
            system 'cp', '-f', $db, $save;

            my $dialog = Gtk::FileDialog->new;
            $dialog->set_title('Save as');
            $dialog->set_initial_name(basename($save));
            $dialog->open($self->_window, sub($file) {

                my $contents = $file->load_contents;

                path($db)->spew_raw($contents);
                exit(0);
            });
        }
    );
    $list_box->connect(
        'row-activated' => sub( $list_box, $row ) {
            bless $row, 'Gtk::ListBoxRow';
            if ( $self->destructive ) {
                my $dialog = Adw::AlertDialog->new(
                    'Unsaved changes',
'Are you sure you want to leave this page? Your changes may be lost.'
                );

                $dialog->add_response( 'cancel',  'Stay' );
                $dialog->add_response( 'discard', 'Discard changes' );

                $dialog->set_response_appearance( 'discard',
                    $const->ADW_RESPONSE_DESTRUCTIVE,
                );

                $dialog->connect(
                    'response' => sub {
                        my ( $dialog, $response ) = @_;

                        if ( $response eq 'discard' ) {
                            $self->destructive(0);
                            $self->callbacks_menu->[ $row->get_index ]->();
                            $self->split_view->set_show_content(1);
                        }

                    }
                );
                $dialog->present( $self->_window );
                return;
            }
            $self->callbacks_menu->[ $row->get_index ]->();
            $self->split_view->set_show_content(1);
        }
    );
    $list_box->add_css_class("navigation-sidebar");
    $scrolled->set_child($list_box);
    $child->set_content($scrolled);
    my $return =
      Adw::NavigationPage->new( $child, 'Where do you want to go?', 'sidebar' );
    return $return;
}

sub parse_params( $self, $params ) {
    my ($url) = @$params;
    return if !defined $url;
    $url =~ s{^japachar://}{};
    my $phrase = url_unescape( url_unescape($url) );
    say $phrase;
    open my $fh, '-|', ( qw/himotoki -j/, $phrase );
    binmode $fh, ':utf8';
    my $file = join '', <$fh>;
    print Data::Dumper::Dumper from_json($file);
}

sub start($self) {
    if ($self->is_android) {
        my $tmpdir = '/data/data/me.sergiotarxz.japachar/cache';

        mkdir $tmpdir unless -d $tmpdir;

        $ENV{SQLITE_TMPDIR} = $tmpdir;
        $ENV{TMPDIR} = $tmpdir;
    }
    my $const = AlgaGTK::Constants->new;
    my $app   = Adw::Application->new( 'me.sergiotarxz.JapaChar',
        0 | $const->G_APPLICATION_CAN_OVERRIDE_APP_ID |
          $const->G_APPLICATION_ALLOW_REPLACEMENT );
    $self->app($app);
    JapaChar::Fontconfig->new( app => $self )->set_current;
    $app->connect(
        'activate' => sub {
            $self->_application_start($app);
        }
    );
    $app->load_resource( $self->_gresources_path );
    $app->run(@ARGV);
}

sub paywall($self) {
    my $dialog = Adw::AlertDialog->new( 'Feature available for paid users',
        'You can only study Hiragana and Katakana in the free version.

Developing this app takes effort, this feature is available only for paid users, Linux users and F-droid users' );
    $dialog->add_response( 'close', 'Continue' );
    $self->present_dialog($dialog);
}
1;
