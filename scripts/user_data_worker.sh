###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# User data script for Slurm worker node to support Ubuntu

nfs_server=${storage_ips}
nfs_mount_dir="data"

sudo apt update -y

sudo apt install slurm-wlm=19.05.5-1 -y
sudo apt install slurm-wlm-doc=19.05.5-1 -y

# checking paths in these service files
cat /lib/systemd/system/slurmctld.service
cat /lib/systemd/system/slurmd.service

# check the status of munge
systemctl status munge

apt install nfs-common -y

#Update worker host name based on with nfs share or not
mkdir -p /mnt/$nfs_mount_dir
echo "${nfs_server}:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs rw,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
mount /mnt/$nfs_mount_dir
ln -s /mnt/$nfs_mount_dir /home/slurm/shared

#copy the public key to authorized key
cat /mnt/data/ssh/authorized_keys >> ~/.ssh/authorized_keys

# Allow login as Slurm
mkdir -p /home/slurm/.ssh
cat /root/.ssh/authorized_keys >> /home/slurm/.ssh/authorized_keys
chmod 600 /home/slurm/.ssh/authorized_keys
chmod 700 /home/slurm/.ssh
chown -R slurm:slurm /home/slurm/.ssh

# Due To Polkit Local Privilege Escalation Vulnerability
chmod 0755 /usr/bin/pkexec

# Allow ssh from masters
sed -i "s#^\(AuthorizedKeysFile.*\)#\1 /mnt/data/ssh/authorized_keys#g" /etc/ssh/sshd_config
systemctl restart sshd

# copy the munge key from nfs to worker
cp /mnt/data/munge.key /etc/munge/munge.key
# copy the hosts list from nfs to worker
cp /mnt/data/hosts /etc/hosts
#copy the configuration file from nfs to worker
cp /mnt/data/slurm.conf /etc/slurm-llnl/slurm.conf

# After transferring munge key from master to worker node
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
