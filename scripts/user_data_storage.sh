###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile=/tmp/user_data.log
SHARED_TOP=/data

env

# Update hostname based on internal IP address
hostname=${cluster_prefix}-storage
hostnamectl set-hostname ${hostname}

# Install and Configure NFS mount
yum install -y nfs-utils
found=0
while [ $found -eq 0 ]; do
    for vdx in $(lsblk -d -n --output NAME); do
        desc=$(file -s /dev/$vdx | grep ': data$' | cut -d : -f1)
        if [ "$desc" != "" ]; then
            mkfs -t xfs $desc
            uuid=$(blkid -s UUID -o value $desc)
            echo "UUID=$uuid $SHARED_TOP xfs defaults,noatime 0 0" >> /etc/fstab
            mkdir -p $SHARED_TOP
            mount $SHARED_TOP
            mkdir -p $SHARED_TOP/ssh
            touch $SHARED_TOP/ssh/authorized_keys
            chmod 700 $SHARED_TOP/ssh
            chmod 600 $SHARED_TOP/ssh/authorized_keys
            mkdir -p $SHARED_TOP/scale_install_done
            found=1
            break
        fi
    done
    sleep 1s
done

echo "$SHARED_TOP ${rc_cidr_block}(rw,no_root_squash)" > /etc/exports.d/export-nfs.exports
exportfs -ar

# Restart and enable NFS service
systemctl start nfs-server
systemctl enable nfs-server

# Function to check for file existence and copy it
copyFile() {
  fileSource=$1  # source file path
  fileDestination=$2  # destination file path
  delay=$3  # time delay between retries in seconds
  retry=$4  # retry count
  logfile=$5  # logfile path
  retryCount=0
  echo "$fileSource file copy wait count : $retryCount" >> $logfile
  while [[ ! -f $fileSource ]] && [[ $retryCount -le $retry ]]; do
    sleep $delay
    retryCount=$((retryCount + 1))
    echo "$fileSource file copy wait count : $retryCount" >> $logfile
  done
  if cp $fileSource $fileDestination >> $logfile 2>&1; then
    echo "$fileDestination copied" >> $logfile
  else
    echo "$fileDestination copy failed" >> $logfile
  fi
}

# Copy the SSH key from NFS to storage
copyFile $SHARED_TOP/ssh/id_rsa /root/.ssh/id_rsa 10 30 $logfile

# Copy the hosts list from NFS to storage
copyFile $SHARED_TOP/hosts /etc/hosts 10 30 $logfile

sleep 20
cat $SHARED_TOP/ssh/authorized_keys >> /root/.ssh/authorized_keys

echo "END $(date '+%Y-%m-%d %H:%M:%S')"