/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/4-hybrid/terraform/outputs.tf ---

output "cloud_wan" {
  description = "AWS Cloud WAN resources."
  value = {
    global_network = awscc_networkmanager_global_network.global_network.global_network_id
    core_network   = awscc_networkmanager_core_network.core_network.core_network_id
  }
}

output "spoke_vpcs" {
  description = "Spoke VPCs created, by Region."
  value = {
    (var.aws_regions.nvirginia) = { for k, v in module.nvirginia_spoke_vpcs : k => v.vpc_attributes.id }
    (var.aws_regions.ireland)   = { for k, v in module.ireland_spoke_vpcs : k => v.vpc_attributes.id }
  }
}

output "hybrid_attachments" {
  description = "Hybrid attachments created. A null entry is a sub-type that was not enabled."
  value = {
    site_to_site_vpn       = try(aws_networkmanager_site_to_site_vpn_attachment.vpn_attachment[0].id, null)
    direct_connect_gateway = try(aws_networkmanager_dx_gateway_attachment.dxgw_attachment[0].id, null)
    connect                = try(aws_networkmanager_connect_attachment.connect_attachment[0].id, null)
  }
}

output "prefix_list_aliases" {
  description = "Prefix list aliases a route-summarization policy can match with `prefix-in-prefix-list`."
  value = var.create_prefix_lists ? {
    (var.aws_regions.nvirginia) = "nvirginiaipv4routes"
    (var.aws_regions.ireland)   = "irelandipv4routes"
  } : {}
}

output "policy_document" {
  description = "Path to the Cloud WAN network policy document deployed."
  value       = var.policy_document
}
