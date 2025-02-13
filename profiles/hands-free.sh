#/bin/sh
script=$0;
preseed_config_file=$(dirname $script)/preseed.cfg
preseed_config_keyword=hands_free

if [ -f $preseed_config_file ] ; then
    # If yes|no found in preseed config, exit.
    preseed_config_value=$(grep $preseed_config_keyword $preseed_config_file | cut -d= -f2)
    if [ "$preseed_config_value" = "yes" ] ; then
        echo 1
        exit
    elif [ "$preseed_config_value" = "no" ] ; then
        echo 0
        exit
    fi
fi

# Detect based on partition
allow_hands_free=0

total_parts=0
has_ngfw_root=0
vfat_parts=0
swap_parts=0

## Ignore all partitions from the installer media.
rootname=$(dirname $script | sed -n -e 's#^\(/[^/]*\).*#\1#p')
installer_dev=$(mount | grep $rootname | cut -d' ' -f1| head -1)
echo $installer_dev >> /tmp/dbg.txt
if [ "$installer_dev" = "" ] ; then
    installer_dev=ignoreme
fi

blk_devices=$(blkid | grep -v "^$installer_dev:" | sed -n -e 's/\([^:]*\):.* TYPE="\([^"]*\)".*/\1 \2/p')
while read line; do
   part=${line%% *}
   type=${line##* }
   if [ "$part" = "" ]; then
       continue
   fi
   total_parts=`expr $total_parts + 1`
   if [ "$type" = "ext4" ] ; then
      blkid | grep $part: | grep -q 'LABEL="NGFW_ROOT"'
      if [  $? -eq 0 ]; then
        # ext4 partition has our label.
        has_ngfw_root=1
      fi
   fi
   if [ "$type" = "vfat" ] ; then
        # Possibly our EFI partition.
        vfat_parts=`expr $vfat_parts + 1`
   fi
   if [ "$type" = "swap" ] ; then
        ## Possibly our swap partition
        swap_parts=`expr $swap_parts + 1`
   fi
done << EOT
$(echo -e "$blk_devices")
EOT

if [ $total_parts -eq 0 ] ; then
    # Only see one partition which is us - enable hands free.
    allow_hands_free=1
fi

if [ $has_ngfw_root -eq 1 \
    -a $swap_parts -eq 1 \
    -a $total_parts -eq 2 ] ; then
    # Found ngfw root, swap, and installer partitions - enable hands free
    allow_hands_free=1
fi

if [ $has_ngfw_root -eq 1 \
    -a $swap_parts -eq 1 \
    -a $vfat_parts -eq 1 \
    -a $total_parts -eq 3 ] ; then
    # Found ngfw root, efi (vfat), swap, and installer partitions - enable hands free
    allow_hands_free=1
fi

echo $allow_hands_free
