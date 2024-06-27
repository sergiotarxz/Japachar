#!/usr/bin/env perl
use Module::Build;

my $home = $ENV{HOME};

my $build = Module::Build->new(
    module_name   => 'JapaChar',
    license       => 'AGPLv3',
    dist_author   => 'Sergio Iglesias <contact@owlcode.tech>',
    dist_abstract => 'Learn Japanese Characters.',
    requires      => {
        'DBI'                         => 0,
        'DBD::SQLite'                 => 0,
        'Cairo::GObject'              => 0,
        'Glib::IO'                    => 0,
        'Glib::Object::Introspection' => 0,
        'JSON'                        => 0,
        'Moo'                         => 0,
        'YAML::PP'                    => 0,
        'Path::Tiny'                  => 0,
        'DBIx::Class'                 => 0,
        'Pango'                       => 0,
        'Crypt::URandom'              => 0,
    },
    test_requires => {
        'Test::MockModule' => 0,
        'Test::Most'       => 0,
        'Test::MockObject' => 0,
    }
);
$build->create_build_script;
