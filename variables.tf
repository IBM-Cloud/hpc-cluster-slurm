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

variable "slurm-version" {
  type = string
  default = ""
  description = "The explicit version tag for the slurm-wlm package. Leave empty for latest package on distro version. e.g For Jammy, see https://packages.ubuntu.com/search?keywords=slurm-wlm&searchon=names&suite=jammy&section=all"
}

variable "zone" {
  type        = string
  description = "IBM Cloud zone name within the selected region where the Slurm cluster should be deployed. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)"
}

variable "image_name" {
  type        = string
  default     = "ibm-ubuntu-22-04-3-minimal-amd64-2"
  description = "Name of the image that you want to use to create virtual server instances in your IBM Cloud account to deploy as worker nodes in the Slurm cluster. By default, the automation uses a stock operating system image. If you would like to include your application-specific binary files, follow the instructions in [Planning for custom images](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the Slurm cluster through this offering. Note that use of your own custom image may require changes to the cloud-init scripts, and potentially other files, in the Terraform code repository if different post-provisioning actions or variables need to be implemented."
}

variable "management_node_instance_type" {
  type        = string
  default     = "bx2-4x16"
  description = "Specify the VSI profile type name to be used to create the management node for Slurm cluster. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.management_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "worker_node_instance_type" {
  type        = string
  default     = "bx2-4x16"
  description = "Specify the VSI profile type name to be used to create the worker nodes for Slurm cluster. The worker nodes are the ones where the workload execution takes place and choice should be made according to the characteristic of workloads. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)"
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.worker_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "login_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
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

variable "worker_node_count" {
  type        = number
  default     = 1
  description = "This is the number of worker nodes that will be provisioned at the time the cluster is created. Enter a value in the range 1 - 500."
  validation {
    condition     = 1 <= var.worker_node_count && var.worker_node_count <= 500
    error_message = "Input \"worker_node_count\" must be >= 1 and <= 500."
  }
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

variable "volume_iops" {
  type        = number
  default     = 300
  description = "Number to represent the IOPS(Input Output Per Second) configuration for block storage to be used for NFS instance (valid only for volume_profile=custom, dependent on volume_capacity). Enter a value in the range 100 - 48000. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles#custom)"
  validation {
    condition     = 100 <= var.volume_iops && var.volume_iops <= 48000
    error_message = "Input \"volume_iops\" must be >= 100 and <= 48000."
  }
}

variable "management_node_count" {
  type        = number
  default     = 1
  description = "This is the total number of management nodes. Enter a value in the range 1 - 2."
  validation {
    condition     = 1 <= var.management_node_count && var.management_node_count <= 2
    error_message = "Input \"management_node_count\" must be >= 1 and <= 2."  
  }
}

variable "ssh_allowed_ips" {
  #type        = list(string)
  #default     = ["0.0.0.0/0"]
  #description = "Allowed a list of IP or CIDR for public SSH. All addresses are allowed with default."
  type        = string
  default     = "0.0.0.0/0"
  description = "Comma separated list of IP addresses that can access the Slurm instance through SSH interface. The default value allows any IP address to access the cluster."
}

variable "volume_profile" {
  type        = string
  default     = "general-purpose"
  description = "Name of the block storage volume type to be used for NFS instance. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-profiles)"
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



