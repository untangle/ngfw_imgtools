#!/bin/bash
script=$0;
root_path=../../

isolinux_cfg_file_name=$root_path/isolinux/isolinux.cfg
menu_cfg_file_name=$root_path/isolinux/menu.cfg
txt_cfg_file_name=$root_path/isolinux/txt.cfg
grub_cfg_file_name=$root_path/boot/grub/grub.cfg

preseed_cfg_file_name=$root_path/simple-cdd/preseed.cfg
localclient_keyword=local_client

##
## Enable serial mode
## Configure settings for serial mode
##
enable_serial(){
    echo

    port_number=
    while [ "$port_number" = "" ] ; 
    do
        read -p "Serial port number (0-3): " port_number && [[ $port_number == [[:digit:]] ]] || port_number=
    done

    port_speed=
    while [ "$port_speed" = "" ] ; 
    do
        read -p "Serial port speed (9600, 19200, 38400, 57600, 115200): " port_speed && [[ $port_speed == 9600 || $port_speed == 19200 || $port_speed == 38400 || $port_speed == 56700 || $port_speed == 115200 ]] || port_speed=
    done

    disable_serial

    ##
    ## isolinux.cfg
    ##
    sed -i '1s/^/serial '$port_number' '$port_speed'\nconsole 0\n/' $isolinux_cfg_file_name

    ##
    ## menu.cfg
    ##
    sed -i '/include gtk.cfg/d' $menu_cfg_file_name

    ##
    ## txt.cfg
    ##
    sed -i -e 's/\( debian-installer\)/ console=ttyS'$port_number','$port_speed'n8\1/' $txt_cfg_file_name

    ##
    ## grub.cfg (EFI)
    ##
    ## Comment out everything up to (but not including) the text install which
    ## we expect to be the last entry in the file
    sed -i '/if/, /'Install'/ { /'Install'/b; s/^/#/ }' $grub_cfg_file_name

    ## Add serial console to kernel
    sed -i -e 's/\( debian-installer\)/ console=ttyS'$port_number','$port_speed'n8\1/g' $grub_cfg_file_name

    ## Prefix grub serial display
    sed -i '1s/^/serial --speed='$port_speed' --unit='$port_number' --word=8 --parity=no --stop=1\nterminal_input --append  serial\nterminal_output --append serial\n/' $grub_cfg_file_name

}

##
## Disable serial mode
## Remove serial mode settings.
##
disable_serial(){
    ##
    ## isolinux.cfg
    ##
    sed -i '/serial .*/d' $isolinux_cfg_file_name
    sed -i '/console /d' $isolinux_cfg_file_name

    ##
    ## menu.cfg
    ##
    sed -i '/txt.cfg/i include gtk.cfg' $menu_cfg_file_name

    ##
    ## txt.cfg
    ##
    sed -i -e 's/console=[^ ]\+ //' $txt_cfg_file_name

    ##
    ## grub.cfg (EFI)
    ##
    ## Remove comments.
    sed -i '/if/, /'Install'/ { /'Install'/b; s/^\(#\)// }' $grub_cfg_file_name

    ## Remove serial console from kernel
    sed -i -e 's/console=[^ ]\+ //g' $grub_cfg_file_name

    ## Remove grub serial support
    sed -i '/serial .*/d' $grub_cfg_file_name
    sed -i '/terminal_input .*/d' $grub_cfg_file_name
    sed -i '/terminal_output .*/d' $grub_cfg_file_name
}

##
## Enable/disable serial port
##
serial_install(){
    echo

    enable_serial=
    while [ "$enable_serial" == "" ];
    do
        read -p "Enable serial install (Y/N): " enable_serial && [[ $enable_serial == [yY] || $enable_serial == [nN] ]] || enable_serial=
    done
    enable_serial=$(echo $enable_serial | tr '[:upper:]' '[:lower:]' )

    if [ "$enable_serial" = "y" ] ; then
        enable_serial
        echo
        echo "Installer is now ready for serial installation."
    elif [ "$enable_serial" = "n" ] ; then
        disable_serial
        echo
        echo "Installer is now ready for installation via keyboard, mouse, and monitor."
    fi
}

##
## Enable/disable/detect Local console configuration
##
local_console(){
    echo
    localconsole=
    while [ "$localconsole" == "" ];
    do
        read -p "Enable local console (Y/N/D) [D=detect]: " localconsole && [[ $localconsole == [yY] || $localconsole == [nN] || $localconsole == [dD] ]] || localconsole=
    done
    localconsole=$(echo $localconsole | tr '[:upper:]' '[:lower:]' )

    echo

    # Delete
    sed -i '/'$localclient_keyword'=.*/d' $preseed_cfg_file_name

    if [ "$localconsole" = "y" ] ; then
        echo "$localclient_keyword=yes" >> $preseed_cfg_file_name
        echo "Installer will install local console"
    elif [ "$localconsole" = "n" ] ; then
        echo "$localclient_keyword=no" >> $preseed_cfg_file_name
        echo "Installer will not install local console"
    elif [ "$localconsole" = "d" ] ; then
        echo "Installer will detect for video and if found, install local console.  Otherwise local console will not be installed."
    fi
    # If not specified, detect

}

##
## Main
##
clear

echo "Untangle NGFW Installer Setup"
echo "============================="

serial_install
local_console

echo
echo "Untangle NGFW installer is ready!"
echo
