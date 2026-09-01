#/bin/sh
script=$0
preseed_config_file=$(dirname $script)/preseed.cfg

# NGFW-15749: trixie d-i 13's apt-install in chroot doesn't auto-bind /cdrom
# like bookworm d-i 12 did. Without this, `apt-install` below hangs at the
# "Please insert media labeled..." debconf dialog. Bind /cdrom from the d-i
# environment to all three paths apt may probe — bookworm-d-i used /media/cdrom,
# trixie-d-i 13 actually probes /media/cdrom0. /target/cdrom is also covered for
# any older apt-cdrom code path. Validated empirically: only /media/cdrom0 was
# the live miss on trixie. mkdir + bind both wrapped with || true so this stays
# safe on bookworm and netboot installs where /cdrom may not exist.
for d in /target/cdrom /target/media/cdrom /target/media/cdrom0 ; do
    mkdir -p "$d" 2>/dev/null || true
    mount --bind /cdrom "$d" 2>/dev/null || true
done

apt-install untangle-archive-keyring
apt-install untangle-linux-config
# sh -c "grep -q BOOTIF /proc/cmdline || sed -i -re 's/^root:[^:]+:/root:CHANGEME:/' /target/etc/shadow"
# FIXME: CHANGEME is not a valid hash and locks the account; disabled until untangle-linux-config handles this
#chroot /target sh -c "grep -q BOOTIF /proc/cmdline || sed -i -re 's/^root:[^:]+:/root:CHANGEME:/' /etc/shadow" 

# Local client installation
install_client_local=1
preseed_config_value=detect
if [ -f $preseed_config_file ] ; then
    preseed_config_keyword=local_client
    # Pull value
    preseed_config_value=$(grep $preseed_config_keyword $preseed_config_file | cut -d= -f2)
fi

if [ "$preseed_config_value" = "yes" ] ; then
    install_client_local=1
elif [ "$preseed_config_value" = "no" ] ; then
    install_client_local=0
else
    # Otherwise test for local graphics console support
    if [ "$TERM_TYPE" = "serial" ]  ; then
        # Configuring via a serial port - disable
        install_client_local=0
    fi

    if [ ! -d /sys/class/graphics ] ; then
        # No graphics interface found - disable
        install_client_local=0
    fi
fi

if [ $install_client_local -eq 1 ] ; then
    apt-install untangle-client-local
fi

# Comment out cdrom references in sources.list.
chroot /target perl -i -pe 's/(.*[dD]ebian)/# Commented by Untangle: $1/ unless m/^#/' /etc/apt/sources.list 
# Remove persistent rules for network interfaces.
chroot /target rm -f /etc/udev/rules.d/70-persistent-net.rules

# If oem script exists, run it.
chroot /target /bin/bash -c "[ ! -f /usr/share/untangle/bin/oem-apply.sh ] || /usr/share/untangle/bin/oem-apply.sh"

if [ "$TERM_TYPE" = "serial" ]  ; then
    apt-install untangle-serial-config
    # Installed via serial port; ensure can boot via console.
    console_argument=$(cat /proc/cmdline | sed -r 's/[[:alnum:]]+=/\n&/g' | grep console= | cut -d' ' -f1)
    if [ "$console_argument" != "" ] ; then
        echo 'GRUB_CMDLINE_LINUX="${GRUB_CMDLINE_LINUX} '$console_argument'"' > /target/etc/default/grub.d/serial.cfg
        chroot /target update-grub
    fi
fi
