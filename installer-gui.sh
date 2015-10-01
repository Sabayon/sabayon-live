#!/bin/bash

. /sbin/sabayon-functions.sh

if sabayon_is_gui_install; then
	#sabayon_setup_autologin
	/usr/bin/xinit /usr/bin/calamares-pkexec -- -nolisten tcp -br +bs -dpi 96 vt$XDG_VTNR
	#sabayon_setup_gui_installer
fi
