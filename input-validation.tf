locals {
  // Since bare metal server creation is supported only in few specific zone, the below validation ensure to return an error message if any other zone value are provided from variable file
  validate_zone                  = var.worker_node_type == "baremetal" ? contains(["us-south-1", "us-south-3", "eu-de-1", "eu-de-2"], var.zone) : true
  zone_msg                       = "The solution supports bare metal server creation in only given availability zones i.e. us-south-1, us-south-3, eu-de-1, and eu-de-2. To deploy bare metal compute server provide any one of the supported availability zones."
  validate_persistent_region_chk = regex("^${local.zone_msg}$", (local.validate_zone ? local.zone_msg : ""))

  // Validate baremetal profile
  validate_bare_metal_profile = var.worker_node_type == "baremetal" ? can(regex("^[b|c|m|v]x[0-9]+d?-[a-z]+-[0-9]+x[0-9]+", var.worker_node_instance_type)) : true
  bare_metal_profile_error = "Specified profile must be a valid baremetal profile type. For example bx2d-metal-96x384 , vx2d-metal-96x1536. Refer worker_node_instance_type description for link."
  validate_bare_metal_profile_chk = regex("^${local.bare_metal_profile_error}$", (local.validate_bare_metal_profile ? local.bare_metal_profile_error : ""))

  // Validate spectrum_scale_enabled only with baremetal
  validate_spectrum_scale_enabled = var.spectrum_scale_enabled && var.worker_node_type == "vsi" ? false : true
  spectrum_scale_enabled_error_msg  = "The solution supports scale only with baremetal worker."
  validate_spectrum_scale_enabled_chk = regex("^${local.spectrum_scale_enabled_error_msg}$", (local.validate_spectrum_scale_enabled ? local.spectrum_scale_enabled_error_msg : ""))

  // Validate worker_node input count
  validate_worker_node_count = var.spectrum_scale_enabled ? (var.worker_node_count >= 3 && var.worker_node_count <= 200) : (var.worker_node_count >= 1 && var.worker_node_count <= 200)
  worker_node_count_error_msg = "When Scale storage is enabled, the input for \"worker_node_count\" must be between 3 and 200. If Scale is not enabled, the minimum number of workers can start from 1, with a maximum of 200."
  validate_worker_node_count_chk = regex("^${local.worker_node_count_error_msg}$", (local.validate_worker_node_count ? local.worker_node_count_error_msg : ""))

}