package JapaChar::Fontconfig;

use v5.38.2;

use strict;
use warnings;

use Digest::SHA qw/sha256_hex/;
use Moo;
use Path::Tiny;

use Data::Dumper;

sub _font_dir($self) {
    require JapaChar;
    my $root = JapaChar->root;
    return $root->child('fonts');
}

sub set_current($self) {
    my $font_dir = $self->_font_dir;
    $self->_set_current_c( '' . $font_dir );
}
1;

