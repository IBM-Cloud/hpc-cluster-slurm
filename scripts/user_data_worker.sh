###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# User data script for Slurm worker node to support Ubuntu

nfs_server=${storage_ips}
nfs_mount_dir="data"

sudo apt update -y

sudo apt install slurm-wlm=${slurm_version} -y
sudo apt install slurm-wlm-doc=${slurm_version} -y

# checking paths in these service files
cat /lib/systemd/system/slurmctld.service
cat /lib/systemd/system/slurmd.service

# check the status of munge
systemctl status munge

apt install nfs-common -y

#Update worker host name based on with nfs share or not
mountNFS (){
    #This function will check for NFS mount availability, if not available wait and retry, than mount the nfs. 
  nfs_server=$1 #NFS server IP
  nfs_mount_dir=$2 #NFS mount directory
  delay=$3 #time delay between retries in seconds
  retry=$4 #retry count
  logfile=$5 #logfile path
  retryCount=0
  showmount -e $nfs_server >> $logfile
  showmountexitcode=$?
  echo "showmount status code : $showmountexitcode and NFS wait count : $retryCount" >> $logfile
  while [[ $showmountexitcode -ne 0 ]] && [[ $retryCount -le $retry ]] 
  do
    sleep $delay
    showmount -e $nfs_server >> $logfile
    showmountexitcode=$?
    retryCount=$((retryCount + 1))
    echo "showmount status code : $showmountexitcode and NFS wait count : $retryCount" >> $logfile
  done
  mkdir -p /mnt/$nfs_mount_dir
  echo "${nfs_server}:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
  mount /mnt/$nfs_mount_dir >> $logfile
  ln -s /mnt/$nfs_mount_dir /home/slurm/shared
}

mountNFS $nfs_server $nfs_mount_dir 10 30 $logfile

#copy the public key to authorized key
cat /mnt/data/ssh/authorized_keys >> ~/.ssh/authorized_keys

# Allow login as Slurm
mkdir -p /home/slurm/.ssh
cat /root/.ssh/authorized_keys >> /home/slurm/.ssh/authorized_keys
chmod 600 /home/slurm/.ssh/authorized_keys
chmod 700 /home/slurm/.ssh
chown -R slurm:slurm /home/slurm/.ssh

# Allow ssh from management node
sed -i "s#^\(AuthorizedKeysFile.*\)#\1 /mnt/data/ssh/authorized_keys#g" /etc/ssh/sshd_config
systemctl restart sshd

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
# copy the munge key from nfs to worker
copyFile /mnt/data/munge.key /etc/munge/munge.key 10 30 $logfile
# copy the hosts list from nfs to worker
copyFile /mnt/data/hosts /etc/hosts 10 30 $logfile
#copy the configuration file from nfs to worker
copyFile /mnt/data/slurm.conf /etc/slurm-llnl/slurm.conf 10 30 $logfile

# After transferring munge key from management node to worker node
# cd /etc/munge/
sudo chown munge:munge /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key

#Add hyperthreding condition
#if ! $hyperthreading; then
#for vcpu in `cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq`; do
#    echo 0 > /sys/devices/system/cpu/cpu$vcpu/online
#done
#fi


# restart munge on every node
sudo systemctl enable munge
sudo systemctl restart munge

sudo mkdir /var/spool/slurm-llnl
sudo chown slurm:slurm /var/spool/slurm-llnl
chmod 755 /var/spool/

sudo mkdir /var/run/slurm-llnl
sudo chown slurm:slurm /var/run/slurm-llnl

# worker node
sudo systemctl enable slurmd
sudo systemctl start slurmd
sudo systemctl status slurmd

# restart munge and deamons 
systemctl restart munge
systemctl restart slurmd
