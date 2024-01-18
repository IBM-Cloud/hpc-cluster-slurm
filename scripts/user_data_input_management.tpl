#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile=/tmp/user_data.log
echo START `date '+%Y-%m-%d %H:%M:%S'`

#
# Export user data, which is defined with the "UserData" attribute
# in the template
#
%EXPORT_USER_DATA%

#input parameters
VPC_APIKEY_VALUE="${vpc_apikey_value}"
RESOURCE_RECORDS_APIKEY_VALUE="${vpc_apikey_value}"
imageID="${image_id}"
subnetID="${subnet_id}"
vpcID="${vpc_id}"
securityGroupID="${security_group_id}"
sshkey_ID="${sshkey_id}"
regionName="${region_name}"
zoneName="${zone_name}"
# the CIDR block for dyanmic hosts
rc_cidr_block="${rc_cidr_block}"
# the instance profile for dynamic hosts
hf_profile="${hf_profile}"
# number of cores for the instance profile
hf_ncores=${hf_ncores}
# number of cpus for the instance profile
hf_ncpus=${hf_ncpus}
# memory size in MB for the instance profile
hf_memInMB=${hf_memInMB}
management_ips="${management_ips}"
worker_ips="${worker_ips}"
storage_ips="${storage_ips}"
cluster_name="${cluster_id}"
cluster_prefix="${cluster_prefix}"
hyperthreading="${hyperthreading}"
ha_enabled="${ha_enabled}"
slurm_version="${slurm_version}"
