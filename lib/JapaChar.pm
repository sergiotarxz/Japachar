package JapaChar;

use v5.38.2;

use strict;
use warnings;
use utf8;

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
use JapaChar::View::MainMenu;
use JapaChar::Fontconfig;
use Glib::IO;
use Data::Dumper;
use Mojo::Util qw/url_unescape/;
use JSON qw/from_json/;

require XSLoader;
XSLoader::load('JapaChar');

use constant PANGO_SCALE => 1024;

Glib::Object::Introspection->setup(
    basename => 'Gtk',
    version  => '4.0',
    package  => 'Gtk',
);

my $GIO_BASENAME = 'Gio';
my $GIO_VERSION  = '2.0';
my $GIO_PACKAGE  = 'Glib::IO';

Glib::Object::Introspection->setup(
	basename => $GIO_BASENAME,
	version  => $GIO_VERSION,
	package  => $GIO_PACKAGE,
);

Glib::Object::Introspection->setup(
    basename => 'Gdk',
    version  => '4.0',
    package  => 'Gtk::Gdk',
);

#Glib::Object::Introspection->setup(
#    basename => 'Gsk',
#    version  => '4.0',
#    package  => 'Gtk::Gsk',
#);

Glib::Object::Introspection->setup(
    basename => 'Adw',
    version  => '1',
    package  => 'Adw',
);

has headerbar         => ( is => 'rw', );
has _on_resize_lesson => ( is => 'rw', );

has _gresources_path    => ( is => 'lazy', );
has _window             => ( is => 'rw' );
has _on_resize_triggers => ( is => 'ro', default => sub { {}; } );
has accessibility       => ( is => 'lazy' );
has characters          => ( is => 'lazy' );
has kanji               => ( is => 'lazy' );
has words               => ( is => 'lazy' );
has started => (is => 'rw', default => sub { 0 });

sub _build_words($self) {
    return JapaChar::Words->new(app => $self);
}

sub _build_kanji($self) {
    return JapaChar::Kanji->new(app => $self);
}

sub _build_characters($self) {
    require JapaChar::Characters;
    return JapaChar::Characters->new;
}

sub _build_accessibility($self) {
    require JapaChar::Accessibility;
    return JapaChar::Accessibility->new( app => $self );
}

sub root($self) {
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
    my $launcher = Gtk::UriLauncher->new('https://japachar.sergiotarxz.me');
    $launcher->launch( $self->_window, undef, undef );
}

sub launch_xmpp($self) {
    my $launcher = Gtk::UriLauncher->new('https://xmpp.link/#japachar@conference.cyberdelia.com.ar%3Fjoin%3Fjoin');
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

sub on_resize( $self, $sub ) {
    $self->_on_resize_triggers->{$sub} = $sub;
}

sub delete_on_resize( $self, $sub ) {
    return if !defined $sub;
    delete $self->_on_resize_triggers->{$sub};
}

sub present_dialog( $self, $dialog ) {
    $dialog->present( $self->_window );
}

sub window_set_child( $self, $child ) {
    my $window    = $self->_window;
    my $box       = Gtk::Box->new( 'vertical', 0 );
    my $headerbar = Adw::HeaderBar->new;
    $window->set_title( 'Learn with Japachar' );
    $headerbar->set_title_widget( Gtk::Label->new('Japachar') );
    $box->append($headerbar);
    $box->append($child);
    $child->set_vexpand(1);
    $window->set_content($box);
    $self->headerbar($headerbar);
}

sub _application_start( $self, $app ) {
	return if $self->started;
	$self->started(1);
    my $main_window = Adw::ApplicationWindow->new($app);
    $self->_window($main_window);
    $main_window->set_default_size( 300, 800 );
    my $settings = Gtk::Settings::get_default();
    $settings->set_property('gtk-font-name', 'Noto Sans CJK JP 12');
    $main_window->set_property( width_request => 300);
    $main_window->signal_connect(
        notify => sub( $object, $param ) {
            if ( $param->{name} eq 'default-width' ) {
                for my $resize_key ( keys $self->_on_resize_triggers->%* ) {
                    $self->_on_resize_triggers->{$resize_key}->();
                }
            }
        }
    );
    my $display = $main_window->get_property('display');
    JapaChar::View::MainMenu->new( app => $self )->run;
    $main_window->present;
}

sub parse_params($self, $params) {
	my ($url) = @$params;
	return if !defined $url;
	$url =~ s{^japachar://}{};
	my $phrase = url_unescape(url_unescape($url));
	say $phrase;
	open my $fh, '-|', (qw/himotoki -j/, $phrase);
	binmode $fh, ':utf8';
	my $file = join '', <$fh>;
	print Data::Dumper::Dumper from_json($file);
}

sub start($self) {
    Glib::IO::resources_register(
        Glib::IO::Resource::load( $self->_gresources_path ) );
    JapaChar::Fontconfig->new->set_current;
    my $app =
      Adw::Application->new( 'me.sergiotarxz.JapaChar', [qw/default-flags handles_command_line/] );
    $app->signal_connect(
        'activate' => sub {
            $self->_application_start($app);
        }
    );
	$app->signal_connect(command_line => sub {
		say command => '';
		$self->_application_start($app);
		$self->parse_params($_[1]->get_arguments);
		return;
	});
    $app->run([@ARGV]);
}
1;
