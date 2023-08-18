###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# IBM Cloud Provider
# Docs are available here, https://cloud.ibm.com/docs/terraform?topic=terraform-tf-provider#store_credentials
# Download IBM Cloud Provider binary from release page. https://github.com/IBM-Cloud/terraform-provider-ibm/releases
# And copy it to $HOME/.terraform.d/plugins/terraform-provider-ibm_v1.55.0

/*
Infrastructure creation related steps
*/

// This module creates a new VPC resource only if var.vpc_name is empty i.e( If any VPC name is provided, that vpc will be considered for all resource creation)
module "vpc" {
  source       = "./resources/ibmcloud/network/vpc"
  count        = var.vpc_name == "" ? 1 : 0
  name         = "${var.cluster_prefix}-vpc"
  resource_group = data.ibm_resource_group.rg.id
  vpc_address_prefix_management = "manual"
  tags         = local.tags
}
// This module creates a vpc_address_prefix as we are now using custom CIDR range for VPC creation
module "vpc_address_prefix" {
  count        = var.vpc_name == "" ? 1 : 0
  source       = "./resources/ibmcloud/network/vpc_address_prefix"
  vpc_id       = data.ibm_is_vpc.vpc.id
  address_name = format("%s-addr", var.cluster_prefix)
  zones        = var.zone
  cidr_block   = var.vpc_cidr_block
}

module "public_gw" {
  source         = "./resources/ibmcloud/network/public_gw"
  count          = local.existing_public_gateway_zone != "" ? 0 : 1
  public_gw_name = "${var.cluster_prefix}-gateway"
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = data.ibm_is_zone.zone.name
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags
}

# This module is used to create subnet, which is used to create both login node. The subnet CIDR range is passed manually based on the user input from variable file
module "login_subnet" {
  source            = "./resources/ibmcloud/network/login_subnet"
  login_subnet_name = "${var.cluster_prefix}-login-subnet"
  vpc               = data.ibm_is_vpc.vpc.id
  zone              = data.ibm_is_zone.zone.name
  ipv4_cidr_block   = var.vpc_cluster_login_private_subnets_cidr_blocks[0]
  resource_group    = data.ibm_resource_group.rg.id
  tags              = local.tags
  depends_on        = [module.vpc_address_prefix]
}

# This module is used to create subnet, which is used to create both worker and storage node. The subnet CIDR range is passed manually based on the user input from variable file
module "subnet" {
  source            = "./resources/ibmcloud/network/subnet"
  subnet_name       = "${var.cluster_prefix}-subnet"
  vpc               = data.ibm_is_vpc.vpc.id
  zone              = data.ibm_is_zone.zone.name
  ipv4_cidr_block   = var.vpc_cluster_private_subnets_cidr_blocks[0]
  public_gateway    = local.existing_public_gateway_zone != "" ? local.existing_public_gateway_zone : module.public_gw[0].public_gateway_id
  resource_group    = data.ibm_resource_group.rg.id
  tags              = local.tags
  depends_on        = [module.vpc_address_prefix]
}

// The module is used to create a security group for only login nodes
module "login_sg" {
  source         = "./resources/ibmcloud/security/login_sg"
  sec_group_name = "${var.cluster_prefix}-login-sg"
  resource_group = data.ibm_resource_group.rg.id
  vpc            = data.ibm_is_vpc.vpc.id
  tags           = local.tags
}

module "login_inbound_security_rules" {
  source             = "./resources/ibmcloud/security/login_sg_inbound_rule"
  remote_allowed_ips = var.remote_allowed_ips
  group              = module.login_sg.sec_group_id
  depends_on         = [module.login_sg]
}

module "login_outbound_security_rule" {
  source    = "./resources/ibmcloud/security/login_sg_outbound_rule"
  group     = module.login_sg.sec_group_id
  remote    = module.sg.sg_id
}

// The module is used to create a security group for all the nodes (i.e.controller/controller-candidate/worker-vsi/worker-baremetal/storage).
module "sg" {
  source          = "./resources/ibmcloud/security/security_group"
  sec_group_name  = "${var.cluster_prefix}-sg"
  vpc             = data.ibm_is_vpc.vpc.id
  resource_group  = data.ibm_resource_group.rg.id
  tags            = local.tags
}

module "inbound_sg_rule" {
  source    = "./resources/ibmcloud/security/security_group_inbound_rule"
  group     = module.sg.sg_id
  remote    = module.login_sg.sec_group_id
}

module "inbound_sg_ingress_all_local_rule" {
  source    = "./resources/ibmcloud/security/security_group_ingress_all_local"
  group     = module.sg.sg_id
  remote    = module.sg.sg_id
}

