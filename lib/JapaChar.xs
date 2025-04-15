#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <fontconfig/fontconfig.h>
#ifdef __MINGW32__
#       include <wingdi.h>
#endif

void
japachar_fontconfig__set_current_c(SV *self, char *font_dir) {
#ifdef __MINGW32__
    AddFontResourceExA("japachar\\fonts\\NotoSansCJK-Regular.ttc", FR_PRIVATE, 0);
    AddFontResourceExA("japachar\\fonts\\NotoSansCJK-Bold.ttc", FR_PRIVATE, 0);
#else
    FcConfig *config = FcConfigCreate();
    FcConfigAppFontAddDir(config, font_dir);
    FcConfigBuildFonts(config);
    FcConfigSetCurrent(config);
#endif
}

MODULE = JapaChar PACKAGE = JapaChar::Fontconfig PREFIX = japachar_fontconfig_

void japachar_fontconfig__set_current_c(SV *self, char *font_dir)
