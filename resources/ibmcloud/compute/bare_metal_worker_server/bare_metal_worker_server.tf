###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "total_vsis" {}
variable "profile" {}
variable "image" {}
variable "zone" {}
variable "keys" {}
variable "tags" {}
variable "vpc" {}
variable "resource_group" {}
variable "user_data" {}
variable "subnet" {}
variable "security_group" {}
variable "cluster_prefix" {}
variable "primary_ipv4_address" {}


data "ibm_is_bare_metal_server_profile" "itself" {
  name = var.profile
}

resource "ibm_is_bare_metal_server" "itself" {
  for_each = {
    # This assigns a subnet-id to each of the instance
    # iteration.
    for idx, count_number in range(1, var.total_vsis + 1) : idx => {
      sequence_string = tostring(count_number)
      subnet_id       = element(var.subnet, idx)
      zone            = element(var.zone, idx)
      worker_ips      = element(var.primary_ipv4_address, idx)
    }
  }
  profile = var.profile
  name    = "${var.cluster_prefix}-worker-${format("%03d", each.value.sequence_string)}"
  image   = var.image
  zone    = each.value.zone
  keys    = var.keys
  tags    = var.tags
  primary_network_interface {
    subnet          = each.value.subnet_id
    security_groups = var.security_group
    primary_ip {
      address            = each.value.worker_ips
    }
  }
  vpc            = var.vpc
  resource_group = var.resource_group
  user_data      = var.user_data
  timeouts {
    create = "90m"
  }
}

output "bare_metal_server_id" {
  value      = try(toset([for instance_details in ibm_is_bare_metal_server.itself : instance_details.id]), [])
  depends_on = [ibm_is_bare_metal_server.itself]

}

output "primary_network_interface" {
  value      = try(toset([for instance_details in ibm_is_bare_metal_server.itself : instance_details.primary_network_interface[0]["primary_ip"][0]["address"]]), [])
  depends_on = [ibm_is_bare_metal_server.itself]
}

output "instance_ips_with_vol_mapping" {
  value = try({ for instance_details in ibm_is_bare_metal_server.itself : instance_details.primary_network_interface[0]["primary_ip"][0]["address"] =>
  data.ibm_is_bare_metal_server_profile.itself.disks[1].quantity[0].value == 8 ? ["/dev/nvme0n1", "/dev/nvme1n1", "/dev/nvme2n1", "/dev/nvme3n1", "/dev/nvme4n1", "/dev/nvme5n1", "/dev/nvme6n1", "/dev/nvme7n1"] : ["/dev/nvme0n1", "/dev/nvme1n1", "/dev/nvme2n1", "/dev/nvme3n1", "/dev/nvme4n1", "/dev/nvme5n1", "/dev/nvme6n1", "/dev/nvme7n1", "/dev/nvme8n1", "/dev/nvme9n1", "/dev/nvme10n1", "/dev/nvme11n1", "/dev/nvme12n1", "/dev/nvme13n1", "/dev/nvme14n1", "/dev/nvme15n1"] }, {})
  depends_on = [ibm_is_bare_metal_server.itself]
}