###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

### About VPC resources
variable "ssh_key_name" {
  type        = string
  description = "Comma-separated list of names of the SSH key configured in your IBM Cloud account that is used to establish a connection to the Slurm management node. Ensure the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by using the instructions given [here](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
}

variable "api_key" {
  type        = string
  description = "This is the API key for IBM Cloud account in which the Slurm cluster needs to be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-userapikey)"
  sensitive   = true
  validation {
    condition     = var.api_key != ""
    error_message = "API key for IBM Cloud must be set."
  }
}

variable "vpc_name" {
  type        = string
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
  default     = ""
}

variable "vpc_cidr_block" {
  type        = list(string)
  default     = ["10.241.0.0/18"]
  description = "Creates the address prefix for the new VPC, when the vpc_name variable is empty. Only a single address prefix is allowed. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design)."
  validation {
    condition     = length(var.vpc_cidr_block) <= 1
    error_message = "Our Automation supports only a single AZ to deploy resources. Provide one CIDR range of address prefix."
  }
}

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = list(string)
  default     = ["10.241.0.0/22"]
  description = "The CIDR block that's required for the creation of the cluster private subnet. Modify the CIDR block if it has already been reserved or used for other applications within the VPC or conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the subnet. Make sure to select a CIDR block size that will accommodate the maximum number of management, storage, and both static worker nodes that you expect to have in your cluster.  For more information on CIDR block size selection, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
  validation {
    condition     = length(var.vpc_cluster_private_subnets_cidr_blocks) <= 1
    error_message = "Our Solution supports only a single AZ to deploy resources. Provide one CIDR range of subnet creation."
  }
}

variable "vpc_cluster_login_private_subnets_cidr_blocks" {
  type        = list(string)
  default     = ["10.241.4.0/28"]
  description = "The CIDR block that's required for the creation of the login cluster private subnet. Modify the CIDR block if it has already been reserved or used for other applications within the VPC or conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the login subnet. Since login subnet is used only for the creation of login virtual server instance provide a CIDR range of /28."
  validation {
    condition     = length(var.vpc_cluster_login_private_subnets_cidr_blocks) <= 1
    error_message = "Our Automation supports only a single AZ to deploy resources. Provide one CIDR range of subnet creation."
  }
  validation {
    condition     =  tonumber(regex("/(\\d+)", join(",",var.vpc_cluster_login_private_subnets_cidr_blocks))[0]) <= 28
    error_message = "Our solution uses this subnet to create only a login virtual server instance, providing a bigger CIDR size will waste the usage of available IP. A CIDR range of /28 is sufficient for the creation of login subnet."
  }
}

variable "resource_group" {
  type        = string
  default     = "Default"
  description = "Resource group name from your IBM Cloud account where the VPC resources should be deployed. [Learn more](https://cloud.ibm.com/docs/account?topic=account-rgs)"
}

variable "cluster_prefix" {
  type        = string
  default     = "hpcc-slurm"
  description = "Prefix that would be used to name Slurm cluster and IBM Cloud resources provisioned to build the Slurm cluster instance. You cannot create more than one instance of Slurm Cluster with same name, make sure the name is unique. Enter a prefix name, such as my-hpcc"
}

variable "cluster_id" {
  type        = string
  default     = "SlurmCluster"
  description = "ID of the cluster used by Slurm for configuration of resources. This must be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.). Other special characters and spaces are not allowed. Do not use the name of any host or user as the name of your cluster. You cannot change it after installation."
  validation {
    condition = 0 < length(var.cluster_id) && length(var.cluster_id) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_id))
    error_message = "The ID must be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.). Other special characters and spaces are not allowed."
  }
}

variable "zone" {
  type        = string
  description = "IBM Cloud zone name within the selected region where the Slurm cluster should be deployed. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)"
}

variable "management_node_image_name" {
  type        = string
  default     = "hpcc-slurm-management-v1-03may23"
  description = "Name of the image that you want to use to create virtual server instances in your IBM Cloud account to deploy as worker nodes in the Slurm cluster. By default, the automation uses a stock operating system image. If you would like to include your application-specific binary files, follow the instructions in [Planning for custom images](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Slurm cluster through this offering. Note that use of your own custom image may require changes to the cloud-init scripts, and potentially other files, in the Terraform code repository if different post-provisioning actions or variables need to be implemented."
}