module "outbound_sg_rule" {
  source     = "./resources/ibmcloud/security/security_group_outbound_rule"
  group      = module.sg.sg_id
}
// The module is used to fetch the IP address of the schematics container and update the IP on security group rule
module "schematics_sg_tcp_rule" {
  source            = "./resources/ibmcloud/security/security_tcp_rule"
  security_group_id = module.login_sg.sec_group_id
  sg_direction      = "inbound"
  remote_ip_addr    = tolist([chomp(data.http.fetch_myip.response_body)])
  depends_on = [module.login_sg]
}

module "nfs_volume" {
  source            = "./resources/ibmcloud/network/nfs_volume"
  nfs_name          = "${var.cluster_prefix}-vm-nfs-volume"
  profile           = data.ibm_is_volume_profile.nfs.name
  iops              = data.ibm_is_volume_profile.nfs.name == "custom" ? var.volume_iops : null
  capacity          = var.volume_capacity
  zone              = data.ibm_is_zone.zone.name
  resource_group    = data.ibm_resource_group.rg.id
  tags              = local.tags
}

module "nfs_storage" {
  source            = "./resources/ibmcloud/compute/vsi_nfs_storage_server"
  count             = 1
  vsi_name          = "${var.cluster_prefix}-storage"
  image             = data.ibm_is_image.stock_image.id
  profile           = data.ibm_is_instance_profile.storage.name
  vpc               = data.ibm_is_vpc.vpc.id
  zone              = data.ibm_is_zone.zone.name
  keys              = local.ssh_key_id_list
  resource_group    = data.ibm_resource_group.rg.id
  user_data         = "${data.template_file.storage_user_data.rendered} ${file("${path.module}/scripts/user_data_storage.sh")}"
  subnet_id         = module.subnet.subnet_id
  security_group    = [module.sg.sg_id]
  volumes           = [module.nfs_volume.nfs_volume_id]
  primary_ipv4_address = local.storage_ips[count.index]
  tags              = local.tags
  depends_on        = [
    module.inbound_sg_ingress_all_local_rule,
    module.outbound_sg_rule
  ]
}

module "login_ssh_key" {
  source       = "./resources/scale_common/generate_keys"
  invoke_count = var.spectrum_scale_enabled ? 1:0
  tf_data_path = format("%s", local.tf_data_path)
}

// The module is used to create the login/bastion node to access all other nodes in the cluster
module "login_vsi" {
  source          =  "./resources/ibmcloud/compute/vsi_login"
  vsi_name        = "${var.cluster_prefix}-login"
  image           = data.ibm_is_image.stock_image.id
  profile         = data.ibm_is_instance_profile.login.name
  vpc             = data.ibm_is_vpc.vpc.id
  zone            = data.ibm_is_zone.zone.name
  keys            = local.ssh_key_id_list
  user_data       = data.template_file.login_user_data.rendered
  resource_group  = data.ibm_resource_group.rg.id
  tags            = local.tags
  subnet_id       = module.login_subnet.login_subnet_id
  security_group  = [module.login_sg.sec_group_id]
  depends_on      = [module.login_ssh_key,module.login_inbound_security_rules,module.login_outbound_security_rule]
}

module "login_fip" {
  source            = "./resources/ibmcloud/network/floating_ip"
  floating_ip_name  = "${var.cluster_prefix}-login-fip"
  target_network_id = module.login_vsi.primary_network_interface
  resource_group    = data.ibm_resource_group.rg.id
  tags              = local.tags
}

module "vpn" {
  source         = "./resources/ibmcloud/network/vpn"
  count          = var.vpn_enabled ? 1: 0
  name           = "${var.cluster_prefix}-vpn"
  resource_group = data.ibm_resource_group.rg.id
  subnet         = module.login_subnet.login_subnet_id
  mode           = "policy"
  tags           = local.tags
}

module "vpn_connection" {
  source          = "./resources/ibmcloud/network/vpn_connection"
  count           = var.vpn_enabled ? 1: 0
  name            = "${var.cluster_prefix}-vpn-conn"
  vpn_gateway     = module.vpn[count.index].vpn_gateway_id
  vpn_peer_address = var.vpn_peer_address
  vpn_preshared_key = var.vpn_preshared_key
  admin_state_up  = true
  local_cidrs     = [module.login_subnet.ipv4_cidr_block]
  peer_cidrs      = local.peer_cidr_list
}

module "ingress_vpn" {
  source    = "./resources/ibmcloud/security/vpn_ingress_sg_rule"
  count     = length(local.peer_cidr_list)
  group     = module.login_sg.sec_group_id
  remote    = local.peer_cidr_list[count.index]
}


