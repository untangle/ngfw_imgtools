
@echo off
rem
rem Setup NGFW installer for non-standard configuration
rem 
set root_path=..\..

if not exist sed.exe (
    rem
    rem The script needs to be run from directory.
    rem
    echo sed.exe not found
    echo Make sure setup.bat is run from util\windows directory
    exit /b 0    
)

set isolinux_cfg_file_name=%root_path%\isolinux\isolinux.cfg
set menu_cfg_file_name=%root_path%\isolinux\menu.cfg
set txt_cfg_file_name=%root_path%\isolinux\txt.cfg
set grub_cfg_file_name=%root_path%\boot\grub\grub.cfg

set preseed_cfg_file_name=%root_path%\simple-cdd\preseed.cfg
set localclient_keyword=local_client

set yes_list=y Y
set no_list=n N

goto main

rem
rem Enable serial mode
rem Configure settings for serial mode
rem
:enable_serial
    echo.

    set port_numbers=0 1 2 3
    :espn_loop
    set /p port_number="Serial port number (0-3): "
        for %%v in (%port_numbers%) do if %port_number%==%%v goto espn_loop_exit
    goto espn_loop
    :espn_loop_exit

    set port_speeds=9600 19200 38400 57600 115200
    :esps_loop
    set /p port_speed="Serial port speed (9600, 19200, 38400, 57600, 115200): "
        for %%v in (%port_speeds%) do if %port_speed%==%%v goto esps_loop_exit
    goto esps_loop
    :esps_loop_exit

    call :disable_serial

    rem
    rem isolinux.cfg
    rem
    sed -i "1s/^/serial "%port_number%" "%port_speed%"\nconsole 0\n/" %isolinux_cfg_file_name%

    rem
    rem menu.cfg
    rem
    sed -i "/include gtk.cfg/d" %menu_cfg_file_name%

    rem
    rem txt.cfg
    rem
    sed -i -e "s/\( debian-installer\)/ console=ttyS"%port_number%","%port_speed%"n8\1/" %txt_cfg_file_name%

    rem
    rem grub.cfg (EFI)
    rem
    rem Comment out everything up to (but not including) the text install which
    rem we expect to be the last entry in the file
    sed -i "/if/, /'Install'/ { /'Install'/b; s/^/#/ }" %grub_cfg_file_name%

    rem Add serial console to kernel
    sed -i -e "s/\( debian-installer\)/ console=ttyS"%port_number%","%port_speed%"n8\1/g" %grub_cfg_file_name%

    rem Prefix grub serial display
    sed -i "1s/^/serial --speed="%port_speed%" --unit="%port_number%" --word=8 --parity=no --stop=1\nterminal_input --append  serial\nterminal_output --append serial\n/" %grub_cfg_file_name%

rem }
    exit /b 0

rem
rem Disable serial mode
rem Remove serial mode settings.
rem 
:disable_serial
    echo.

    rem
    rem isolinux.cfg
    rem
    sed -i "/serial .*/d" %isolinux_cfg_file_name%
    sed -i "/console /d" %isolinux_cfg_file_name%

    rem
    rem menu.cfg
    rem
    sed -i "/txt.cfg/i include gtk.cfg" %menu_cfg_file_name%

    rem
    rem txt.cfg
    rem
    sed -i -e "s/console=[^ ]\+ //" %txt_cfg_file_name%

    rem
    rem grub.cfg (EFI)
    rem
    rem Remove comments.
    sed -i "/if/, /'Install'/ { /'Install'/b; s/^\(#\)// }" %grub_cfg_file_name%

    rem Remove serial console from kernel
    sed -i -e "s/console=[^ ]\+ //g" %grub_cfg_file_name%

    rem Remove grub serial support
    sed -i "/serial .*/d" %grub_cfg_file_name%
    sed -i "/terminal_input .*/d" %grub_cfg_file_name%
    sed -i "/terminal_output .*/d" %grub_cfg_file_name%

    exit /b 0

rem
rem Enable/disable serial port
rem 
:serial_install
    echo.

    :si_loop
    set /p serial_install="Enable serial install (Y/N): "
        if %serial_install%==y goto si_loop_exit
        if %serial_install%==Y goto si_loop_exit
        if %serial_install%==n goto si_loop_exit
        if %serial_install%==N goto si_loop_exit
    goto si_loop
    :si_loop_exit

    for %%v in (%yes_list%) do (
        if %serial_install%==%%v (
            call :enable_serial
            echo Installer is now ready for serial installation.
        )
    )
    for %%v in (%no_list%) do (
        if %serial_install%==%%v (
            call :disable_serial
            echo Installer is now ready for installation via keyboard, mouse, and monitor.
        )
    )

    exit /b 0

rem
rem Enable/disable/detect Local console configuration
rem
:local_console
    echo.

rem     while [ "$localconsole" == "" ];
rem     do
rem         read -p "Enable local console (Y/N/D) [D=detect]: " localconsole && [[ $localconsole == [yY] || $localconsole == [nN] || $localconsole == [dD] ]] || localconsole=
rem     done
rem     localconsole=$(echo $localconsole | tr '[:upper:]' '[:lower:]' )

    set default_list=d D
    :lcl_loop
    set /p localconsole="Enable local console (Y/N/D) [D=detect]: "
        for %%v in (%default_list%) do if %localconsole%==%%v goto lcl_loop_exit
        for %%v in (%yes_list%) do if %localconsole%==%%v goto lcl_loop_exit
        for %%v in (%no_list%) do if %localconsole%==%%v goto lcl_loop_exit
    goto lcl_loop
    :lcl_loop_exit

    echo %localconsole%

    rem Delete
    sed -i "/"%localclient_keyword%"=.*/d" %preseed_cfg_file_name%

    for %%v in (%yes_list%) do (
        if %localconsole%==%%v (
            echo %localclient_keyword%=yes >> %preseed_cfg_file_name%
            echo Installer will install local console
        )
    )

    for %%v in (%no_list%) do (
        if %localconsole%==%%v (
            echo %localclient_keyword%=no >> %preseed_cfg_file_name%
            echo Installer will not install local console
        )
    )

    for %%v in (%default_list%) do (
        if %localconsole%==%%v (
            echo Installer will detect for video and if found, install local console.  Otherwise local console will not be installed.
        )
    )

    exit /b 0

rem
rem Main
rem
:main
cls

echo Untangle NGFW Installer Setup
echo =============================

call :serial_install
call :local_console

echo.
echo Untangle NGFW installer is ready!
echo.
