package JapaChar;

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
use JapaChar::View::MainMenu;

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

has headerbar         => ( is => 'rw', );
has _on_resize_lesson => ( is => 'rw', );

has _gresources_path    => ( is => 'lazy', );
has _window             => ( is => 'rw' );
has _on_resize_triggers => ( is => 'ro', default => sub { {}; } );
has accessibility       => ( is => 'lazy' );
has characters => ( is => 'lazy' );

sub _build_characters($self) {
    require JapaChar::Characters;
    return JapaChar::Characters->new;
}

sub _build_accessibility($self) {
    require JapaChar::Accessibility;
    return JapaChar::Accessibility->new(app => $self);
}

sub _build__gresources_path($self) {
    my $root       = path(__FILE__)->parent->parent;
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

sub get_width($self) {
    return $self->_window->get_property('default-width');
}

sub config($class) {
    my $ypp = YAML::PP->new;
    $ypp->load_file( '' . path(__FILE__)->parent->parent->child('config.yml') );
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
    $headerbar->set_title_widget( Gtk::Label->new('Japachar') );
    $box->append($headerbar);
    $box->append($child);
    $child->set_vexpand(1);
    $window->set_content($box);
    $self->headerbar($headerbar);
}

sub _application_start( $self, $app ) {
    my $main_window = Adw::ApplicationWindow->new($app);
    $self->_window($main_window);
    $main_window->set_default_size( 1200, 600 );
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

sub start($self) {
    Glib::IO::resources_register(
        Glib::IO::Resource::load( $self->_gresources_path ) );
    my $app =
      Adw::Application->new( 'me.sergiotarxz.JapaChar', 'default-flags' );
    $app->signal_connect(
        'activate' => sub {
            $self->_application_start($app);
        }
    );
    $app->run;
}
1;
