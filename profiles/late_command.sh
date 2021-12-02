#/bin/sh
script=$0
preseed_config_file=$(dirname $script)/preseed.cfg

# Forcibly install our linux configurator
apt-install untangle-linux-config
# sh -c "grep -q BOOTIF /proc/cmdline || sed -i -re 's/^root:[^:]+:/root:CHANGEME:/' /target/etc/shadow"
chroot /target sh -c "grep -q BOOTIF /proc/cmdline || sed -i -re 's/^root:[^:]+:/root:CHANGEME:/' /etc/shadow" 

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
    # Installed via serial port; ensure can boot via console.
    console_argument=$(cat /proc/cmdline | sed -r 's/[[:alnum:]]+=/\n&/g' | grep console= | cut -d' ' -f1)
    if [ "$console_argument" != "" ] ; then
        echo 'GRUB_CMDLINE_LINUX="${GRUB_CMDLINE_LINUX} '$console_argument'"' > /target/etc/default/grub.d/serial.cfg
        chroot /target update-grub
    fi
fi
