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
variable "cluster_prefix" {}
variable "image" {}
variable "profile" {}
variable "vpc" {}
variable "zone" {}
variable "keys" {}
variable "user_data" {}
variable "resource_group" {}
variable "tags" {}
variable "subnet" {}
variable "security_group" {}
variable "primary_ipv4_address" {}

resource "ibm_is_instance" "worker" {
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
  name           = "${var.cluster_prefix}-worker-${format("%03d", each.value.sequence_string)}"
  image          = var.image
  profile        = var.profile
  vpc            = var.vpc
  zone           = each.value.zone
  keys           = var.keys
  resource_group = var.resource_group
  user_data      = var.user_data
  tags = var.tags
  primary_network_interface {
    name                 = "eth0"
    subnet               = each.value.subnet_id
    security_groups      = var.security_group
    primary_ip {
      address            = each.value.worker_ips
    }
  }
}

output "vsi_server_id" {
  value      = try(toset([for instance_details in ibm_is_instance.worker : instance_details.id]), [])
  depends_on = [ibm_is_instance.worker]
}

output "vsi_primary_network_interface" {
  value      = try(toset([for instance_details in ibm_is_instance.worker : instance_details.primary_network_interface[0]["primary_ip"][0]["address"]]), [])
  depends_on = [ibm_is_instance.worker]
}