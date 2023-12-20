# Slurm README

Slurm on IBM Cloud enables customers to use Terraform as an automation tool to easily and quickly deploy Slurm clusters. The automation has been validated and tested for Slurm 19.05.5-1 Advanced Edition. For more details you can refer to our [documentation](https://cloud.ibm.com/docs/hpc-slurm?topic=hpc-slurm-getting-started-tutorial)
 
# Support
Depending on the area where the issue is encountered use the following channels for getting help with the solution:
1. If the issue is with automation code, you can create an issue on this [git repository](https://github.com/IBM-Cloud/hpc-cluster-slurm)
2. If the issue is with IBM Cloud infrastructure you can create a cloud support case [here](https://cloud.ibm.com/unifiedsupport/supportcenter)
3. If the issue is with Slurm software, you can work with SchedMD corporation and get help [here](https://www.schedmd.com/services.php)

# Deployment with Schematics CLI on IBM Cloud

Initial configuration:

```
$ cp sample/configs/hpc_workspace_config.json config.json
$ ibmcloud iam api-key-create my-api-key --file ~/.ibm-api-key.json -d "my api key"
$ cat ~/.ibm-api-key.json | jq -r ."apikey"
# copy your apikey
$ vim config.json
# paste your apikey
```

You also need to generate github token if you use private Github repository.

Deployment:

```
$ ibmcloud schematics workspace new -f config.json --github-token xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ ibmcloud schematics workspace list
Name               ID                                            Description   Status     Frozen
hpcc-slurm-test       us-east.workspace.hpcc-slurm-test.7cbc3f6b                     INACTIVE   False

OK
$ ibmcloud schematics plan --id us-east.workspace.hpcc-slurm-test.7cbc3f6b

Activity ID b0a909030f071f51d6ceb48b62ee1671

OK
$ ibmcloud schematics apply --id us-east.workspace.hpcc-slurm-test.7cbc3f6b
Do you really want to perform this action? [y/N]> y

Activity ID b0a909030f071f51d6ceb48b62ee1672

OK
$ ibmcloud schematics logs --id us-east.workspace.hpcc-slurm-test.7cbc3f6b
...
 2021/04/05 09:44:54 Terraform apply | Apply complete! Resources: 14 added, 0 changed, 0 destroyed.
 2021/04/05 09:44:54 Terraform apply |
 2021/04/05 09:44:54 Terraform apply | Outputs:
 2021/04/05 09:44:54 Terraform apply |
 2021/04/05 09:44:54 Terraform apply | sshcommand = ssh -J root@52.116.124.67 root@10.241.0.6
 2021/04/05 09:44:54 Command finished successfully.
 2021/04/05 09:45:00 Done with the workspace action

OK
$ ssh -J root@52.116.124.67 root@10.241.0.6

$ ibmcloud schematics destroy --id us-east.workspace.hpcc-slurm-test.7cbc3f6b
Do you really want to perform this action? [y/N]> y

Activity ID b0a909030f071f51d6ceb48b62ee1673

OK
```

# Deployment with Schematics UI on IBM Cloud

1. Go to https://cloud.ibm.com/schematics, select Workspaces and then select create workspace using Schematics.
2.  In the Specify template section:
    - Provide your GitHub, GitLab or Bitbucket repository URL where your Terraform files resides.
    - If you are using a private GitHub repository, provide your personal GitHub access token that you set up in Setting up the IBM Cloud Schematics prerequisites.
    - Select the terraform version, the version of the Terraform engine that's used in the Schematics workspace, and then click Next.
3. In the workspace details section:
    - Specify the Name for your Schematics workspace
    - Define any Tags that you want to associate with the resources provisioned through the offering. The tags can later be used to query the resources in the IBM Cloud console.
    - Select a Resource group
    - Select a Location. Location determines where workspace actions will be executed
    - Provide a Description (optional) of the Schematics workspace.
    - Click on Next and Then click Create. The Schematics workspace is created with the name you specified.
4. Go to Schematic Workspace Settings, under variable section, click on "burger icons" to update the following parameters:
    - ssh_key_name with your ibm cloud SSH key name such as "slurm-ssh-key" created in a specific region in IBM Cloud
    - api_key with the api key value and mark it as sensitive to hide the API key in the IBM Cloud Console
    - Update cluster_prefix value to the specific cluster prefix for your Slurm cluster
    - Update cluster_id the ID of the cluster used by Slurm for configuration of resources
    - Update the worker_node_count as per your requirement
5. Click on "Generate Plan" and ensure there are no errors and fix the errors if there are any.
6. After "Generate Plan" gives no errors, click on "Apply Plan" to create resources.
7. When you click on "Apply plan" the post provisioning scripts run and the Slurm workload manager get installed.
8. Click on Jobs then Activity and Show more to view the resource creation progress.
9. Click on "Show more" if the "Apply Plan" activity is successful and copy the output SSH command to your laptop terminal to SSH to management node via a jump host public ip to SSH one of the nodes.
10. Also use this jump host public ip and change the IP address of the node you want to access via the jump host to access specific hosts.


# Storage Node and NFS Setup
The storage node is configured as an NFS server and the data volume is mounted to the /data directory which is exported to share with Slurm management nodes.

### Steps to validate Cluster setups
###### 1. To validate the NFS storage is setup and exported correctly
* Login to the storage node using SSH (ssh -J root@52.117.4.140  root@10.240.128.36)
* The command below shows that the data volume, /dev/vdd, is mounted to /data on the storage node.
```
# df -k | grep data
/dev/vdd       104806400   33008 104773392   1% /data`
```
* The command below shows that /data is exported as a NFS shared directory.

```
# exportfs -v
/data         10.240.128.32/27(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,no_root_squash,no_all_squash)
```

* At the NFS client end, the Slurm management/worker nodes in this case, we mount the /data directory in NFS server to the local directory, /data.
```
# df -k | grep data
10.240.128.36:/data  100G   32M  100G   1% /mnt/data
```
The command above shows that the local directory, /data, is mounted to the remote /data directory on the NFS server, 10.240.128.26.

###### 2. Steps to validate the cluster status
* Login to the management as shown in the ssh_command output.
```
# ssh -J root@52.117.4.140  root@10.240.128.37
```
* Check the status of the munge and slurm management daemon.
```
# systemctl status munge
# systemctl status slurmctld
```
* The command below show that the nfs is mounted correctly /data.
```
# showmount -e 10.240.128.36
```

###### 3. Steps to validate the cluster status
* Login to the worker as shown in the ssh_command output.
```
# ssh -J root@52.117.4.140  root@10.240.128.38
```
* Check the status of the munge and slurm node daemon.
```
# systemctl status munge
# systemctl status slurmd
```
* The command below show that the nfs is mounted correctly /data.
```
# showmount -e 10.240.128.36
```

# Testing
* The command below reports the state of partitions and nodes managed by Slurm.
```
# sinfo -N -l
```
* The command below reports the state of jobs or job steps. By default, it reports the running jobs in priority order and then the pending jobs in priority order.
```
# squeue
```
* The below command is used to allocate resources for a job in real time. Typically this is used to allocate resources and spawn a shell. The shell is then used to execute srun commands to launch parallel tasks.
```
# salloc
```

* The below commands can be used to report more detailed information about nodes, partitions, jobs, job steps, and configuration.
```
# scontrol show jobs
# scontrol show nodes
```
* The below commannd is used to cancel a pending or running job or job step. It can also be used to send an arbitrary signal to all processes associated with a running job or job step.
```
# scancel <job_id>
```
*  To use a specific number of nodes (one node as N1) and execute the command "hostname" on the worker nodes.
```
# srun -N1 -l hostname
0: hpcc-slurm-worker-0
```

## Stop ufw firewall 
*  Stop ufw firewall on all nodes (management and worker) if it doesn't work and restart slurmctld/slurmd or munge daemons.
```
# systemctl status ufw
# systemctl stop ufw
```
## Slurm-wlm 

This was run using Slurm version 19.05.5-1
| Name | Version |
|------|---------|
| <a name="requirement_slurm"></a> [slurm](#requirement\_slurm) | 19.05.5-1 |

* The command below shows that which slurm version is installed.
```
# dpkg -l | grep slurm
ii  slurm-client                   19.05.5-1            amd64        SLURM client side commands
ii  slurm-wlm                      19.05.5-1            amd64        Simple Linux Utility for Resource Management
ii  slurm-wlm-basic-plugins        19.05.5-1            amd64        SLURM basic plugins
ii  slurm-wlm-doc                  19.05.5-1            all          SLURM documentation
ii  slurmctld                      19.05.5-1            amd64        SLURM central management daemon
ii  slurmd                         19.05.5-1            amd64        SLURM worker node daemon
```

## Authentication issues

Issues with munge => munge daemon or munge key not same on all nodes


# Terraform Documentation

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | 1.30.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 1.30.0 |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ibm_is_floating_ip.login_fip](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_floating_ip) | resource |
| [ibm_is_instance.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.management](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.management_candidate](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_public_gateway.mygateway](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_public_gateway) | resource |
| [ibm_is_security_group.login_sg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group) | resource |
| [ibm_is_security_group.sg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group) | resource |
| [ibm_is_security_group_rule.egress_all](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_all_local](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_vpn](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_tcp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_udp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_tcp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_udp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_subnet.login_subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_subnet) | resource |
| [ibm_is_subnet.subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_subnet) | resource |
| [ibm_is_volume.nfs](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_volume) | resource |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_vpc) | resource |
| [ibm_is_vpn_gateway.vpn](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_vpn_gateway) | resource |
| [ibm_is_vpn_gateway_connection.conn](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_vpn_gateway_connection) | resource |
| [ibm_is_image.image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.stock_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_image) | data source |
| [ibm_is_instance_profile.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.management](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_region.region](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_region) | data source |
| [ibm_is_ssh_key.ssh_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_ssh_key) | data source |
| [ibm_is_volume_profile.nfs](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_volume_profile) | data source |
| [ibm_is_vpc.existing_vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_zone.zone](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_zone) | data source |
| [ibm_resource_group.rg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/resource_group) | data source |
| [template_file.management_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.storage_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.worker_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | This is the API key for IBM Cloud account in which the Slurm cluster needs to be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-userapikey) | `string` | n/a | yes |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | ID of the cluster used by Slurm for configuration of resources. This must be up to 39 alphanumeric characters including the underscore (\_), the hyphen (-), and the period (.). Other special characters and spaces are not allowed. Do not use the name of any host or user as the name of your cluster. You cannot change it after installation. | `string` | `"SlurmCluster"` | no |
| <a name="input_cluster_prefix"></a> [cluster\_prefix](#input\_cluster\_prefix) | Prefix that would be used to name Slurm cluster and IBM Cloud resources provisioned to build the Slurm cluster instance. You cannot create more than one instance of Slurm Cluster with same name, make sure the name is unique. Enter a prefix name, such as my-hpcc | `string` | `"hpcc-slurm"` | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | Name of the image that you want to use to create virtual server instances in your IBM Cloud account to deploy as worker nodes in the Slurm cluster. By default, the automation uses a stock operating system image. If you would like to include your application-specific binary files, follow the instructions in [Planning for custom images](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Slurm cluster through this offering. Note that use of your own custom image may require changes to the cloud-init scripts, and potentially other files, in the Terraform code repository if different post-provisioning actions or variables need to be implemented. | `string` | `"ibm-ubuntu-20-04-minimal-amd64-2"` | no |
| <a name="input_login_node_instance_type"></a> [login\_node\_instance\_type](#input\_login\_node\_instance\_type) | Specify the VSI profile type name to be used to create the login node for Slurm cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-2x8"` | no |
| <a name="input_management_node_count"></a> [management\_node\_count](#input\_management\_node\_count) | This is the total number of management nodes. Enter a value in the range 1 - 2. | `number` | `1` | no |
| <a name="input_management_node_instance_type"></a> [management\_node\_instance\_type](#input\_management\_node\_instance\_type) | Specify the VSI profile type name to be used to create the management node for Slurm cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-4x16"` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Resource group name from your IBM Cloud account where the VPC resources should be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-rgs) | `string` | `"Default"` | no |
| <a name="input_ssh_allowed_ips"></a> [ssh\_allowed\_ips](#input\_ssh\_allowed\_ips) | Comma separated list of IP addresses that can access the Slurm instance through SSH interface. The default value allows any IP address to access the cluster. | `string` | `"0.0.0.0/0"` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | Comma-separated list of names of the SSH key configured in your IBM Cloud account that is used to establish a connection to the Slurm management node. Ensure the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the instructions given [here](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys). | `string` | n/a | yes |
| <a name="input_storage_node_instance_type"></a> [storage\_node\_instance\_type](#input\_storage\_node\_instance\_type) | Specify the VSI profile type name to be used to create the storage nodes for Slurm cluster. The storage nodes are the ones that would be used to create an NFS instance to manage the data for HPC workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-2x8"` | no |
| <a name="input_volume_capacity"></a> [volume\_capacity](#input\_volume\_capacity) | Size in GB for the block storage that would be used to build the NFS instance and would be available as a mount on Slurm management node. Enter a value in the range 10 - 16000. | `number` | `100` | no |
| <a name="input_volume_iops"></a> [volume\_iops](#input\_volume\_iops) | Number to represent the IOPS(Input Output Per Second) configuration for block storage to be used for NFS instance (valid only for volume\_profile=custom, dependent on volume\_capacity). Enter a value in the range 100 - 48000. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles#custom) | `number` | `300` | no |
| <a name="input_volume_profile"></a> [volume\_profile](#input\_volume\_profile) | Name of the block storage volume type to be used for NFS instance. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles) | `string` | `"general-purpose"` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc) | `string` | `""` | no |
| <a name="input_vpn_enabled"></a> [vpn\_enabled](#input\_vpn\_enabled) | Set to true to deploy a VPN gateway for VPC in the cluster (default: false). | `bool` | `false` | no |
| <a name="input_vpn_peer_address"></a> [vpn\_peer\_address](#input\_vpn\_peer\_address) | The peer public IP address to which the VPN will be connected. | `string` | `""` | no |
| <a name="input_vpn_peer_cidrs"></a> [vpn\_peer\_cidrs](#input\_vpn\_peer\_cidrs) | Comma separated list of peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected. | `string` | `""` | no |
| <a name="input_vpn_preshared_key"></a> [vpn\_preshared\_key](#input\_vpn\_preshared\_key) | The pre-shared key for the VPN. | `string` | `""` | no |
| <a name="input_worker_node_count"></a> [worker\_node\_count](#input\_worker\_node\_count) | This is the number of worker nodes that will be provisioned at the time the cluster is created. Enter a value in the range 1 - 500. | `number` | `1` | no |
| <a name="input_worker_node_instance_type"></a> [worker\_node\_instance\_type](#input\_worker\_node\_instance\_type) | Specify the VSI profile type name to be used to create the worker nodes for Slurm cluster. The worker nodes are the ones where the workload execution takes place and choice should be made according to the characteristic of workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-4x16"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | IBM Cloud zone name within the selected region where the Slurm cluster should be deployed. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ha_enabled"></a> [ha\_enabled](#output\_ha\_enabled) | n/a |
| <a name="output_region_name"></a> [region\_name](#output\_region\_name) | n/a |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | n/a |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | n/a |
| <a name="output_vpn_config_info"></a> [vpn\_config\_info](#output\_vpn\_config\_info) | n/a |
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | 1.30.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 1.30.0 |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ibm_is_floating_ip.login_fip](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_floating_ip) | resource |
| [ibm_is_instance.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.management](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.management_candidate](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_instance) | resource |
| [ibm_is_public_gateway.mygateway](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_public_gateway) | resource |
| [ibm_is_security_group.login_sg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group) | resource |
| [ibm_is_security_group.sg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group) | resource |
| [ibm_is_security_group_rule.egress_all](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_all_local](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.ingress_vpn](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_tcp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_egress_udp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_tcp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_tcp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.login_ingress_udp_rhsm](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_security_group_rule) | resource |
| [ibm_is_subnet.login_subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_subnet) | resource |
| [ibm_is_subnet.subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_subnet) | resource |
| [ibm_is_volume.nfs](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_volume) | resource |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_vpc) | resource |
| [ibm_is_vpn_gateway.vpn](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_vpn_gateway) | resource |
| [ibm_is_vpn_gateway_connection.conn](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/resources/is_vpn_gateway_connection) | resource |
| [ibm_is_image.image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.stock_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_image) | data source |
| [ibm_is_instance_profile.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.management](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_region.region](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_region) | data source |
| [ibm_is_ssh_key.ssh_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_ssh_key) | data source |
| [ibm_is_volume_profile.nfs](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_volume_profile) | data source |
| [ibm_is_vpc.existing_vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_zone.zone](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/is_zone) | data source |
| [ibm_resource_group.rg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.30.0/docs/data-sources/resource_group) | data source |
| [template_file.management_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.storage_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.worker_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | This is the API key for IBM Cloud account in which the Slurm cluster needs to be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-userapikey) | `string` | n/a | yes |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | ID of the cluster used by Slurm for configuration of resources. This must be up to 39 alphanumeric characters including the underscore (\_), the hyphen (-), and the period (.). Other special characters and spaces are not allowed. Do not use the name of any host or user as the name of your cluster. You cannot change it after installation. | `string` | `"SlurmCluster"` | no |
| <a name="input_cluster_prefix"></a> [cluster\_prefix](#input\_cluster\_prefix) | Prefix that would be used to name Slurm cluster and IBM Cloud resources provisioned to build the Slurm cluster instance. You cannot create more than one instance of Slurm Cluster with same name, make sure the name is unique. Enter a prefix name, such as my-hpcc | `string` | `"hpcc-slurm"` | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | Name of the image that you want to use to create virtual server instances in your IBM Cloud account to deploy as worker nodes in the Slurm cluster. By default, the automation uses a stock operating system image. If you would like to include your application-specific binary files, follow the instructions in [Planning for custom images](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Slurm cluster through this offering. Note that use of your own custom image may require changes to the cloud-init scripts, and potentially other files, in the Terraform code repository if different post-provisioning actions or variables need to be implemented. | `string` | `"ibm-ubuntu-20-04-minimal-amd64-2"` | no |
| <a name="input_login_node_instance_type"></a> [login\_node\_instance\_type](#input\_login\_node\_instance\_type) | Specify the VSI profile type name to be used to create the login node for Slurm cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-2x8"` | no |
| <a name="input_management_node_count"></a> [management\_node\_count](#input\_management\_node\_count) | This is the total number of management nodes. Enter a value in the range 1 - 2. | `number` | `1` | no |
| <a name="input_management_node_instance_type"></a> [management\_node\_instance\_type](#input\_management\_node\_instance\_type) | Specify the VSI profile type name to be used to create the management node for Slurm cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-4x16"` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Resource group name from your IBM Cloud account where the VPC resources should be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-rgs) | `string` | `"Default"` | no |
| <a name="input_ssh_allowed_ips"></a> [ssh\_allowed\_ips](#input\_ssh\_allowed\_ips) | Comma separated list of IP addresses that can access the Slurm instance through SSH interface. The default value allows any IP address to access the cluster. | `string` | `"0.0.0.0/0"` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | Comma-separated list of names of the SSH key configured in your IBM Cloud account that is used to establish a connection to the Slurm management node. Ensure the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the instructions given [here](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys). | `string` | n/a | yes |
| <a name="input_storage_node_instance_type"></a> [storage\_node\_instance\_type](#input\_storage\_node\_instance\_type) | Specify the VSI profile type name to be used to create the storage nodes for Slurm cluster. The storage nodes are the ones that would be used to create an NFS instance to manage the data for HPC workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-2x8"` | no |
| <a name="input_volume_capacity"></a> [volume\_capacity](#input\_volume\_capacity) | Size in GB for the block storage that would be used to build the NFS instance and would be available as a mount on Slurm management node. Enter a value in the range 10 - 16000. | `number` | `100` | no |
| <a name="input_volume_iops"></a> [volume\_iops](#input\_volume\_iops) | Number to represent the IOPS(Input Output Per Second) configuration for block storage to be used for NFS instance (valid only for volume\_profile=custom, dependent on volume\_capacity). Enter a value in the range 100 - 48000. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles#custom) | `number` | `300` | no |
| <a name="input_volume_profile"></a> [volume\_profile](#input\_volume\_profile) | Name of the block storage volume type to be used for NFS instance. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles) | `string` | `"general-purpose"` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc) | `string` | `""` | no |
| <a name="input_vpn_enabled"></a> [vpn\_enabled](#input\_vpn\_enabled) | Set to true to deploy a VPN gateway for VPC in the cluster (default: false). | `bool` | `false` | no |
| <a name="input_vpn_peer_address"></a> [vpn\_peer\_address](#input\_vpn\_peer\_address) | The peer public IP address to which the VPN will be connected. | `string` | `""` | no |
| <a name="input_vpn_peer_cidrs"></a> [vpn\_peer\_cidrs](#input\_vpn\_peer\_cidrs) | Comma separated list of peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected. | `string` | `""` | no |
| <a name="input_vpn_preshared_key"></a> [vpn\_preshared\_key](#input\_vpn\_preshared\_key) | The pre-shared key for the VPN. | `string` | `""` | no |
| <a name="input_worker_node_count"></a> [worker\_node\_count](#input\_worker\_node\_count) | This is the number of worker nodes that will be provisioned at the time the cluster is created. Enter a value in the range 1 - 500. | `number` | `1` | no |
| <a name="input_worker_node_instance_type"></a> [worker\_node\_instance\_type](#input\_worker\_node\_instance\_type) | Specify the VSI profile type name to be used to create the worker nodes for Slurm cluster. The worker nodes are the ones where the workload execution takes place and choice should be made according to the characteristic of workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-4x16"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | IBM Cloud zone name within the selected region where the Slurm cluster should be deployed. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ha_enabled"></a> [ha\_enabled](#output\_ha\_enabled) | n/a |
| <a name="output_region_name"></a> [region\_name](#output\_region\_name) | n/a |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | n/a |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | n/a |
| <a name="output_vpn_config_info"></a> [vpn\_config\_info](#output\_vpn\_config\_info) | n/a |
