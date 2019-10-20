#!/bin/bash

GDM_FILE="/usr/share/gdm/defaults.conf"
CUSTOM_GDM_FILE="/etc/gdm/custom.conf"
LXDM_FILE="/etc/lxdm/lxdm.conf"
LIGHTDM_FILE="/etc/lightdm/lightdm.conf"
SDDM_FILE="/etc/sddm.conf"
OEM_FILE="/etc/oemlive.sh"
OEM_FILE_NEW="/etc/oem/liveboot.sh"
LIVE_USER_GROUPS="audio bumblebee cdrom cdrw clamav console entropy games \
kvm lp lpadmin messagebus plugdev polkituser portage pulse pulse-access pulse-rt \
scanner usb users uucp vboxguest vboxusers video wheel"
LIVE_USER=${SABAYON_USER:-sabayonuser}
LIVE_PERSISTENT_HOME_LABEL="live:/home"

sabayon_setup_autologin() {
    # GDM - GNOME
    if [ -f "${GDM_FILE}" ]; then
        sed -i "s/^AutomaticLoginEnable=.*/AutomaticLoginEnable=true/" ${GDM_FILE}
        sed -i "s/^AutomaticLogin=.*/AutomaticLogin=${LIVE_USER}/" ${GDM_FILE}

        sed -i "s/^TimedLoginEnable=.*/TimedLoginEnable=true/" ${GDM_FILE}
        sed -i "s/^TimedLogin=.*/TimedLogin=${LIVE_USER}/" ${GDM_FILE}
        sed -i "s/^TimedLoginDelay=.*/TimedLoginDelay=0/" ${GDM_FILE}

        # It seems that restart of the getty@tty1.service (inside sabayon_setup_vt_autologin)
        # block gdm bootstrap
        sed -i "s/^Conflicts=getty@t.*//g" ${GDM_FILE}

    elif [ -f "${CUSTOM_GDM_FILE}" ]; then
        # FIXME: if this is called multiple times, it generates duplicated entries
        sed -i "s:\[daemon\]:\[daemon\]\nAutomaticLoginEnable=true\nAutomaticLogin=${LIVE_USER}\nTimedLoginEnable=true\nTimedLogin=${LIVE_USER}\nTimedLoginDelay=0:" \
            "${CUSTOM_GDM_FILE}"
        # change other entries there
        sed -i "s/^TimedLogin=.*/TimedLogin=${LIVE_USER}/" "${CUSTOM_GDM_FILE}"
        sed -i "s/^AutomaticLogin=.*/AutomaticLogin=${LIVE_USER}/" "${CUSTOM_GDM_FILE}"
        sed -i "s/^Conflicts=getty@t.*//g" ${CUSTOM_GDM_FILE}
    fi

    # LXDM
    if [ -f "$LXDM_FILE" ]; then
        sed -i "s/autologin=.*/autologin=${LIVE_USER}/" $LXDM_FILE
        sed -i "/^#.*autologin=/ s/^#//" $LXDM_FILE
    fi

    # SDDM
    if [ -f "$SDDM_FILE" ]; then
        sed -i "s/^User=.*/User=${LIVE_USER}/" $SDDM_FILE
        sed -i "s/^Session=.*/Session=default/" $SDDM_FILE

        # This fix shutdown issue with sddm
        #	systemctl stop getty@tty1
    fi

    # LightDM
    if [ -f "$LIGHTDM_FILE" ]; then
        sed -i "s/autologin-user=.*/autologin-user=${LIVE_USER}/" $LIGHTDM_FILE
        sed -i "/^#.*autologin-user=/ s/^#//" $LIGHTDM_FILE
    fi

    # Setup correct login session
    sabayon_is_normal_boot && sabayon_fixup_gnome_autologin_session
}

