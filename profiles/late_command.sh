#/bin/sh

# Forcibly install our linux configurator
apt-install untangle-linux-config
# sh -c "grep -q BOOTIF /proc/cmdline || sed -i -re 's/^root:[^:]+:/root:CHANGEME:/' /target/etc/shadow"
chroot /target sh -c "grep -q BOOTIF /proc/cmdline || sed -i -re 's/^root:[^:]+:/root:CHANGEME:/' /etc/shadow" 

# Test for local graphics console support
# Default to enable.
install_client_local=1

if [ "$TERM_TYPE" = "serial" ]  ; then
    # Configuring via a serial port - disable
    install_client_local=0
fi

if [ ! -d /sys/class/graphics ] ; then
    # No graphics interface found - disable
    install_client_local=0
fi

if [ $install_client_local -eq 1 ] ; then
    apt-install untangle-client-local
fi 

# Comment out cdrom references in sources.list.
chroot /target perl -i -pe 's/(.*[dD]ebian)/# Commented by Untangle: $1/ unless m/^#/' /etc/apt/sources.list 
# Remove persistent rules for network interfaces.
chroot /target rm -f /etc/udev/rules.d/70-persistent-net.rules

