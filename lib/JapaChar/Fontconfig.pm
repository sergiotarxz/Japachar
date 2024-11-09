package JapaChar::Fontconfig;

use v5.40.0;

use strict;
use warnings;

use Digest::SHA qw/sha256_hex/;
use Moo;
use Path::Tiny;

use Data::Dumper;

use Inline C => DATA => LIBS => '-lfontconfig -lfreetype';

sub _font_dir($self) {
    my $root = path(__FILE__)->parent->parent->parent;
    return $root->child('fonts');
}

sub set_current($self) {
    my $font_dir = $self->_font_dir;
    $self->_set_current_c( '' . $font_dir );
}
1;
__DATA__
__C__
#include <stdio.h>
#include <fontconfig/fontconfig.h>

void
_set_current_c(SV *self, char *font_dir) {
    FcConfig *config = FcConfigGetCurrent();
    FcConfigAppFontAddDir(config, font_dir);
    FcConfigBuildFonts(config);
    FcConfigSetCurrent(config);
}
