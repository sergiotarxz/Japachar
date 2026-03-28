#!/usr/bin/env perl
use Module::Build;
use ExtUtils::Depends;
use Data::Dumper;

my $home = $ENV{HOME};
my $depends = ExtUtils::Depends->new(JapaChar => 'Glib');
my %deps  = $depends->get_deps;
print Data::Dumper::Dumper \%deps;
print Data::Dumper::Dumper [ split(/\s/, (`pkg-config --cflags gio-2.0 glib-2.0`)), map { join ' ', $_->{inc} } values %deps];

my $build = Module::Build->new(
    module_name   => 'JapaChar',
    license       => 'AGPLv3',
    dist_author   => 'Sergio Iglesias <contact@owlcode.tech>',
    dist_abstract => 'Learn Japanese Characters.',
    requires      => {
        'DBI'                         => 0,
        'DBD::SQLite'                 => 0,
        'Cairo::GObject'              => 0,
        'Glib'                        => 0,
        'Glib::IO'                    => 0,
        'Glib::Object::Introspection' => 0,
        'JSON'                        => 0,
        'Moo'                         => 0,
        'YAML::PP'                    => 0,
        'Path::Tiny'                  => 0,
        'DBIx::Class'                 => 0,
        'Pango'                       => 0,
        'Crypt::URandom'              => 0,
        'Mojolicious'                 => 0,
    },
    extra_linker_flags => [ '-lfontconfig', '-lfreetype' ],
	extra_compiler_flags => [ split(/\s/, (`pkg-config --cflags gio-2.0 glib-2.0`)), map { split /\s+/, $_->{inc} } values %deps],
    test_requires      => {
        'Test::MockModule' => 0,
        'Test::Most'       => 0,
        'Test::MockObject' => 0,
    }
);
$build->create_build_script;
