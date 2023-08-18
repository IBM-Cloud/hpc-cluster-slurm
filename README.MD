# Slurm README

Slurm on IBM Cloud enables customers to use Terraform as an automation tool to easily and quickly deploy Slurm clusters. The automation has been validated and tested for Slurm 21.08.5-2ubuntu1 Advanced Edition. For more details you can refer to our [documentation](https://cloud.ibm.com/docs/hpc-slurm?topic=hpc-slurm-getting-started-tutorial)
 
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
 2023/04/26 08:20:37 Terraform apply | Apply complete! Resources: 34 added, 0 changed, 0 destroyed.
 2023/04/26 08:20:37 Terraform apply | 
 2023/04/26 08:20:37 Terraform apply | Outputs:
 2023/04/26 08:20:37 Terraform apply | 
 2023/04/26 08:20:37 Terraform apply | nfs_ssh_command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J root@158.177.2.7 root@10.243.0.36"
 2023/04/26 08:20:37 Terraform apply | region_name = "eu-de"
 2023/04/26 08:20:37 Terraform apply | ssh_command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J root@158.177.2.7  root@10.243.0.37"
 2023/04/26 08:20:37 Terraform apply | vpc_name = "marvel-slurm-vpc --  - r010-5d7c29b4-5585-49bc-bfde-ab145d9f104b"
 2023/04/26 08:20:37 Command finished successfully.

OK
$ ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J root@158.177.2.7  root@10.243.0.37"

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
###### How to login cluster nodes:
  ###### Storage Node
    - On a local machine, ssh [-i <identity_file>] -J root@<floating_ip_of_bastion_node> ubuntu@<private_ip_of_storage_node>
      Example: ssh -J root@52.117.4.140  root@10.243.0.36 (or) ssh -i id_rsa -J root@52.117.4.140  root@10.243.0.36
  ###### Slurm Management / Slurm Worker / Scale Storage Node
    - On a local machine, ssh [-i <identity_file>] -J root@<floating_ip_of_bastion_node> ubuntu@<private_ip_for_the_node>
      Example:ssh -J root@52.117.4.140  ubuntu@10.243.0.37 (or) ssh -i id_rsa -J root@52.117.4.140  ubuntu@10.243.0.37
  
###### 1. To validate the NFS storage is setup and exported correctly
* Login to the storage node using SSH (ssh -J root@<floating_ip_of_bastion_node>  root@<private_ip_of_storage_node>)
* The command below shows that the data volume, /dev/vdd, is mounted to /data on the storage node.
```
# df -k | grep data
/dev/vdd       104806400   33008 104773392   1% /data`
```
* The command below shows that /data is exported as a NFS shared directory.

```
# exportfs -v
/data         <private_ip_of_storage_node>/27(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,no_root_squash,no_all_squash)
```

* At the NFS client end, the Slurm management/worker nodes in this case, we mount the /data directory in NFS server to the local directory, /data.
```
# df -k | grep data
10.243.0.36:/data  100G   32M  100G   1% /mnt/data
```
The command above shows that the local directory, /data, is mounted to the remote /data directory on the NFS server, 10.240.128.26.

###### 2. Steps to validate the cluster status
* Login to the management as shown in the ssh_command output.
```
# ssh -J root@<floating_ip_of_bastion_node> ubuntu@<private_ip_of_management_node>
```
* Check the status of the munge and slurm management daemon.
```
# systemctl status munge
# systemctl status slurmctld
```
* The command below show that the nfs is mounted correctly /data.
```
# showmount -e <private_ip_of_storage_node>
```

###### 3. Steps to validate the cluster status
* Login to the worker as shown in the ssh_command output.
```
# ssh -J root@<floating_ip_of_bastion_node> ubuntu@<private_ip_of_worker_node>
```
* Check the status of the munge and slurm node daemon.
```
# systemctl status munge
# systemctl status slurmd
```
* The command below show that the nfs is mounted correctly /data.
```
# showmount -e <private_ip_of_storage_node>
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

This was run using Slurm version 21.08.5-2ubuntu1
| Name | Version |
|------|---------|
| <a name="requirement_slurm"></a> [slurm](#requirement\_slurm) | 21.08.5-2ubuntu1 |

* The command below shows that which slurm version is installed.
```
# dpkg -l | grep slurm
ii  slurm-client                   21.08.5-2ubuntu1            amd64        SLURM client side commands
ii  slurm-wlm                      21.08.5-2ubuntu1            amd64        Simple Linux Utility for Resource Management
ii  slurm-wlm-basic-plugins        21.08.5-2ubuntu1            amd64        SLURM basic plugins
ii  slurm-wlm-doc                  21.08.5-2ubuntu1            all          SLURM documentation
ii  slurmctld                      21.08.5-2ubuntu1            amd64        SLURM central management daemon
ii  slurmd                         21.08.5-2ubuntu1            amd64        SLURM compute node daemon
```

## Authentication issues

Issues with munge => munge daemon or munge key not same on all nodes

## Steps to validate spectrum scale integration
###### How to login Scale Storage nodes and Access Scale GUI:
  ###### Scale Storage Node
    - On a local machine, ssh [-i <identity_file>] -L 22443:localhost:443 -J root@<floating_ip_of_bastion_node> ubuntu@<private_ip_of_scale_storage_node>
      Example: ssh -L 22443:localhost:443 -J root@52.117.4.140  root@10.243.0.39 (or) ssh -i id_rsa -L 22443:localhost:443 -J root@52.117.4.140  root@10.243.0.39
  ###### Access Scale Storage GUI 
    - On local machine, open a local browser window and go to this URL:  https://localhost:22443
  
* The below command shows the gpfs cluster setup on scale storage node.
```buildoutcfg
# /usr/lpp/mmfs/bin/mmlscluster
```
* The below command shows file system mounted on number of nodes
```buildoutcfg
# /usr/lpp/mmfs/bin/mmlsmount all
```
* The below command shows the fileserver details. This command can be used to validate file block size(Inode size in bytes).
```buildoutcfg
#   /usr/lpp/mmfs/bin/mmlsfs all -i
```

* Create a file on mountpoint path(e.g `/gpfs/fs1`) and verify on other nodes that the file can be accessed.


## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.4.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | 1.55.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_http"></a> [http](#provider\_http) | 3.4.0 |
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 1.55.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.1 |
| <a name="provider_template"></a> [template](#provider\_template) | 2.2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_inbound_sg_ingress_all_local_rule"></a> [inbound\_sg\_ingress\_all\_local\_rule](#module\_inbound\_sg\_ingress\_all\_local\_rule) | ./resources/ibmcloud/security/security_group_ingress_all_local | n/a |
| <a name="module_inbound_sg_rule"></a> [inbound\_sg\_rule](#module\_inbound\_sg\_rule) | ./resources/ibmcloud/security/security_group_inbound_rule | n/a |
| <a name="module_ingress_vpn"></a> [ingress\_vpn](#module\_ingress\_vpn) | ./resources/ibmcloud/security/vpn_ingress_sg_rule | n/a |
| <a name="module_invoke_storage_playbook"></a> [invoke\_storage\_playbook](#module\_invoke\_storage\_playbook) | ./resources/scale_common/ansible_playbook | n/a |
| <a name="module_login_fip"></a> [login\_fip](#module\_login\_fip) | ./resources/ibmcloud/network/floating_ip | n/a |
| <a name="module_login_inbound_security_rules"></a> [login\_inbound\_security\_rules](#module\_login\_inbound\_security\_rules) | ./resources/ibmcloud/security/login_sg_inbound_rule | n/a |
| <a name="module_login_outbound_security_rule"></a> [login\_outbound\_security\_rule](#module\_login\_outbound\_security\_rule) | ./resources/ibmcloud/security/login_sg_outbound_rule | n/a |
| <a name="module_login_sg"></a> [login\_sg](#module\_login\_sg) | ./resources/ibmcloud/security/login_sg | n/a |
| <a name="module_login_ssh_key"></a> [login\_ssh\_key](#module\_login\_ssh\_key) | ./resources/scale_common/generate_keys | n/a |
| <a name="module_login_subnet"></a> [login\_subnet](#module\_login\_subnet) | ./resources/ibmcloud/network/login_subnet | n/a |
| <a name="module_login_vsi"></a> [login\_vsi](#module\_login\_vsi) | ./resources/ibmcloud/compute/vsi_login | n/a |
| <a name="module_management"></a> [management](#module\_management) | ./resources/ibmcloud/compute/vsi_management_server | n/a |
| <a name="module_nfs_storage"></a> [nfs\_storage](#module\_nfs\_storage) | ./resources/ibmcloud/compute/vsi_nfs_storage_server | n/a |
| <a name="module_nfs_volume"></a> [nfs\_volume](#module\_nfs\_volume) | ./resources/ibmcloud/network/nfs_volume | n/a |
| <a name="module_outbound_sg_rule"></a> [outbound\_sg\_rule](#module\_outbound\_sg\_rule) | ./resources/ibmcloud/security/security_group_outbound_rule | n/a |
| <a name="module_prepare_spectrum_scale_ansible_repo"></a> [prepare\_spectrum\_scale\_ansible\_repo](#module\_prepare\_spectrum\_scale\_ansible\_repo) | ./resources/scale_common/git_utils | n/a |
| <a name="module_public_gw"></a> [public\_gw](#module\_public\_gw) | ./resources/ibmcloud/network/public_gw | n/a |
| <a name="module_schematics_sg_tcp_rule"></a> [schematics\_sg\_tcp\_rule](#module\_schematics\_sg\_tcp\_rule) | ./resources/ibmcloud/security/security_tcp_rule | n/a |
| <a name="module_sg"></a> [sg](#module\_sg) | ./resources/ibmcloud/security/security_group | n/a |
| <a name="module_storage_cluster_configuration"></a> [storage\_cluster\_configuration](#module\_storage\_cluster\_configuration) | ./resources/scale_common/storage_configuration | n/a |
| <a name="module_subnet"></a> [subnet](#module\_subnet) | ./resources/ibmcloud/network/subnet | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./resources/ibmcloud/network/vpc | n/a |
| <a name="module_vpc_address_prefix"></a> [vpc\_address\_prefix](#module\_vpc\_address\_prefix) | ./resources/ibmcloud/network/vpc_address_prefix | n/a |
| <a name="module_vpn"></a> [vpn](#module\_vpn) | ./resources/ibmcloud/network/vpn | n/a |
| <a name="module_vpn_connection"></a> [vpn\_connection](#module\_vpn\_connection) | ./resources/ibmcloud/network/vpn_connection | n/a |
| <a name="module_worker_bare_metal"></a> [worker\_bare\_metal](#module\_worker\_bare\_metal) | ./resources/ibmcloud/compute/bare_metal_worker_server | n/a |
| <a name="module_worker_nodes_wait"></a> [worker\_nodes\_wait](#module\_worker\_nodes\_wait) | ./resources/scale_common/wait | n/a |
| <a name="module_worker_vsi"></a> [worker\_vsi](#module\_worker\_vsi) | ./resources/ibmcloud/compute/vsi_worker_server | n/a |
| <a name="module_write_storage_cluster_inventory"></a> [write\_storage\_cluster\_inventory](#module\_write\_storage\_cluster\_inventory) | ./resources/scale_common/write_inventory | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.upgrade_jinja](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [http_http.fetch_myip](https://registry.terraform.io/providers/hashicorp/http/3.4.0/docs/data-sources/http) | data source |
| [ibm_is_bare_metal_server_profile.worker_bare_metal_server_profile](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_bare_metal_server_profile) | data source |
| [ibm_is_image.management_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.stock_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_image) | data source |
| [ibm_is_image.worker_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_image) | data source |
| [ibm_is_instance_profile.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.management](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.storage](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.worker](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_region.region](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_region) | data source |
| [ibm_is_ssh_key.ssh_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_ssh_key) | data source |
| [ibm_is_subnet.subnet_id](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_subnet) | data source |
| [ibm_is_volume_profile.nfs](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_volume_profile) | data source |
| [ibm_is_vpc.existing_vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_vpc) | data source |
| [ibm_is_vpc_address_prefixes.existing_vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_vpc_address_prefixes) | data source |
| [ibm_is_zone.zone](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/is_zone) | data source |
| [ibm_resource_group.rg](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.55.0/docs/data-sources/resource_group) | data source |
| [template_file.login_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.management_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.storage_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.worker_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_TF_WAIT_DURATION"></a> [TF\_WAIT\_DURATION](#input\_TF\_WAIT\_DURATION) | wait duration time set for the storage and worker node to complete the entire setup | `string` | `"600s"` | no |
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | This is the API key for IBM Cloud account in which the Slurm cluster needs to be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-userapikey) | `string` | n/a | yes |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | ID of the cluster used by Slurm for configuration of resources. This must be up to 39 alphanumeric characters including the underscore (\_), the hyphen (-), and the period (.). Other special characters and spaces are not allowed. Do not use the name of any host or user as the name of your cluster. You cannot change it after installation. | `string` | `"SlurmCluster"` | no |
| <a name="input_cluster_prefix"></a> [cluster\_prefix](#input\_cluster\_prefix) | Prefix that would be used to name Slurm cluster and IBM Cloud resources provisioned to build the Slurm cluster instance. You cannot create more than one instance of Slurm Cluster with same name, make sure the name is unique. Enter a prefix name, such as my-hpcc | `string` | `"hpcc-slurm"` | no |
| <a name="input_login_node_instance_type"></a> [login\_node\_instance\_type](#input\_login\_node\_instance\_type) | Specify the VSI profile type name to be used to create the login node for Slurm cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"cx2-16x32"` | no |
| <a name="input_management_node_image_name"></a> [management\_node\_image\_name](#input\_management\_node\_image\_name) | Name of the image that you want to use to create virtual server instances in your IBM Cloud account to deploy as worker nodes in the Slurm cluster. By default, the automation uses a stock operating system image. If you would like to include your application-specific binary files, follow the instructions in [Planning for custom images](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Slurm cluster through this offering. Note that use of your own custom image may require changes to the cloud-init scripts, and potentially other files, in the Terraform code repository if different post-provisioning actions or variables need to be implemented. | `string` | `"hpcc-slurm-management-v1-03may23"` | no |
| <a name="input_management_node_instance_type"></a> [management\_node\_instance\_type](#input\_management\_node\_instance\_type) | Specify the VSI profile type name to be used to create the management node for Slurm cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"cx2-16x32"` | no |
| <a name="input_remote_allowed_ips"></a> [remote\_allowed\_ips](#input\_remote\_allowed\_ips) | Comma-separated list of IP addresses that can access the Slurm instance through an SSH. For security purposes, provide the public IP addresses assigned to the devices that are authorized to establish SSH (for example, ["169.45.117.34"]). To fetch the IP address of the device, use [https://ipv4.icanhazip.com/](https://ipv4.icanhazip.com/). | `list(string)` | n/a | yes |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Resource group name from your IBM Cloud account where the VPC resources should be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-rgs) | `string` | `"Default"` | no |
| <a name="input_scale_filesystem_block_size"></a> [scale\_filesystem\_block\_size](#input\_scale\_filesystem\_block\_size) | File system [block size](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=considerations-block-size). Spectrum Scale supported block sizes (in bytes) include: 256K, 512K, 1M, 2M, 4M, 8M, 16M. | `string` | `"4M"` | no |
| <a name="input_scale_storage_cluster_filesystem_mountpoint"></a> [scale\_storage\_cluster\_filesystem\_mountpoint](#input\_scale\_storage\_cluster\_filesystem\_mountpoint) | Spectrum Scale storage cluster (owningCluster) file system mount point. The owningCluster is the cluster that owns and serves the file system to be mounted.  For more information, see [Mounting a remote GPFS file system](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=system-mounting-remote-gpfs-file). | `string` | `"/gpfs/fs1"` | no |
| <a name="input_spectrum_scale_enabled"></a> [spectrum\_scale\_enabled](#input\_spectrum\_scale\_enabled) | Setting this to 'true' will enable Spectrum Scale integration with the cluster. Otherwise, Spectrum Scale integration will be disabled (default). By entering 'true' for the property you have also agreed to one of the two conditions. 1. You are using the software in production and confirm you have sufficient licenses to cover your use under the International Program License Agreement (IPLA). 2. You are evaluating the software and agree to abide by the International License Agreement for Evaluation of Programs (ILAE). NOTE: Failure to comply with licenses for production use of software is a violation of [IBM International Program License Agreement](https://www.ibm.com/software/passportadvantage/programlicense.html). | `bool` | `false` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | Comma-separated list of names of the SSH key configured in your IBM Cloud account that is used to establish a connection to the Slurm management node. Ensure the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the instructions given [here](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys). | `string` | n/a | yes |
| <a name="input_storage_cluster_gui_password"></a> [storage\_cluster\_gui\_password](#input\_storage\_cluster\_gui\_password) | Password for storage cluster GUI | `string` | `""` | no |
| <a name="input_storage_cluster_gui_username"></a> [storage\_cluster\_gui\_username](#input\_storage\_cluster\_gui\_username) | GUI user to perform system management and monitoring tasks on storage cluster. | `string` | `""` | no |
| <a name="input_storage_node_instance_type"></a> [storage\_node\_instance\_type](#input\_storage\_node\_instance\_type) | Specify the VSI profile type name to be used to create the storage nodes for Slurm cluster. The storage nodes are the ones that would be used to create an NFS instance to manage the data for HPC workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) | `string` | `"bx2-2x8"` | no |
| <a name="input_volume_capacity"></a> [volume\_capacity](#input\_volume\_capacity) | Size in GB for the block storage that would be used to build the NFS instance and would be available as a mount on Slurm management node. Enter a value in the range 10 - 16000. | `number` | `100` | no |
| <a name="input_volume_iops"></a> [volume\_iops](#input\_volume\_iops) | Number to represent the IOPS(Input Output Per Second) configuration for block storage to be used for NFS instance (valid only for volume\_profile=custom, dependent on volume\_capacity). Enter a value in the range 100 - 48000. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles#custom) | `number` | `300` | no |
| <a name="input_volume_profile"></a> [volume\_profile](#input\_volume\_profile) | Name of the block storage volume type to be used for NFS instance. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles) | `string` | `"general-purpose"` | no |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | Creates the address prefix for the new VPC, when the vpc\_name variable is empty. Only a single address prefix is allowed. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design). | `list(string)` | <pre>[<br>  "10.241.0.0/18"<br>]</pre> | no |
| <a name="input_vpc_cluster_login_private_subnets_cidr_blocks"></a> [vpc\_cluster\_login\_private\_subnets\_cidr\_blocks](#input\_vpc\_cluster\_login\_private\_subnets\_cidr\_blocks) | The CIDR block that's required for the creation of the login cluster private subnet. Modify the CIDR block if it has already been reserved or used for other applications within the VPC or conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the login subnet. Since login subnet is used only for the creation of login virtual server instance provide a CIDR range of /28. | `list(string)` | <pre>[<br>  "10.241.4.0/28"<br>]</pre> | no |
| <a name="input_vpc_cluster_private_subnets_cidr_blocks"></a> [vpc\_cluster\_private\_subnets\_cidr\_blocks](#input\_vpc\_cluster\_private\_subnets\_cidr\_blocks) | The CIDR block that's required for the creation of the cluster private subnet. Modify the CIDR block if it has already been reserved or used for other applications within the VPC or conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the subnet. Make sure to select a CIDR block size that will accommodate the maximum number of management, storage, and both static worker nodes that you expect to have in your cluster.  For more information on CIDR block size selection, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc). | `list(string)` | <pre>[<br>  "10.241.0.0/22"<br>]</pre> | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc) | `string` | `""` | no |
| <a name="input_vpn_enabled"></a> [vpn\_enabled](#input\_vpn\_enabled) | Set to true to deploy a VPN gateway for VPC in the cluster (default: false). | `bool` | `false` | no |
| <a name="input_vpn_peer_address"></a> [vpn\_peer\_address](#input\_vpn\_peer\_address) | The peer public IP address to which the VPN will be connected. | `string` | `""` | no |
| <a name="input_vpn_peer_cidrs"></a> [vpn\_peer\_cidrs](#input\_vpn\_peer\_cidrs) | Comma separated list of peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected. | `string` | `""` | no |
| <a name="input_vpn_preshared_key"></a> [vpn\_preshared\_key](#input\_vpn\_preshared\_key) | The pre-shared key for the VPN. | `string` | `""` | no |
| <a name="input_worker_node_count"></a> [worker\_node\_count](#input\_worker\_node\_count) | This is the number of worker nodes that will be provisioned at the time the cluster is created. Enter a value in the range 3 - 200. | `number` | `3` | no |
| <a name="input_worker_node_instance_type"></a> [worker\_node\_instance\_type](#input\_worker\_node\_instance\_type) | Specify the virtual server instance or bare metal server profile type name to be used to create the worker nodes for the Slurm cluster based on worker\_node\_type. The worker nodes are the ones where the workload execution takes place and the choice should be made according to the characteristic of workloads. For more information, see [virtual server instance ](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) and [bare metal server profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-profile&interface=ui). Check `ibmcloud target -r {region_name}; ibmcloud is dedicated-host-profiles`. | `string` | `"bx2-4x16"` | no |
| <a name="input_worker_node_type"></a> [worker\_node\_type](#input\_worker\_node\_type) | The type of server that's used for the worker nodes: virtual server instance or bare metal server. If you choose vsi, the worker nodes are deployed on virtual server instances, or if you choose baremetal, the worker nodes are deployed on bare metal servers. | `string` | `"vsi"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | IBM Cloud zone name within the selected region where the Slurm cluster should be deployed. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nfs_ssh_command"></a> [nfs\_ssh\_command](#output\_nfs\_ssh\_command) | Storage Server SSH command |
| <a name="output_region_name"></a> [region\_name](#output\_region\_name) | n/a |
| <a name="output_scale_gui_web_link"></a> [scale\_gui\_web\_link](#output\_scale\_gui\_web\_link) | Scale GUI Web Link |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | SSH Command |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | n/a |
| <a name="output_vpn_config_info"></a> [vpn\_config\_info](#output\_vpn\_config\_info) | n/a |
