###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# User data script for Slurm management node to support Ubuntu

nfs_server=${storage_ips}
nfs_mount_dir="data"
DB_ADMIN_USERNAME="root"
DB_USER_PASSWORD="secret"
DB_HOSTNAME="localhost"

sudo apt-get update -y
#installing hdf5
sudo apt-get install hdf5-* -y
sudo apt-get install libhdf5-dev -y
sudo apt install postgresql-client-common -y

privateIP=$(ip addr show ens3 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
ManagementHostName=${vmPrefix}-${privateIP//./-}

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

slurmAccounting (){

  mysql -u ${DB_ADMIN_USERNAME} -e "create user 'slurm'@'localhost' identified by '${DB_USER_PASSWORD}'; grant all on slurm_acct_db.* TO 'slurm'@'localhost'; create database slurm_acct_db;"

cat << EOS > /etc/slurm/slurmdbd.conf
LogFile=/var/log/slurm/slurmdbd.log
DbdHost=${DB_HOSTNAME}
DbdPort=6819
SlurmUser=slurm
StorageHost=localhost
StoragePass=${DB_USER_PASSWORD}
StorageLoc=slurm_acct_db
StorageType=accounting_storage/mysql

DebugLevel=info
PurgeEventAfter=1month
PurgeJobAfter=12month
PurgeResvAfter=1month
PurgeStepAfter=1month
PurgeSuspendAfter=1month
PurgeTXNAfter=12month
PurgeUsageAfter=24month
EOS

sudo chown slurm: /etc/slurm/slurmdbd.conf
sudo chmod 600 /etc/slurm/slurmdbd.conf
touch /var/log/slurm/slurmdbd.log
sudo chown slurm: /var/log/slurm/slurmdbd.log
}

#if ! $hyperthreading; then
#for vcpu in `cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq`; do
    #echo 0 > /sys/devices/system/cpu/cpu$vcpu/online
#done
#fi

#Update management node host name based on with nfs share or not
mountNFS (){
    #This function will check for NFS mount availability, if not available wait and retry, than mount the nfs.
  nfs_server=$1  #NFS server IP
  nfs_mount_dir=$2  #NFS mount directory
  delay=$3  #time delay between retries in seconds
  retry=$4  #retry count
  logfile=$5  #logfile path
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
  echo "$nfs_server:/$nfs_mount_dir /mnt/$nfs_mount_dir nfs defaults 0 0 " >> /etc/fstab
  mount /mnt/$nfs_mount_dir >> $logfile
}

if ([ -n "${nfs_server}" ] && [ -n "${nfs_mount_dir}" ]); then
  echo "NFS server and share found, start mount nfs share!" >> $logfile
  #Mount the nfs share
  mountNFS $nfs_server $nfs_mount_dir 10 30 $logfile
  df -h /mnt/$nfs_mount_dir >> $logfile
  echo "Mount nfs share done!" >> $logfile

  # Copy Scale files to Mount path
  copy_scale_package(){
    mkdir -p /mnt/$nfs_mount_dir/scale
    cp -avf /opt/src/scale/* /mnt/$nfs_mount_dir/scale/
    mkdir /mnt/$nfs_mount_dir/scale/package_to_install
    cp -avf /mnt/$nfs_mount_dir/scale/gpfs_debs/*.deb /mnt/$nfs_mount_dir/scale/package_to_install/
    cp -avf /mnt/$nfs_mount_dir/scale/zimon_debs/ubuntu/ubuntu22/*.deb /mnt/$nfs_mount_dir/scale/package_to_install/
  }
  # Generate and copy a public ssh key
  mkdir -p /mnt/$nfs_mount_dir/ssh 

  #Create the sshkey in the share directory and then copy the public and private key to respective root and lsfadmin .ssh folder
  ssh-keygen -q -t rsa -f /mnt/$nfs_mount_dir/ssh/id_rsa -C "slurm@$ManagementHostName" -N "" -q
  cat /mnt/$nfs_mount_dir/ssh/id_rsa.pub >> /root/.ssh/authorized_keys
  echo $vsi_login_temp_public_key >> /root/.ssh/authorized_keys
  cp /root/.ssh/authorized_keys /mnt/$nfs_mount_dir/ssh/authorized_keys
  cp /mnt/$nfs_mount_dir/ssh/id_rsa /root/.ssh/id_rsa
  cp /mnt/$nfs_mount_dir/ssh/authorized_keys  /home/ubuntu/.ssh/authorized_keys
  sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
  cp /mnt/$nfs_mount_dir/ssh/id_rsa /home/ubuntu/.ssh/id_rsa
  sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh/
  sudo chmod 600 /home/ubuntu/.ssh/authorized_keys
  sudo chmod 700 /home/ubuntu/.ssh

  echo "StrictHostKeyChecking no" >> /root/.ssh/config
  mkdir -p /home/slurm/.ssh
  cp /mnt/$nfs_mount_dir/ssh/id_rsa /home/slurm/.ssh/id_rsa
  cp /mnt/$nfs_mount_dir/ssh/authorized_keys /home/slurm/.ssh/authorized_keys
  chmod 600 /home/slurm/.ssh/authorized_keys
  chmod 700 /home/slurm/.ssh
  chown -R slurm:slurm /home/slurm/.ssh

  sudo mkdir -p /mnt/$nfs_mount_dir/slurm
  sudo chown slurm:slurm /mnt/$nfs_mount_dir/slurm

else
  echo "No NFS server and share found!" >> $logfile
fi

#every node (management & worker) needs to have the same munge key
# use dd to generate the munge key on management node
dd if=/dev/urandom of=/etc/munge/munge.key bs=1c count=1024

#cd /etc/munge/
sudo chown munge:munge /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key

#Add hyperthreding condition
if $hyperthreading; then
  ncpus=${hf_ncpus}
else
  ncpus=${hf_ncores}
fi

#Add hosts on every node
#edit /etc/hosts... include "<ip> <host-name>" and ensure /etc/hosts is the same on every node
cat > /etc/hosts << 'EOF'
127.0.0.1 localhost
# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

echo "${storage_ips} ${cluster_prefix}-storage" >> /etc/hosts

i=0
for management_ip in ${management_ips}; do
  if [ $i -gt 0 ]; then
      let j=$i-1
      echo "$management_ip ${cluster_prefix}-management-candidate" >> /etc/hosts
    else
      echo "$management_ip ${cluster_prefix}-management" >> /etc/hosts
    fi
    management_hostnames="${management_hostnames} $cluster_prefix-management"
    i=`expr $i + 1`
done

i=1
for worker_ip in ${worker_ips}; do
    printf "$worker_ip ${cluster_prefix}-worker-%03d\n" $i >> /etc/hosts
    worker_hostnames="${worker_hostnames} $cluster_prefix-worker-%03d\n" $i
    i=`expr $i + 1`
done

worker_count=`expr $i - 1`
worker_index=$(printf "%03d" $worker_count)
management_index=`expr $i - 1`

if $hyperthreading; then
  ThreadsPerCore=2
else
  ThreadsPerCore=1
fi


# Now set up slurm.conf
cat > /etc/slurm/slurm.conf << EOF
# Slurm Configuration file
# Should be the same across management node and all worker nodes

SlurmctldHost=${cluster_prefix}-management

ClusterName=${cluster_name}

#SlurmctldHost=
#
#DisableRootJobs=NO
#EnforcePartLimits=NO
#Epilog=
#EpilogSlurmctld=
#FirstJobId=1
#MaxJobId=999999
#GresTypes=
#GroupUpdateForce=0
#GroupUpdateTime=600
#JobFileAppend=0
#JobRequeue=1
#JobSubmitPlugins=1
#KillOnBadExit=0
#LaunchType=launch/slurm
#Licenses=foo*4,bar
#MailProg=/bin/mail
#MaxJobCount=5000
#MaxStepCount=40000
#MaxTasksPerNode=128
MpiDefault=none
#MpiParams=ports=#-#
#PluginDir=
#PlugStackConfig=
#PrivateData=jobs

##ProctrackType=proctrack/pgid
Proctracktype=proctrack/linuxproc

#Prolog=
#PrologFlags=
#PrologSlurmctld=
#PropagatePrioProcess=0
#PropagateResourceLimits=
#PropagateResourceLimitsExcept=
#RebootProgram=
ReturnToService=1
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmctldPort=6817
SlurmdPidFile=/var/run/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=/var/spool/slurm/ctld
SlurmUser=slurm
#SlurmdUser=root
#SrunEpilog=
#SrunProlog=
StateSaveLocation=/mnt/data/slurm
SwitchType=switch/none
#TaskEpilog=
TaskPlugin=task/affinity
#TaskProlog=
#TopologyPlugin=topology/tree
#TmpFS=/tmp
#TrackWCKey=no
#TreeWidth=
#UnkillableStepProgram=
#UsePAM=0
#
#
# TIMERS
#BatchStartTimeout=10
#CompleteWait=0
#EpilogMsgTime=2000
#GetEnvTimeout=2
#HealthCheckInterval=0
#HealthCheckProgram=
InactiveLimit=0
KillWait=30
#MessageTimeout=10
#ResvOverRun=0
MinJobAge=300
#OverTimeLimit=0
SlurmctldTimeout=120
SlurmdTimeout=300
#UnkillableStepTimeout=60
#VSizeFactor=0
Waittime=0
#
#
# SCHEDULING
#DefMemPerCPU=0
#MaxMemPerCPU=0
#SchedulerTimeSlice=30
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core
#
#
# JOB PRIORITY
#PriorityFlags=
#PriorityType=priority/basic
#PriorityDecayHalfLife=
#PriorityCalcPeriod=
#PriorityFavorSmall=
#PriorityMaxAge=
#PriorityUsageResetPeriod=
#PriorityWeightAge=
#PriorityWeightFairshare=
#PriorityWeightJobSize=
#PriorityWeightPartition=
#PriorityWeightQOS=
#
#
# LOGGING AND ACCOUNTING
#AccountingStorageEnforce=0
#AccountingStorageHost=
#AccountingStoragePass=
#AccountingStoragePort=


##AccountingStorageType=accounting_storage/filetxt
#AccountingStorageType=accounting_storage/none
##AccountingStorageLoc=/var/log/slurm/acct_completions


#AccountingStorageUser=


##AccountingStoreJobComment=YES
AccountingStoreFlags=job_comment

#DebugFlags=
#JobCompHost=
JobCompLoc=/var/log/slurm/job_completions
#JobCompPass=
#JobCompPort=
JobCompType=jobcomp/filetxt
#JobCompUser=
#JobContainerType=job_container/none
#JobAcctGatherFrequency=30


##JobAcctGatherType=jobacct_gather/none
#JobAcctGatherType=jobacct_gather/linux

# for Accounting
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=${DB_HOSTNAME}
JobAcctGatherType=jobacct_gather/linux
JobAcctGatherFrequency=30

SlurmctldDebug=debug
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurm/slurmd.log
SlurmSchedLogFile=/var/log/slurm/slurmsched.log


AcctGatherFilesystemType=acct_gather_filesystem/lustre
#AcctGatherInterconnectType=acct_gather_interconnect/ofed
AcctGatherEnergyType=acct_gather_energy/ipmi
AcctGatherProfileType=acct_gather_profile/hdf5

#SlurmSchedLogLevel=
#
#
# POWER SAVE SUPPORT FOR IDLE NODES (optional)
#SuspendProgram=
#ResumeProgram=
#SuspendTimeout=
#ResumeTimeout=
#ResumeRate=
#SuspendExcNodes=
#SuspendExcParts=
#SuspendRate=
#SuspendTime=
#
#
# WORKER NODES
NodeName=${cluster_prefix}-worker-[000-${worker_index}] CPUs=${ncpus} ThreadsPerCore=${ThreadsPerCore} RealMemory=`expr ${hf_memInMB} - 2048` State=UNKNOWN
PartitionName=debug Nodes=${cluster_prefix}-worker-[000-${worker_index}] Default=YES MaxTime=INFINITE State=UP
EOF

cat > /etc/slurm/acct_gather.conf << EOF
###
# Slurm acct_gather configuration file
###
# Parameters for acct_gather_energy/impi plugin
EnergyIPMIFrequency=10
EnergyIPMICalcAdjustment=yes
#
# Parameters for acct_gather_profile/hdf5 plugin
ProfileHDF5Dir=/mnt/data/slurm/profile_data
# Parameters for acct_gather_interconnect/ofed plugin
#InfinibandOFEDPort=1
EOF

sudo systemctl enable munge
sudo systemctl enable slurmctld

sudo systemctl start munge

sudo mkdir /var/spool/slurm
sudo chown slurm:slurm /var/spool/slurm

sudo mkdir /var/run/slurm
sudo chown slurm:slurm /var/run/slurm

# create that log file in management node
touch /var/log/slurm_jobcomp.log
chown slurm:slurm /var/log/slurm_jobcomp.log

slurmAccounting

# on management node
sudo systemctl restart slurmdbd
sudo systemctl restart slurmctld

#copy the munge key from management node to nfs shared
cp /etc/munge/munge.key /mnt/$nfs_mount_dir/

#copy the hosts list to nfs
cp /etc/hosts /mnt/$nfs_mount_dir/

# copy the config file from management node to nfs shared
cp /etc/slurm/slurm.conf /mnt/$nfs_mount_dir/
cp /etc/slurm/acct_gather.conf /mnt/$nfs_mount_dir/

mkdir -p /home/slurm/shared
sleep 2m
ln -s /mnt/$nfs_mount_dir /home/slurm/shared

# restart munge and daemons on every node
systemctl restart munge
systemctl restart slurmctld
sleep 10

# Install Scale Dependencies
install_scale_dependance(){
  sudo apt-get install ksh -y
  sudo apt-get install m4 -y
  sudo apt-get install make -y
  sudo apt-get install g++ -y
  sudo apt-get install numactl -y
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
  sudo apt-get remove openmpi-bin openmpi-doc libopenmpi-dev -y #remove openmpi comes with custom image
  sudo rm -rf /usr/bin/mpi* #remove openmpi comes with custom image
  sudo apt-get install gfortran -y
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
    copy_scale_package
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
touch /tmp/done
systemctl daemon-reload && systemctl restart systemd-networkd
