###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# User data script for Slurm worker node to support Ubuntu

sleep 30

nfs_server=${storage_ips}
nfs_mount_dir="data"

## Update the OS tuneable and MTU value
# Get the primary network interface
net_int=$(basename /sys/class/net/en*)

# Update the OS network tuneable
cat << EOF >> /etc/sysctl.conf
kernel.randomize_va_space=2
net.ipv4.tcp_max_syn_backlog=65536
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_sack=1
net.core.netdev_max_backlog=250000
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.optmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_adv_win_scale=1
net.core.somaxconn=2048
net.ipv4.neigh.ens1.gc_stale_time=2000000
net.ipv4.neigh.ens1.base_reachable_time_ms=120000
net.ipv4.neigh.ens1.mcast_solicit=18
EOF

sed -i "s/ens1/${net_int}/g" /etc/sysctl.conf

sysctl -p

sudo apt-get update -y
sudo apt-get install hdf5-* -y
sudo apt-get install libhdf5-dev -y
sudo apt-get install numactl -y
sudo apt-get install slurm-wlm=21.08.5-2ubuntu1 -y
sudo apt-get install slurm-wlm-doc=21.08.5-2ubuntu1 -y
sudo apt-get install nfs-common -y
sudo apt-get install build-essential -y


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
  mkdir -p /home/slurm/shared
  ln -s /mnt/$nfs_mount_dir /home/slurm/shared
}

mountNFS $nfs_server $nfs_mount_dir 10 30 $logfile

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
copyFile /mnt/$nfs_mount_dir/munge.key /etc/munge/munge.key 10 30 $logfile
# copy the hosts list from nfs to worker
copyFile /mnt/$nfs_mount_dir/hosts /etc/hosts 10 30 $logfile
#copy the slurm configuration file from nfs to worker
copyFile /mnt/$nfs_mount_dir/slurm.conf /etc/slurm/slurm.conf 10 30 $logfile
#copy the account configuration file from nfs to worker
copyFile /mnt/$nfs_mount_dir/acct_gather.conf /etc/slurm/acct_gather.conf 10 30 $logfile

echo "SSH Configuration"
#copy the public key to authorized key
echo "StrictHostKeyChecking no" >> /root/.ssh/config
mkdir -p /home/ubuntu/.ssh
cp /mnt/$nfs_mount_dir/ssh/authorized_keys  /home/ubuntu/.ssh/authorized_keys
cp /mnt/$nfs_mount_dir/ssh/id_rsa /home/ubuntu/.ssh/id_rsa
sudo chmod 600 /home/ubuntu/.ssh/authorized_keys
sudo chmod 700 /home/ubuntu/.ssh
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh/

mkdir -p /root/.ssh
cat /mnt/$nfs_mount_dir/ssh/authorized_keys > /root/.ssh/authorized_keys
cp /mnt/$nfs_mount_dir/ssh/id_rsa /root/.ssh/id_rsa
chmod 600 /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chown -R root:root /root/.ssh

sleep 5

# Allow login as Slurm
mkdir -p /home/slurm/.ssh
cat /root/.ssh/authorized_keys >> /home/slurm/.ssh/authorized_keys
chmod 600 /home/slurm/.ssh/authorized_keys
chmod 700 /home/slurm/.ssh
chown -R slurm:slurm /home/slurm/.ssh

# After transferring munge key from management node to worker node
sudo chown munge:munge /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key

sudo systemctl enable munge
sudo systemctl enable slurmd

# restart munge on every node
sudo systemctl restart munge

sudo mkdir /var/spool/slurm
sudo chown slurm:slurm /var/spool/slurm
chmod 755 /var/spool/

sudo mkdir /var/run/slurm
sudo chown slurm:slurm /var/run/slurm

# worker node
sudo systemctl start slurmd

sleep 1m
# restart munge and daemons
systemctl restart munge
systemctl restart slurmd

# Install Scale Dependencies
install_scale_dependance(){
  sudo apt-get install ksh -y
  sudo apt-get install m4 -y
  sudo apt-get install make -y
  sudo apt-get install g++ -y
}

# Install Scale Packages
install_scale(){
  install_scale_dependance
  nfs_mount_dir=$1
  echo "Starting gpfs_debs installation"
  cd /mnt/$nfs_mount_dir/scale/gpfs_debs ; sudo dpkg -i *.deb
  echo "Starting zimon_debs installation"
  cd /mnt/$nfs_mount_dir/scale/zimon_debs/ubuntu/ubuntu22/ ; sudo dpkg -i *.deb
  echo "Fixing broken installs"
  sudo apt --fix-broken install -y
  cd /mnt/$nfs_mount_dir/scale/zimon_debs/ubuntu/ubuntu22/ ; sudo dpkg -i *.deb
  cd /mnt/$nfs_mount_dir/scale/gpfs_debs ; sudo dpkg -i *.deb
  echo "export PATH=$PATH:/usr/lpp/mmfs/bin/" >> /root/.bashrc
  echo "export PATH=$PATH:/usr/lpp/mmfs/bin/" >> /home/ubuntu/.bashrc
  sudo ufw disable
}

download_openmpi(){
  sudo apt install gfortran -y
  mkdir -p /opt/src/
  cd /opt/src/
  wget -O openmpi.tar.bz2 https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.4.tar.bz2
  tar -xvf openmpi.tar.bz2 
  rm -rf openmpi.tar.bz2
  for nam in openmpi*
  do
    newname="openmpi_src"
    mv $nam $newname
  done
}

# Install Scale packages and download openmpi
if ${spectrum_scale}; then
    if [ ${worker_node_type} = "baremetal" ] ;then
      install_scale $nfs_mount_dir
      download_openmpi
      echo "install completed" > /tmp/install_completed
    fi  
fi 

## Disable Automatic Updates on Ubuntu 22.04
echo 'APT::Periodic::Download-Upgradeable-Packages "0";' >> /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::AutocleanInterval "0";' >> /etc/apt/apt.conf.d/20auto-upgrades
sed -i 's/APT::Periodic::Update-Package-Lists "1";/APT::Periodic::Update-Package-Lists "0";/g' /etc/apt/apt.conf.d/20auto-upgrades
sed -i 's/APT::Periodic::Unattended-Upgrade "1";/APT::Periodic::Unattended-Upgrade "0";/g' /etc/apt/apt.conf.d/20auto-upgrades

## Disable automatic kernel updates on ubuntu 22.04
apt-get remove linux-image linux-image-generic -y

## Hold the Kernal Updates
kernal_version=$(uname -r)
apt-mark hold $kernal_version

# Update the MTU value to 9000 and restart the networkd service
# Note: This need to be done at the last. Else, user-init script will be fail.
sed -i '/'$net_int':/a\            mtu: 9000' /etc/netplan/50-cloud-init.yaml
systemctl daemon-reload && systemctl restart systemd-networkd
