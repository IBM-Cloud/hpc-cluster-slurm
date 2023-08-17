data "template_file" "storage_user_data" {
  template = local.storage_template_file
  vars = {
    rc_cidr_block       = module.subnet.ipv4_cidr_block
    cluster_prefix      = var.cluster_prefix
    spectrum_scale      = var.spectrum_scale_enabled
  }
}

data "template_file" "management_user_data" {
  template = local.management_template_file
  vars = {
    vpc_apikey_value              = var.api_key
    resource_records_apikey_value = var.api_key
    image_id                       = local.management_image_mapping_entry_found ? local.new_management_image_id : data.ibm_is_image.management_image[0].id
    subnet_id                     = module.subnet.subnet_id
    security_group_id             = module.sg.sg_id
    sshkey_id                     = data.ibm_is_ssh_key.ssh_key[local.ssh_key_list[0]].id
    region_name                   = data.ibm_is_region.region.name
    zone_name                     = data.ibm_is_zone.zone.name
    vpc_id                        = data.ibm_is_vpc.vpc.id
    rc_cidr_block                 = module.subnet.ipv4_cidr_block
    hf_profile                    = var.worker_node_type == "vsi" ? data.ibm_is_instance_profile.worker[0].name : data.ibm_is_bare_metal_server_profile.worker_bare_metal_server_profile[0].name
    hf_ncores                     = local.hf_ncores
    hf_ncpus                      = local.hf_ncpus
    hf_memInMB                    = local.memInMB
    management_ips                = join(" ", local.management_ips)
    worker_ips                    = join(" ", local.worker_ips)
    storage_ips                   = join(" ", local.storage_ips)
    cluster_id                    = local.cluster_name
    cluster_prefix                = var.cluster_prefix
    hyperthreading                = true
    spectrum_scale                = var.spectrum_scale_enabled
    worker_node_type              = var.worker_node_type
    worker_node_count             = var.worker_node_count
    vsi_login_temp_public_key = local.vsi_login_temp_public_key
  }
}

data "template_file" "worker_user_data" {
  template = local.worker_template_file
  vars = {
    rc_cidr_block      = module.subnet.ipv4_cidr_block
    management_ips     = join(" ", local.management_ips)
    storage_ips        = join(" ", local.storage_ips)
    cluster_id         = local.cluster_name
    cluster_prefix     = var.cluster_prefix
    hyperthreading     = true
    worker_node_type   = var.worker_node_type
    spectrum_scale     = var.spectrum_scale_enabled
  }
}

data "template_file" "login_user_data" {
  template = <<EOF
#!/usr/bin/env bash
echo "${local.vsi_login_temp_public_key}" >> ~/.ssh/authorized_keys
EOF
}