module "management" {
  source            = "./resources/ibmcloud/compute/vsi_management_server"
  count             = 1
  vsi_name          = "${var.cluster_prefix}-management"
  image             = local.management_image_mapping_entry_found ? local.new_management_image_id : data.ibm_is_image.management_image[0].id
  profile           = data.ibm_is_instance_profile.management.name
  vpc               = data.ibm_is_vpc.vpc.id
  zone              = data.ibm_is_zone.zone.name
  keys              = local.ssh_key_id_list
  resource_group    = data.ibm_resource_group.rg.id
  user_data         = "${data.template_file.management_user_data.rendered} ${file("${path.module}/scripts/user_data_management.sh")}"
  subnet_id         = module.subnet.subnet_id
  security_group    = [module.sg.sg_id]
  primary_ipv4_address = local.management_ips[count.index]
  tags              = local.tags
  depends_on        = [
    module.inbound_sg_ingress_all_local_rule,
    module.outbound_sg_rule
  ]
}

module "worker_vsi" {
  source           = "./resources/ibmcloud/compute/vsi_worker_server"
  count            = var.worker_node_type == "vsi" ? 1 : 0
  total_vsis      =  var.worker_node_count
  cluster_prefix  = var.cluster_prefix
  image            = data.ibm_is_image.worker_image.id
  profile          = data.ibm_is_instance_profile.worker[0].name
  vpc              = data.ibm_is_vpc.vpc.id
  zone            = [data.ibm_is_zone.zone.name]
  keys             = local.ssh_key_id_list
  resource_group   = data.ibm_resource_group.rg.id
  user_data        = "${data.template_file.worker_user_data.rendered} ${file("${path.module}/scripts/user_data_worker.sh")}"
  subnet          = [module.subnet.subnet_id]
  security_group   = [module.sg.sg_id]
  primary_ipv4_address = local.worker_ips
  tags             = local.tags
  depends_on = [module.nfs_storage,
    module.management,
    module.inbound_sg_ingress_all_local_rule,
    module.sg]
  }

module "worker_bare_metal" {
  source          = "./resources/ibmcloud/compute/bare_metal_worker_server"
  count           = var.worker_node_type == "baremetal" ? 1 : 0
  cluster_prefix  = var.cluster_prefix
  profile         = data.ibm_is_bare_metal_server_profile.worker_bare_metal_server_profile[0].name
  image           = data.ibm_is_image.worker_image.id
  zone            = [data.ibm_is_zone.zone.name]
  keys            = local.ssh_key_id_list
  vpc             = data.ibm_is_vpc.vpc.id
  resource_group  = data.ibm_resource_group.rg.id
  subnet          = [module.subnet.subnet_id]
  security_group  = [module.sg.sg_id]
  primary_ipv4_address = local.worker_ips
  user_data       = "${data.template_file.worker_user_data.rendered} ${file("${path.module}/scripts/user_data_worker.sh")}"
  tags            = local.tags
  total_vsis      =  var.worker_node_count
  depends_on      = [module.nfs_storage, module.management,module.sg, module.inbound_sg_ingress_all_local_rule, module.inbound_sg_rule, module.outbound_sg_rule]
}

// This null_resource is required to upgrade the jinja package version on schematics, since the ansible playbook that we run requires the latest version of jinja
resource "null_resource" "upgrade_jinja" {
  count = var.spectrum_scale_enabled && var.worker_node_type == "baremetal" ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "pip install jinja2 --upgrade"
  }
}


// This module is used to clone ansible repo for scale.
module "prepare_spectrum_scale_ansible_repo" {
  count      = var.spectrum_scale_enabled && var.worker_node_type == "baremetal" ? 1 : 0
  source     = "./resources/scale_common/git_utils"
  branch     = "master"
  tag        = null
  clone_path = local.scale_infra_repo_clone_path
}

// Wait for nodes to get in running state.
module "worker_nodes_wait" { 
  count         = 1 
  source        = "./resources/scale_common/wait"
  wait_duration = var.TF_WAIT_DURATION
  depends_on    = [module.worker_bare_metal,module.worker_vsi]
}

