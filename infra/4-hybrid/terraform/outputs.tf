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
  description = "Spoke VPC created in each Region."
  value = {
    (var.aws_regions.nvirginia) = module.nvirginia_spoke_vpc.vpc_attributes.id
    (var.aws_regions.ireland)   = module.ireland_spoke_vpc.vpc_attributes.id
  }
}

output "hybrid_attachments" {
  description = "Hybrid attachments created. A null entry is a sub-type that was not enabled."
  value = {
    site_to_site_vpn       = try(aws_networkmanager_site_to_site_vpn_attachment.vpn_attachment[0].id, null)
    direct_connect_gateway = try(aws_networkmanager_dx_gateway_attachment.dxgw_attachment[0].id, null)
  }
}
