###################################################
# Copyright (C) IBM Corp. 2021 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

output "region_name" {
  value = data.ibm_is_region.region.name
}

output "vpc" {
  value = "Name:- ${data.ibm_is_vpc.vpc.name} | ID:- ${data.ibm_is_vpc.vpc.id}"
}

output "vpn_config_info" {
  value = var.vpn_enabled ? "IP: ${module.vpn[0].vpn_gateway_public_ip_address}, CIDR: ${module.subnet.ipv4_cidr_block}, UDP ports: 500, 4500": null
}

output "ssh_command" {
  description = "SSH Command"
  value = var.spectrum_scale_enabled ? "ssh -L 22443:localhost:443 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J root@${module.login_fip.floating_ip_address}  ubuntu@${module.management[0].primary_network_interface}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J root@${module.login_fip.floating_ip_address}  ubuntu@${module.management[0].primary_network_interface}"
}

output "scale_gui_web_link" {
  description = "Scale GUI Web Link"
  value = var.spectrum_scale_enabled ? "https://localhost:22443" : null
}

/**
*   NFS Server IP Address.
**/
output "nfs_ssh_command" {
  description = "Storage Server SSH command"
  value       = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J root@${module.login_fip.floating_ip_address} root@${module.nfs_storage[0].primary_network_interface}"
}
