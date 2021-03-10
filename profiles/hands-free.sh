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

mount_test=/tmp/mnt_test
total_parts=0
is_ngfw=0

blk_devices=$(blkid | sed -n -e 's/\([^:]*\):.* TYPE="\([^"]*\)".*/\1 \2/p')
mkdir -p $mount_test
while read line; do
   part=${line%% *}
   type=${line##* }
   total_parts=`expr $total_parts + 1`
   if [ "$type" = "ext4" ] ; then
        # Mount partition and determine if ngfw.
        mount -t $type $part $mount_test
        if [ -d $mount_test"/etc/untangle" ]; then
                is_ngfw=1
        fi
        umount $mount_test
   fi
done << EOT
$(echo -e "$blk_devices")
EOT

if [ $total_parts -eq 1 ] ; then
    # Only see one partition which is us - enable hands free.
    allow_hands_free=1
fi

if [ $is_ngfw -eq 1 ] ; then
    # This is currently a NGFW system - enable hands free.
    allow_hands_free=1
fi

echo $allow_hands_free
