###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

SHARED_TOP=/data

env

#Update management node host name based on internal IP address
# privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
# hostName=ibm-gen2host-${privateIP//./-}
hostname=${cluster_prefix}-storage
hostnamectl set-hostname ${hostName}

# NOTE: On ibm gen2, the default DNS server do not have reverse hostname/IP resolution.
# 1) put the management node hostname and ip into lsf hosts.
# 2) put all possible VMs' hostname and ip into lsf hosts.
python -c "import ipaddress; print('\n'.join([str(ip) + ' ibm-gen2host-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network(bytearray('${rc_cidr_block}'))]))" >> /etc/hosts

yum install -y nfs-utils
found=0
while [ $found -eq 0 ]; do
    for vdx in `lsblk -d -n --output NAME`; do
        desc=$(file -s /dev/$vdx | grep ': data$' | cut -d : -f1)
        if [ "$desc" != "" ]; then
            mkfs -t xfs $desc
            uuid=`blkid -s UUID -o value $desc`
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

echo "$SHARED_TOP      ${rc_cidr_block}(rw,no_root_squash)" > /etc/exports.d/export-nfs.exports
exportfs -ar

#Adjust the number of threads for the NFS daemon
#NOTE: This would only work for RH7/CentOS7.
#      On RH8, need to adjust /etc/nfs.conf instead
ncpus=$( nproc )
#default is 8 threads
nthreads=8

if [ "$ncpus" -gt "$nthreads" ]; then
  echo "Adjust the thread number for NFS from $nthreads to $ncpus"
  sed -i "s/^# *RPCNFSDCOUNT.*/RPCNFSDCOUNT=$ncpus/g" /etc/sysconfig/nfs
fi

systemctl start nfs-server
systemctl enable nfs-server

echo END `date '+%Y-%m-%d %H:%M:%S'`


copyFile (){
    #This function will check for file existence, if not present, wait and recheck for file presence than copies.
  fileSource=$1  #source file path
  fileDestination=$2  #distination file path
  delay=$3  #time delay between retries in seconds
  retry=$4  #retry count
  logfile=$5  #logfile path
  retryCount=0
  echo "$fileSource file copy wait count : $retryCount" >> $logfile
  while [[ ! -f $fileSource ]] && [[ $retryCount -le $retry ]]
  do
    sleep $delay
    retryCount=$((retryCount + 1))
    echo "$fileSource file copy wait count : $retryCount" >> $logfile
  done
  if cp $fileSource $fileDestination >> $logfile; then
    echo "$fileDestination copied" >> $logfile
  else
    echo "$fileDestination copy failed" >> $logfile
  fi
}
# copy the ssh key from nfs to storage
copyFile $SHARED_TOP/ssh/id_rsa /root/.ssh/id_rsa 10 30 $logfile
# copy the hosts list from nfs to storage
copyFile $SHARED_TOP/hosts /etc/hosts 10 30 $logfile
sleep 20
cat $SHARED_TOP/ssh/authorized_keys >> /root/.ssh/authorized_keys