sabayon_disable_autologin() {
    # GDM - GNOME
    if [ -f "${GDM_FILE}" ]; then
        sed -i "/^AutomaticLoginEnable=.*/d" ${CUSTOM_GDM_FILE}
        sed -i "/^AutomaticLogin=.*/d" ${CUSTOM_GDM_FILE}
        sed -i "/^TimedLoginEnable=.*/d" ${CUSTOM_GDM_FILE}
        sed -i "/^TimedLogin=.*/d" ${CUSTOM_GDM_FILE}
        sed -i "/^TimedLoginDelay=.*/d" ${CUSTOM_GDM_FILE}
        sed -i "s/^AutomaticLoginEnable=.*/AutomaticLoginEnable=false/" ${GDM_FILE}
    fi

    # LXDM
    if [ -f "$LXDM_FILE" ]; then
        sed -i "s/^autologin=.*/autologin=/" $LXDM_FILE
    fi

    # LightDM
    if [ -f "$LIGHTDM_FILE" ]; then
        sed -i "s/^autologin-user=.*/#autologin-user=/" $LIGHTDM_FILE
    fi

    # SDDM
    if [ -f "$SDDM_FILE" ]; then
        sed -i "s/Relogin=.*/Relogin=false/" $SDDM_FILE
        sed -i "s/^Session=.*/Session=/" $SDDM_FILE
        sed -i "s/^User=.*/User=/" $SDDM_FILE
    fi

}

sabayon_setup_home_mount() {
    local target_label="${LIVE_PERSISTENT_HOME_LABEL}"
    local device=$(blkid -L "${target_label}")

    # check if there is a device available
    [ -z "${device}" ] && return 0

    mkdir -p /home || return 1
    mount "${device}" /home || return 1
}

sabayon_setup_live_user() {
    local live_user="${1}"
    local live_uid="${2}"
    if [ -z "${live_user}" ]; then
        live_user="${LIVE_USER}"
    fi
    if [ -n "${live_uid}" ]; then
        live_uid="-u ${live_uid}"
    fi
    id ${live_user} &> /dev/null
    if [ "${?}" != "0" ]; then
        local live_groups=""
        local avail_groups=$(cat /etc/group | cut -d":" -f 1 | xargs echo)
        for a_group in ${avail_groups}; do
            for p_group in ${LIVE_USER_GROUPS}; do
                if [ "${p_group}" = "${a_group}" ]; then
                    if [ -z "${live_groups}" ]; then
                        live_groups="${p_group}"
                    else
                        live_groups="${live_groups},${p_group}"
                    fi
                fi
            done
        done
        # then setup live user, that is missing
        useradd -d "/home/${live_user}" -g root -G ${live_groups} -c "Sabayon" \
            -m -N -p "" -s /bin/bash ${live_uid} "${live_user}"
        # setting sudoers file
        [ -e /etc/sudoers ] && grep -q -F ${live_user} /etc/sudoers || echo "${live_user} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        return 0
    fi
    return 1
}

sabayon_setup_vt_autologin() {
    if openrc_running; then
        . /sbin/livecd-functions.sh
        export CDBOOT=1
        livecd_fix_inittab
    elif systemd_running; then
        cp /lib/systemd/system/getty@.service \
            /etc/systemd/system/autologin@.service
        sed -i "/^ExecStart=/ s:/sbin/agetty:/sbin/agetty --autologin root:g" \
            /lib/systemd/system/getty@.service
        sed -i "/^ExecStart=/ s:--noclear::g" \
            /lib/systemd/system/getty@.service
        systemctl daemon-reload
        systemctl restart getty@tty1
    fi
}

sabayon_setup_oem_livecd() {
    if [ -x "${OEM_LIVE_NEW}" ]; then
        ${OEM_FILE_NEW} || return 1
    elif [ -x "${OEM_LIVE}" ]; then
        ${OEM_FILE} || return 1
    fi
    return 0
}

sabayon_is_live() {
    local cmdl=$(cat /proc/cmdline | grep cdroot)
    if [ -n "${cmdl}" ]; then
        return 0
    else
        return 1
    fi
}

