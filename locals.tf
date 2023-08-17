locals{

  management_image_mapping_entry_found = contains(keys(local.image_region_map), var.management_node_image_name)
  new_management_image_id              = local.management_image_mapping_entry_found ? lookup(lookup(local.image_region_map, var.management_node_image_name), local.region_name) : "Image not found with the given name"

  region_name = join("-", slice(split("-", var.zone), 0, 2))
  worker_image = "ibm-ubuntu-22-04-1-minimal-amd64-4"

  script_map = {
    "storage" = file("${path.module}/scripts/user_data_input_storage.tpl")
    "management"  = file("${path.module}/scripts/user_data_input_management.tpl")
    "worker"  = file("${path.module}/scripts/user_data_input_worker.tpl")
  }


  storage_template_file = lookup(local.script_map, "storage")
  management_template_file  = lookup(local.script_map, "management")
  worker_template_file  = lookup(local.script_map, "worker")

  tags                  = ["hpcc", var.cluster_prefix]
  hf_ncpus              = var.worker_node_type == "vsi" ? tonumber(data.ibm_is_instance_profile.worker[0].vcpu_count[0].value) : tonumber(data.ibm_is_bare_metal_server_profile.worker_bare_metal_server_profile[0].cpu_core_count[0].value) * 2
  hf_ncores             = local.hf_ncpus / 2
  memInMB               = var.worker_node_type == "vsi" ? tonumber(data.ibm_is_instance_profile.worker[0].memory[0].value) * 1000 : tonumber(data.ibm_is_bare_metal_server_profile.worker_bare_metal_server_profile[0].memory[0].value) * 1000
  cluster_name          = var.cluster_id

  // Use existing VPC if var.vpc_name is not empty
  vpc_name = var.vpc_name == "" ? module.vpc.*.name[0] : data.ibm_is_vpc.existing_vpc.*.name[0]

  # Get the list of public gateways from the existing vpc on provided var.zone input parameter. If no public gateway is found and in that zone our solution creates a new public gateway.
  existing_pgs = [for subnetsdetails in data.ibm_is_subnet.subnet_id: subnetsdetails.public_gateway if subnetsdetails.zone == var.zone && subnetsdetails.public_gateway != ""]
  existing_public_gateway_zone = var.vpc_name == "" ? "" : (length(local.existing_pgs) == 0 ? "" : element(local.existing_pgs ,0))

  peer_cidr_list = var.vpn_enabled ? split(",", var.vpn_peer_cidrs): []
  
  tf_data_path                =  "/tmp/.schematics/IBM/tf_data_path"

  // scale version installed on custom images.
  scale_version             = "5.1.7.1"

  vsi_login_private_key     = module.login_ssh_key.private_key
  vsi_login_temp_public_key = module.login_ssh_key.public_key
  
  // path where ansible playbook will be cloned from github public repo.
  scale_infra_repo_clone_path = "/tmp/.schematics/IBM/ibm-spectrumscale-cloud-deploy"
  scale_infra_repo_inventory_path = "/tmp/.schematics/IBM/ibm-spectrumscale-cloud-deploy/ibm-spectrum-scale-install-infra/"
  inventory_format            = "ini"
  create_scale_cluster        = false
  using_rest_api_remote_mount = true
   // cloud platform as IBMCloud, required for ansible playbook.
  cloud_platform              = "IBMCloud"
  gpfs_package_path           = "/mnt/data/scale/package_to_install"


  stock_image_name = "ibm-redhat-8-6-minimal-amd64-1"

  management_node_count = 1
  total_ipv4_address_count = pow(2, ceil(log(var.worker_node_count + local.management_node_count + 5 + 1 + 4, 2)))

  storage_ips = [
    for idx in range(1) :
    cidrhost(module.subnet.ipv4_cidr_block, idx + 4)
  ]

  management_ips = [
    for idx in range(local.management_node_count) :
    cidrhost(module.subnet.ipv4_cidr_block, idx + 4 + length(local.storage_ips))
  ]

  worker_ips =  [
    for idx in range(var.worker_node_count) :
    cidrhost(module.subnet.ipv4_cidr_block, idx + 4 + length(local.storage_ips) + length(local.management_ips))
  ]

  ssh_key_list = split(",", var.ssh_key_name)
  ssh_key_id_list = [
    for name in local.ssh_key_list:
    data.ibm_is_ssh_key.ssh_key[name].id
  ]   

  management_node_id = module.management[*].instance_id
  worker_instances_id = [for n in module.worker_bare_metal[*].bare_metal_server_id : n]
  management_node_private_ip = module.management[*].primary_network_interface
  worker_instances_private_ip = [for n in module.worker_bare_metal[*].primary_network_interface : n]
  instances_id = toset(flatten([local.management_node_id, local.worker_instances_id]))
  instances_primary_network_interface = toset(flatten([local.management_node_private_ip, local.worker_instances_private_ip]))

}