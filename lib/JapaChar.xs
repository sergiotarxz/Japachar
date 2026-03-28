#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <fontconfig/fontconfig.h>
#ifdef __MINGW32__
#       include <wingdi.h>
#endif
#include <gperl.h>
#include <gio/gio.h>

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

void
japachar_arguments_get_params(SV *self, SV *arguments) {
	GObject *object = gperl_get_object(arguments); 
	int argc = 0;
	gchar **args = g_application_command_line_get_arguments(G_APPLICATION_COMMAND_LINE (object), &argc);
	printf("hola\n");
	for (int i = 0; i < argc; i++) {
		printf("%s\n", args[i]);
	}
}

MODULE = JapaChar PACKAGE = JapaChar::Fontconfig PREFIX = japachar_fontconfig_

void japachar_fontconfig__set_current_c(SV *self, char *font_dir)

MODULE = JapaChar PACKAGE = JapaChar::Arguments PREFIX = japachar_arguments_

void japachar_arguments_get_params(SV *self, SV *arguments)
