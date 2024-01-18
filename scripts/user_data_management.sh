###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# User data script for Slurm management node to support Ubuntu

nfs_server=${storage_ips}
nfs_mount_dir="data"

sudo apt update -y

sudo apt install slurm-wlm=${slurm_version} -y
sudo apt install slurm-wlm-doc=${slurm_version} -y

# checking paths in these service files
cat /lib/systemd/system/slurmctld.service
cat /lib/systemd/system/slurmd.service

#check the status of munge
systemctl status munge

apt install nfs-common -y

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
  ln -s /mnt/$nfs_mount_dir /home/slurm/shared
}

if ([ -n "${nfs_server}" ] && [ -n "${nfs_mount_dir}" ]); then
  echo "NFS server and share found, start mount nfs share!" >> $logfile
  #Mount the nfs share
  mountNFS $nfs_server $nfs_mount_dir 10 30 $logfile
  df -h /mnt/$nfs_mount_dir >> $logfile
  echo "Mount nfs share done!" >> $logfile
  
  # Generate and copy a public ssh key
  mkdir -p /mnt/$nfs_mount_dir/ssh /home/slurm/.ssh
  ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -C "slurm@${ManagementHostName}" -N "" -q
  cat /root/.ssh/id_rsa.pub >> /mnt/data/ssh/authorized_keys
  #mv /root/.ssh/id_rsa /home/slurm/.ssh/
  #cp /home/slurm/.ssh/id_rsa /root/.ssh

  sudo mkdir -p /mnt/$nfs_mount_dir/slurm-llnl
  sudo chown slurm:slurm /mnt/$nfs_mount_dir/slurm-llnl

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

i=0
for management_ip in ${management_ips}; do
  if [ $i -gt 0 ]; then
      let j=$i-1
      echo "$management_ip ${cluster_prefix}-management-candidate-$j" >> /etc/hosts
    else
      echo "$management_ip ${cluster_prefix}-management-$i" >> /etc/hosts
    fi
    management_hostnames="${management_hostnames} $cluster_prefix-management-$i"
    i=`expr $i + 1`
done
i=0
for worker_ip in ${worker_ips}; do
    echo "$worker_ip ${cluster_prefix}-worker-$i" >> /etc/hosts
    worker_hostnames="${worker_hostnames} $cluster_prefix-worker-$i"
    i=`expr $i + 1`
done

worker_index=`expr $i - 1`
management_index=`expr $i - 1`

if $ha_enabled; then
  backup_management="SlurmctldHost=${cluster_prefix}-management-candidate-0"
else
  backup_management=""
fi

if $hyperthreading; then
  ThreadsPerCore=2
else
  ThreadsPerCore=1
fi

# Now set up slurm.conf
cat > /etc/slurm-llnl/slurm.conf << EOF
# Slurm Configuration file
# Should be the same across management node and all worker nodes

SlurmctldHost=${cluster_prefix}-management-0
${backup_management}

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
ProctrackType=proctrack/pgid
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
SlurmdSpoolDir=/var/spool/slurm-llnl/ctld
SlurmUser=slurm
#SlurmdUser=root
#SrunEpilog=
#SrunProlog=
StateSaveLocation=/mnt/data/slurm-llnl
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
AccountingStorageType=accounting_storage/filetxt
AccountingStorageLoc=/var/log/slurm-llnl/acct_completions
#AccountingStorageUser=
AccountingStoreJobComment=YES
ClusterName=SlurmCluster
#DebugFlags=
#JobCompHost=
JobCompLoc=/var/log/slurm-llnl/job_completions
#JobCompPass=
#JobCompPort=
JobCompType=jobcomp/filetxt
#JobCompUser=
#JobContainerType=job_container/none
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=debug
SlurmctldLogFile=/var/log/slurm-llnl/slurmctld.log
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurm-llnl/slurmd.log
SlurmSchedLogFile=/var/log/slurm-llnl/slurmsched.log
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
NodeName=${cluster_prefix}-worker-[0-${worker_index}] CPUs=${ncpus} ThreadsPerCore=${ThreadsPerCore} RealMemory=`expr ${hf_memInMB} - 2048` State=UNKNOWN
PartitionName=debug Nodes=${cluster_prefix}-worker-[0-${worker_index}] Default=YES MaxTime=INFINITE State=UP
EOF

# restart munge on every node
sudo systemctl enable munge
sudo systemctl start munge

sudo mkdir /var/spool/slurm-llnl
sudo chown slurm:slurm /var/spool/slurm-llnl

sudo mkdir /var/run/slurm-llnl
sudo chown slurm:slurm /var/run/slurm-llnl

# create that log file in management node
touch /var/log/slurm_jobcomp.log
chown slurm:slurm /var/log/slurm_jobcomp.log

# on management node
sudo systemctl enable slurmctld
sudo systemctl restart slurmctld
sudo systemctl status slurmctld

#copy the munge key from management node to nfs shared
cp /etc/munge/munge.key /mnt/data/

#copy the hosts list to nfs
cp /etc/hosts /mnt/data/

# copy the config file from management node to nfs shared
cp /etc/slurm-llnl/slurm.conf /mnt/data/

# restart munge and deamons on every node
systemctl restart munge
systemctl restart slurmctld