variable "management_node_instance_type" {
  type        = string
  default     = "cx2-16x32"
  description = "Specify the VSI profile type name to be used to create the management node for Slurm cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.management_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "login_node_instance_type" {
  type        = string
  default     = "cx2-16x32"
  description = "Specify the VSI profile type name to be used to create the login node for Slurm cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.login_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "storage_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Specify the VSI profile type name to be used to create the storage nodes for Slurm cluster. The storage nodes are the ones that would be used to create an NFS instance to manage the data for HPC workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.storage_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "worker_node_type" {
  description = "The type of server that's used for the worker nodes: virtual server instance or bare metal server. If you choose vsi, the worker nodes are deployed on virtual server instances, or if you choose baremetal, the worker nodes are deployed on bare metal servers."
  type    = string
  default = "vsi"
  validation {
    condition = can(regex("^(vsi|baremetal)$", lower(var.worker_node_type)))
    error_message = "Our automation support only worker node type as vsi and baremetal, provide any one of the value."
  }
}

variable "worker_node_instance_type" {
  type        = string
  default     = "bx2-4x16"
  description = "Specify the virtual server instance or bare metal server profile type name to be used to create the worker nodes for the Slurm cluster based on worker_node_type. The worker nodes are the ones where the workload execution takes place and the choice should be made according to the characteristic of workloads. For more information, see [virtual server instance ](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles) and [bare metal server profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-bare-metal-servers-profile&interface=ui). Check `ibmcloud target -r {region_name}; ibmcloud is dedicated-host-profiles`."
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.worker_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "worker_node_count" {
  type        = number
  default     = 1
  description = "This is the number of worker nodes that will be provisioned at the time the cluster is created."
}

variable "volume_capacity" {
  type        = number
  default     = 100
  description = "Size in GB for the block storage that would be used to build the NFS instance and would be available as a mount on Slurm management node. Enter a value in the range 10 - 16000."
  validation {
    condition     = 10 <= var.volume_capacity && var.volume_capacity <= 16000
    error_message = "Input \"volume_capacity\" must be >= 10 and <= 16000."
  }
}

variable "volume_profile" {
  type        = string
  default     = "general-purpose"
  description = "Name of the block storage volume type to be used for NFS instance. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles)"
}

variable "volume_iops" {
  type        = number
  default     = 300
  description = "Number to represent the IOPS(Input Output Per Second) configuration for block storage to be used for NFS instance (valid only for volume_profile=custom, dependent on volume_capacity). Enter a value in the range 100 - 48000. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles#custom)"
  validation {
    condition     = 100 <= var.volume_iops && var.volume_iops <= 48000
    error_message = "Input \"volume_iops\" must be >= 100 and <= 48000."
  }
}

variable "remote_allowed_ips" {
	type        = list(string)
	description = "Comma-separated list of IP addresses that can access the Slurm instance through an SSH. For security purposes, provide the public IP addresses assigned to the devices that are authorized to establish SSH (for example, [\"169.45.117.34\"]). To fetch the IP address of the device, use [https://ipv4.icanhazip.com/](https://ipv4.icanhazip.com/)."
	validation {
    condition     = alltrue([
            for o in var.remote_allowed_ips : !contains(["0.0.0.0/0", "0.0.0.0"], o)
            ])
    error_message = "For the purpose of security provide the public IP address(es) assigned to the device(s) authorized to establish SSH connections. Use https://ipv4.icanhazip.com/ to fetch the ip address of the device."
  }
  validation {
	  condition = alltrue([
		for a in var.remote_allowed_ips : can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",a))
	  ])
	  error_message = "Provided IP address format is not valid. Check if Ip address format has comma instead of dot and there should be double quotes between each IP address range if using multiple ip ranges. For multiple IP address use format [\"169.45.117.34\",\"128.122.144.145\"]."
	}
}

variable "spectrum_scale_enabled"{
  type = bool
  default = false
  description = "Setting this to 'true' will enable Spectrum Scale integration with the cluster. Otherwise, Spectrum Scale integration will be disabled (default). By entering 'true' for the property you have also agreed to one of the two conditions. 1. You are using the software in production and confirm you have sufficient licenses to cover your use under the International Program License Agreement (IPLA). 2. You are evaluating the software and agree to abide by the International License Agreement for Evaluation of Programs (ILAE). NOTE: Failure to comply with licenses for production use of software is a violation of [IBM International Program License Agreement](https://www.ibm.com/software/passportadvantage/programlicense.html)."
}

variable "TF_WAIT_DURATION" {
  type = string
  default = "600s"
  description = "wait duration time set for the storage and worker node to complete the entire setup"
}

variable "storage_cluster_gui_username" {
  type        = string
  default     = ""
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on storage cluster."
}

variable "storage_cluster_gui_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for storage cluster GUI"
}

variable "scale_storage_cluster_filesystem_mountpoint" {
  type        = string
  default     = "/gpfs/fs1"
  description = "Spectrum Scale storage cluster (owningCluster) file system mount point. The owningCluster is the cluster that owns and serves the file system to be mounted.  For more information, see [Mounting a remote GPFS file system](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=system-mounting-remote-gpfs-file)."

  validation {
    condition     = can(regex("^\\/[a-z0-9A-Z-_]+\\/[a-z0-9A-Z-_]+$", var.scale_storage_cluster_filesystem_mountpoint))
    error_message = "Specified value for \"storage_cluster_filesystem_mountpoint\" is not valid (valid: /gpfs/fs1)."
  }
}

variable "scale_filesystem_block_size" {
  type        = string
  default     = "4M"
  description = "File system [block size](https://www.ibm.com/docs/en/spectrum-scale/5.1.5?topic=considerations-block-size). Spectrum Scale supported block sizes (in bytes) include: 256K, 512K, 1M, 2M, 4M, 8M, 16M."

  validation {
    condition     = can(regex("^256K$|^512K$|^1M$|^2M$|^4M$|^8M$|^16M$", var.scale_filesystem_block_size))
    error_message = "Specified block size must be a valid IBM Spectrum Scale supported block sizes (256K, 512K, 1M, 2M, 4M, 8M, 16M)."
  }
}

variable "vpn_enabled" {
  type = bool
  default = false
  description = "Set to true to deploy a VPN gateway for VPC in the cluster (default: false)."
}

variable "vpn_peer_cidrs" {
  type = string
  default = ""
  description = "Comma separated list of peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected."
}

variable "vpn_peer_address" {
  type = string
  default = ""
  description = "The peer public IP address to which the VPN will be connected."
}

variable "vpn_preshared_key" {
  type = string
  default = ""
  description = "The pre-shared key for the VPN."
}