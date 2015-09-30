#!/bin/bash

. /sbin/sabayon-functions.sh

if sabayon_is_text_install; then
	sabayon_setup_text_installer
	/usr/bin/xinit /usr/bin/calamares-pkexec -- -nolisten tcp -br +bs -dpi 96 vt$XDG_VTNR
fi
