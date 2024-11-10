#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <fontconfig/fontconfig.h>

void
japachar_fontconfig__set_current_c(SV *self, char *font_dir) {
    FcConfig *config = FcConfigGetCurrent();
    FcConfigAppFontAddDir(config, font_dir);
    FcConfigBuildFonts(config);
    FcConfigSetCurrent(config);
}

MODULE = JapaChar PACKAGE = JapaChar::Fontconfig PREFIX = japachar_fontconfig_

void japachar_fontconfig__set_current_c(SV *self, char *font_dir)
