###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
/*
Data source process to fetch all the existing value from IBM cloud environment
*/

data "ibm_resource_group" "rg" {
  name = var.resource_group
}

data "ibm_is_region" "region" {
  name = local.region_name
}

data "ibm_is_zone" "zone" {
  name   = var.zone
  region = data.ibm_is_region.region.name
}

data "ibm_is_vpc" "existing_vpc" {
  // Lookup for this VPC resource only if var.vpc_name is not empty
  count = var.vpc_name != "" ? 1:0
  name  = var.vpc_name
}

data "ibm_is_vpc" "vpc" {
  name = local.vpc_name
  // Depends on creation of new VPC or look up of existing VPC based on value of var.vpc_name,
  depends_on = [module.vpc, data.ibm_is_vpc.existing_vpc]
}

data "ibm_is_vpc_address_prefixes" "existing_vpc" {
  vpc = data.ibm_is_vpc.vpc.id
}

data "ibm_is_image" "management_image" {
  name  = var.management_node_image_name
  count = local.management_image_mapping_entry_found ? 0 : 1
}

data "ibm_is_instance_profile" "login" {
  name = var.login_node_instance_type
}

data "ibm_is_instance_profile" "storage" {
  name = var.storage_node_instance_type
}

data "ibm_is_instance_profile" "management" {
  name = var.management_node_instance_type
}

data "ibm_is_instance_profile" "worker" {
  count = var.worker_node_type == "vsi" ? 1 : 0
  name = var.worker_node_instance_type
}

data "ibm_is_bare_metal_server_profile" "worker_bare_metal_server_profile" {
  count = var.worker_node_type == "baremetal" ? 1 : 0
  name = var.worker_node_instance_type
}

data "ibm_is_volume_profile" "nfs" {
  name = var.volume_profile
}

data "ibm_is_ssh_key" "ssh_key" {
  for_each = toset(split(",", var.ssh_key_name))
  name     = each.value
}

data "ibm_is_image" "stock_image" {
  name = local.stock_image_name
}

data "ibm_is_image" "worker_image" {
  name = local.worker_image
}

data "http" "fetch_myip"{
  url = "http://ipv4.icanhazip.com"
}

data "ibm_is_subnet" "subnet_id" {
  for_each   = var.vpc_name == "" ? [] : toset(data.ibm_is_vpc.vpc.subnets[*].id)
  identifier = each.value
}