// This module creates the json file with the required configuration and will be used for the creation of inventory file for scale storage cluster
module "write_storage_cluster_inventory" {
  count                                            = var.spectrum_scale_enabled && var.worker_node_type == "baremetal" ? 1 : 0
  source                                           = "./resources/scale_common/write_inventory"
  inventory_path                                   = format("%s/storage_cluster_inventory.json", local.scale_infra_repo_clone_path)
  cloud_platform                                   = jsonencode("IBMCloud")
  resource_prefix                                  = jsonencode(format("%s", var.cluster_prefix))
  vpc_region                                       = jsonencode(local.region_name)
  vpc_availability_zones                           = jsonencode([var.zone])
  scale_version                                    = jsonencode(local.scale_version)
  filesystem_block_size                            = jsonencode(var.scale_filesystem_block_size)
  compute_cluster_filesystem_mountpoint            = jsonencode("None")
  bastion_instance_id                              = jsonencode(module.login_vsi.login_id)
  bastion_instance_public_ip                       = jsonencode(module.login_fip.floating_ip_address)
  bastion_user                                     = jsonencode("root")
  compute_cluster_instance_ids                     = jsonencode([])
  compute_cluster_instance_private_ips             = jsonencode([])
  compute_cluster_instance_private_dns_ip_map      = jsonencode({})
  storage_cluster_filesystem_mountpoint            = jsonencode(var.scale_storage_cluster_filesystem_mountpoint)
  storage_cluster_instance_ids                     = jsonencode(local.instances_id) 
  storage_cluster_instance_private_ips             = jsonencode(local.instances_primary_network_interface)
  storage_cluster_with_data_volume_mapping         = jsonencode(one(module.worker_bare_metal[*].instance_ips_with_vol_mapping))
  storage_cluster_instance_private_dns_ip_map      = jsonencode([])
  storage_cluster_desc_instance_ids                = jsonencode([])
  storage_cluster_desc_instance_private_ips        = jsonencode([])
  storage_cluster_desc_data_volume_mapping         = jsonencode({})
  storage_cluster_desc_instance_private_dns_ip_map = jsonencode({})
  depends_on                                       = [module.login_ssh_key, module.prepare_spectrum_scale_ansible_repo, module.worker_nodes_wait]
}


// This module creates the inventory file for the storage ansible playbook to be created
module "storage_cluster_configuration" {
  count                        = var.spectrum_scale_enabled && var.worker_node_type == "baremetal" ? 1 : 0
  source                       = "./resources/scale_common/storage_configuration"
  turn_on                      = var.worker_node_count > 0  ? true : false
  clone_complete               = var.spectrum_scale_enabled ? module.prepare_spectrum_scale_ansible_repo[0].clone_complete : false
  write_inventory_complete     = module.write_storage_cluster_inventory[0].write_inventory_complete
  inventory_format             = local.inventory_format
  create_scale_cluster         = local.create_scale_cluster
  clone_path                   = local.scale_infra_repo_clone_path
  inventory_path               = format("%s/storage_cluster_inventory.json", local.scale_infra_repo_clone_path)
  using_packer_image           = false
  using_direct_connection      = false
  using_rest_initialization    = local.using_rest_api_remote_mount
  storage_cluster_gui_username = var.storage_cluster_gui_username
  storage_cluster_gui_password = var.storage_cluster_gui_password
  memory_size                  = data.ibm_is_bare_metal_server_profile.worker_bare_metal_server_profile[0].memory[0].value * 1000
  max_pagepool_gb              = 32
  vcpu_count                   = data.ibm_is_bare_metal_server_profile.worker_bare_metal_server_profile[0].cpu_socket_count[0].value * data.ibm_is_bare_metal_server_profile.worker_bare_metal_server_profile[0].cpu_core_count[0].value 
  bastion_user                 = jsonencode("root")
  bastion_instance_public_ip   = module.login_fip.floating_ip_address
  bastion_ssh_private_key      = var.spectrum_scale_enabled ? module.login_ssh_key.private_key_path : ""
  meta_private_key             = module.login_ssh_key.private_key
  scale_version                = local.scale_version
  spectrumscale_rpms_path      = local.gpfs_package_path
  disk_type                    = "locally-attached"
  max_data_replicas            = 3
  max_metadata_replicas        = 3
  default_metadata_replicas    = 3
  default_data_replicas        = 2
  max_mbps                     = data.ibm_is_bare_metal_server_profile.worker_bare_metal_server_profile[0].bandwidth[0].value * 0.25
  depends_on                   = [ module.login_ssh_key, module.prepare_spectrum_scale_ansible_repo, module.worker_nodes_wait]
}

// This module is used to configure the end-end deployment for storage cluster through Ansible
module "invoke_storage_playbook" {
  count                            = var.spectrum_scale_enabled && var.worker_node_type == "baremetal" ? 1 : 0
  source                           = "./resources/scale_common/ansible_playbook"
  bastion_public_ip                = module.login_fip.floating_ip_address
  bastion_ssh_private_key          = var.spectrum_scale_enabled ? module.login_ssh_key.private_key_path : ""
  host                             = chomp(data.http.fetch_myip.response_body)
  scale_version                    = local.scale_version
  cloud_platform                   = local.cloud_platform
  ansible_python_interpreter       = "/usr/bin/python3"
  inventory_path                   = format("%s/storage_inventory.ini", local.scale_infra_repo_inventory_path)
  playbook_path                    = format("%s/storage_cloud_playbook.yaml", local.scale_infra_repo_inventory_path)
  gpfs_package_path                = local.gpfs_package_path
  bastion_user                     = "root"
  depends_on                       = [module.login_ssh_key, module.worker_nodes_wait, module.storage_cluster_configuration, null_resource.upgrade_jinja]
}