sabayon_setup_desktop_session() {
    local usr="${1}"
    local sess="${2}"

    local dmrc_file="/home/${usr}/.dmrc"
    local skel_dmrc_file="/etc/skel/.dmrc"

    local dmrc_f_dir=
    for dmrc_f in "${dmrc_file}" "${skel_dmrc_file}"; do
        dmrc_f_dir=$(dirname "${dmrc_f}")
        [ -d "${dmrc_f_dir}" ] || continue

        echo "[Desktop]" > "${dmrc_f}"
        echo "Session=${sess}" >> "${dmrc_f}"
        chown "${usr}" "${dmrc_f}"
    done

    if [ -x "/usr/libexec/gdm-set-default-session" ]; then
        # oh my fucking glorious god, this
        # is AccountsService bullshit
        # cross fingers
        /usr/libexec/gdm-set-default-session "${sess}"
    fi
    if [ -x "/usr/libexec/gdm-set-session" ]; then
        # GDM 3.6 support
        /usr/libexec/gdm-set-session "${usr}" "${sess}"
    fi

    # LightDM support
    ln -sf "${sess}.desktop" /usr/share/xsessions/default.desktop
}

sabayon_setup_gui_installer() {
    # Configure Fluxbox
    local flux_dir="/home/${LIVE_USER}/.fluxbox"
    local flux_startup_file="${flux_dir}/startup"
    if [ ! -d "${flux_dir}" ]; then
        mkdir "${flux_dir}" && chown "${LIVE_USER}" "${flux_dir}"
    fi
    sed -i "/installer --fullscreen/ s/^# //" "${flux_startup_file}"

    sabayon_setup_desktop_session "${LIVE_USER}" "fluxbox"

}

# This function reads /etc/skel/.dmrc and properly
# set the Session= value inside AccountsService.
# Blame the idiots who broke de-facto standards
# and created this fugly thing called AccountsService
sabayon_fixup_gnome_autologin_session() {
    local cur_session=

    if [ -f "/etc/skel/.dmrc" ]; then
        cur_session=$(cat /etc/skel/.dmrc | grep ^Session | cut -d"=" -f 2)
    fi
    if [ -z "${cur_session}" ]; then
        return 0
    fi

    sabayon_setup_desktop_session "${LIVE_USER}" "${cur_session}"
}

sabayon_setup_text_installer() {
    if openrc_running; then
        # switch to verbose mode
        splash_manager -c set -t default -m v &> /dev/null
        reset
        chvt 1
        clear
    fi
    sabayon_setup_text_installer_motd
}

sabayon_setup_vbox() {
   if ! sabayon_is_vbox; then
       systemctl disable virtualbox-guest-additions
       systemctl stop virtualbox-guest-additions
       # KILL IT WITH FIRE BEFORE IT LAYS EGGS
       rm -rf /etc/xdg/autostart/vboxclient.desktop
   fi
}

sabayon_setup_text_installer_motd() {
    echo "Welcome to Sabayon Linux installation. Text installation unfortunately it's not available:" >> /etc/motd
    echo "to run the installation start installer-text.sh" >> /etc/motd
}

sabayon_is_text_install() {
    local _is_install=$(cat /proc/cmdline | grep installer-text)
    if [ -n "${_is_install}" ]; then
        return 0
    else
        return 1
    fi
}

sabayon_is_gui_install() {
    local _is_install=$(cat /proc/cmdline | grep installer-gui)
    if [ -n "${_is_install}" ]; then
        return 0
    else
        return 1
    fi
}

sabayon_is_live_install() {
    ( sabayon_is_text_install || sabayon_is_gui_install ) && return 0
    return 1
}

sabayon_is_mce() {
    local _is_mce=$(cat /proc/cmdline | grep sabayonmce)
    if [ -n "${_is_mce}" ]; then
        return 0
    else
        return 1
    fi
}

sabayon_is_vbox() {
    local _isvbox=$(dmidecode | grep -i VirtualBox)
    if [[ $? != 0 ]]; then
        return 0
    elif [ -n "${_isvbox}" ]; then
        return 0
    else
        return 1
    fi
}

sabayon_is_steambox() {
    local _is_steam=$(cat /proc/cmdline | grep steambox)
    if [ -n "${_is_steam}" ]; then
        return 0
    else
        return 1
    fi
}

sabayon_is_normal_boot() {
    if ! sabayon_is_mce && ! sabayon_is_live_install && ! sabayon_is_steambox; then
        return 0
    else
        return 1
    fi
}

systemd_running() {
    test -d /run/systemd/system
}

openrc_running() {
    test -e /run/openrc/softlevel
}
