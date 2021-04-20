#!/bin/bash
script=$0;
root_path=$(dirname $script | sed -n -e 's#^\(/[^/]*\).*#\1#p')

isolinux_cfg_file_name=$root_path/isolinux/isolinux.cfg
menu_cfg_file_name=$root_path/isolinux/menu.cfg
txt_cfg_file_name=$root_path/isolinux/txt.cfg

##
## Enable serial mode
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

    echo
    echo "Installer is now ready for serial installation."

}

##
## Disable serial mode
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

    echo
    echo "Installer is now ready for local console installation."
}

##
## Main
##
clear

echo "Untangle NGFW Installer"
echo

enable_serial=
while [ "$enable_serial" == "" ]; 
do
    read -p "Enable serial install (Y/N): " enable_serial && [[ $enable_serial == [yY] || $enable_serial == [nN] ]] || enable_serial=
done
enable_serial=$(echo $enable_serial | tr '[:upper:]' '[:lower:]' )

if [ "$enable_serial" = "y" ] ; then
    enable_serial
elif [ "$enable_serial" = "n" ] ; then
    disable_serial
fi
