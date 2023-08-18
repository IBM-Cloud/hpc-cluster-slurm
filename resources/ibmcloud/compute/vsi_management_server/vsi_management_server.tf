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

variable "vsi_name" {}
variable "image" {}
variable "profile" {}
variable "vpc" {}
variable "zone" {}
variable "keys" {}
variable "user_data" {}
variable "resource_group" {}
variable "tags" {}
variable "subnet_id" {}
variable "security_group" {}
variable "primary_ipv4_address" {}


resource "ibm_is_instance" "management" {
  name           = var.vsi_name
  image          = var.image
  profile        = var.profile
  vpc            = var.vpc
  zone           = var.zone
  keys           = var.keys
  resource_group = var.resource_group
  user_data      = var.user_data

  tags = var.tags
  primary_network_interface {
    name                 = "eth0"
    subnet               = var.subnet_id
    security_groups      = var.security_group
    primary_ip {
      address            = var.primary_ipv4_address
    }
  }
}

locals {
  instance = [ {
      name = var.vsi_name
      primary_network_interface = var.primary_ipv4_address
    }
  ]
}

output "name" {
  value = ibm_is_instance.management.name
}

output "instance_id" {
  value = ibm_is_instance.management.id
}

output "primary_network_interface" {
  value = ibm_is_instance.management.primary_network_interface[0].primary_ip.0.address
}
